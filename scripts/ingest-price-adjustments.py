#!/usr/bin/env python3
"""Read announced fuel price adjustments from news feeds.

The extractor here is deliberately simple, and the design says why: announcement
phrasing varies too much across outlets for a rule-based reader to be reliable,
so rather than engineering that away, a misread amount has to survive two
independent checks — corroboration between sources in different independence
groups, and the DOE cross-check that runs when a new reference period lands.

Nothing here understands language. It finds a category, finds a number near it,
finds a direction word, and refuses when any of those is missing or implausible.
Refusing is cheap; guessing moves every derived price in the app at once.

Usage:
    python3 scripts/ingest-price-adjustments.py --self-test
    python3 scripts/ingest-price-adjustments.py --dry-run [--linked]

Requires: supabase CLI, and the local stack running unless --linked.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import difflib
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime

USER_AGENT = "gas-price-tracker/0.1 (price adjustment feed; github.com/zipz4per)"
TIMEOUT = 20

MANILA = dt.timezone(dt.timedelta(hours=8))

# A per-litre adjustment is small. Philippine movements run roughly P0.10 to
# P5.00 and have not approached P20 in a single week.
#
# This bound is not tidiness, it is the guard against reading a PRICE as a
# DELTA. "Gasoline now at P78.50" contains a category, a number and, often
# enough, a direction word; without a magnitude ceiling it parses as a P78.50
# hike and moves every gasoline price in the app by the price of gasoline.
MIN_AMOUNT = 0.01
MAX_AMOUNT = 20.00

# How far an effective instant may sit from the announcement that states it.
#
# Announcements say "effective Tuesday", not a date, so the day name is resolved
# against the publication time. Unbounded, that resolution silently lands an
# adjustment in the wrong week whenever the publication date is wrong or the
# phrasing is unusual — which is exactly the off-cycle case the feed exists to
# catch. Bounded, it refuses instead.
MAX_EFFECTIVE_LEAD_DAYS = 7

# The hour a Philippine price adjustment takes effect when the announcement
# names a day but no time.
#
# The DAY always comes from the text; the spec forbids defaulting the weekly
# cycle and this does not. Only the hour is supplied, and every candidate
# records whether its time was 'stated' or came from this 'convention', so the
# assumption is visible in the data rather than hidden in the parser.
CONVENTIONAL_HOUR = 6

MONEY = re.compile(
    r"(?:₱|php|p)\s?(\d{1,3}(?:\.\d{1,2})?)\b"
    r"|(\d{1,3}(?:\.\d{1,2})?)\s*(?:centavos?|pesos?)\b",
    re.I,
)

UP_WORDS = re.compile(
    r"\b(hike|hikes|increase[sd]?|raise[sd]?|raises|up|upward|rise|rises|rising|"
    r"higher|dearer)\b", re.I
)
DOWN_WORDS = re.compile(
    r"\b(rollback|roll\s?back|rollbacks|decrease[sd]?|down|downward|lower|cut|cuts|"
    r"reduction|reduce[sd]?|cheaper)\b",
    re.I,
)

WEEKDAYS = {
    "monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3,
    "friday": 4, "saturday": 5, "sunday": 6,
}

EFFECTIVE_DAY = re.compile(
    r"(?:effective|starting|beginning|takes?\s+effect|as\s+early\s+as)\s+"
    r"(?:on\s+)?(?:(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)\s+(?:on\s+)?)?"
    r"(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"
    r"(?:\s*,?\s*(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?))?",
    re.I,
)

MONTHS = {
    "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
    "july": 7, "august": 8, "september": 9, "october": 10, "november": 11,
    "december": 12, "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6, "jul": 7,
    "aug": 8, "sept": 9, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}

EFFECTIVE_DATE = re.compile(
    r"(?:effective|starting|beginning|takes?\s+effect)\s+"
    r"(?:on\s+)?(?:(\d{1,2})(?::(\d{2}))?\s*(a\.?m\.?|p\.?m\.?)\s+(?:on\s+)?)?"
    r"(" + "|".join(sorted(MONTHS, key=len, reverse=True)) + r")\.?\s+(\d{1,2})"
    r"(?:\s*,\s*(\d{4}))?",
    re.I,
)

WINDOW = 140  # characters either side of a category mention

# A list construction that proximity cannot read.
#
#   "larger cuts for diesel and kerosene, reaching P3.83 and P3.84 respectively"
#
# The figures are ordered to match the categories, not placed beside them, so
# the nearest amount to "kerosene" is diesel's. Parsing the pairing is possible
# and is exactly the kind of cleverness this extractor is designed not to have:
# a wrong figure here moves every derived price of that grade at once, and no
# amount of corroboration helps because a second outlet running the same
# sentence is misread identically. So the window is refused and surfaced.
RESPECTIVELY = re.compile(r"\brespectively\b", re.I)


def sql_array(values: list[str]) -> str:
    """A SQL text[] literal."""
    if not values:
        return "'{}'"
    return "array[" + ", ".join(lit(v) for v in values) + "]::text[]"


def lit(value) -> str:
    """A SQL string literal, or NULL. Nothing here is interpolated raw."""
    if value is None:
        return "null"
    text = str(value).strip()
    if not text:
        return "null"
    return "'" + text.replace("'", "''") + "'"


def db(sql: str, linked: bool) -> list[dict]:
    """Run SQL through the Supabase CLI and return its rows."""
    cmd = ["supabase", "db", "query", sql, "--linked" if linked else "--local"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(f"db query failed:\n{result.stdout.strip()}\n{result.stderr.strip()}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []
    return payload.get("result") or payload.get("rows") or []


def normalize(text: str) -> str:
    """Lower-case, strip tags, collapse whitespace."""
    text = re.sub(r"<[^>]+>", " ", text or "")
    text = text.replace("&amp;", "&").replace("&#8217;", "'").replace("&nbsp;", " ")
    return re.sub(r"\s+", " ", text).strip().lower()


def amounts_in(window: str) -> list[tuple[float, int]]:
    """Every plausible amount in the window, with where it was found.

    The position matters. An article announcing several categories puts their
    figures in one sentence — "gasoline up by P1.20 per liter, diesel up P0.85"
    — so taking the first amount in the window attaches the gasoline figure to
    diesel. The caller picks the amount NEAREST the category it is reading.
    """
    found = []
    for m in MONEY.finditer(window):
        raw = m.group(1) or m.group(2)
        try:
            value = float(raw)
        except (TypeError, ValueError):
            continue
        if m.group(2) and "centavo" in window[m.start():m.end() + 12].lower():
            value = value / 100.0
        found.append((value, m.start()))
    return found


def direction_in(window: str) -> int | None:
    """+1, -1, or None. The nearer word wins when both appear."""
    up = UP_WORDS.search(window)
    down = DOWN_WORDS.search(window)
    if up and down:
        return 1 if up.start() < down.start() else -1
    if up:
        return 1
    if down:
        return -1
    return None


def resolve_effective(text: str, published_at: dt.datetime) -> tuple[dt.datetime, str] | None:
    """The instant an announcement says it takes effect, or None.

    The day is read from the text and never assumed. The hour is read when
    stated and otherwise supplied by convention, which the caller records.
    """
    local = published_at.astimezone(MANILA)

    def clock(hour_raw, minute_raw, meridiem):
        if not hour_raw:
            return CONVENTIONAL_HOUR, 0, "convention"
        hour = int(hour_raw) % 12
        if meridiem and meridiem.lower().startswith("p"):
            hour += 12
        return hour, int(minute_raw or 0), "stated"

    # An explicit date wins over a day name: it is the less ambiguous statement,
    # and it is the form that can land far from the announcement.
    dated = EFFECTIVE_DATE.search(text)
    if dated:
        hour, minute, time_source = clock(dated.group(1), dated.group(2), dated.group(3))
        month = MONTHS[dated.group(4).lower()]
        day = int(dated.group(5))
        year = int(dated.group(6) or local.year)
        try:
            effective = dt.datetime(year, month, day, hour, minute, tzinfo=MANILA)
        except ValueError:
            return None
    else:
        match = EFFECTIVE_DAY.search(text)
        if not match:
            return None
        hour, minute, time_source = clock(match.group(1) or match.group(5),
                                          match.group(2) or match.group(6),
                                          match.group(3) or match.group(7))
        weekday = WEEKDAYS[match.group(4).lower()]
        ahead = (weekday - local.weekday()) % 7
        if ahead == 0:
            ahead = 7  # "effective Tuesday" published ON a Tuesday means the next one
        effective = (local + dt.timedelta(days=ahead)).replace(
            hour=hour, minute=minute, second=0, microsecond=0
        )

    if abs((effective - local).total_seconds()) > MAX_EFFECTIVE_LEAD_DAYS * 86400:
        return None
    return effective, time_source


def extract(text: str, published_at: dt.datetime, aliases: dict[str, str]) -> tuple[list[dict], list[str], list[str]]:
    """Candidates found in one article, and the category phrasings it used that
    have no mapping.

    Amounts are assigned to the NEAREST category mention, and a category keeps
    only the amounts assigned to it. Taking the nearest amount to each category
    independently is not enough: an article that names two categories and prints
    one figure — "oil firms cut diesel and gasoline prices ... gasoline would dip
    by 32 centavos" — then hands that one figure to both, inventing a diesel
    adjustment out of a gasoline one. Nearest-mention assignment leaves diesel
    with nothing, which is the true answer.
    """
    norm = normalize(text)
    headline_direction = direction_in(norm[:160])
    effective = resolve_effective(norm, published_at)

    # Every category mention, mapped or not.
    mentions: list[tuple[int, int, str | None, str]] = []
    for alias, category in aliases.items():
        for m in re.finditer(rf"\b{re.escape(alias)}\b", norm):
            mentions.append((m.start(), m.end(), category, alias))
    if not mentions:
        return [], [], []
    mentions.sort()

    # Assign each plausible amount to the mention it sits closest to.
    assigned: dict[int, list[tuple[float, int]]] = {}
    for value, pos in amounts_in(norm):
        if not (MIN_AMOUNT <= value <= MAX_AMOUNT):
            continue
        best = min(range(len(mentions)),
                   key=lambda i: min(abs(pos - mentions[i][0]), abs(pos - mentions[i][1])))
        start, end, _, _ = mentions[best]
        if min(abs(pos - start), abs(pos - end)) > WINDOW:
            continue
        assigned.setdefault(best, []).append((value, pos))

    candidates: list[dict] = []
    unmapped: list[str] = []
    refused: list[str] = []
    seen: set[str] = set()

    for index, (start, end, category, alias) in enumerate(mentions):
        values = assigned.get(index)
        if not values:
            continue
        if category is None:
            if alias not in unmapped:
                unmapped.append(alias)
            continue
        if category in seen:
            continue
        window = norm[max(0, start - WINDOW): end + WINDOW]
        if RESPECTIVELY.search(window):
            note = f"{category}: ordered list, figures not beside their categories"
            if note not in refused:
                refused.append(note)
            continue
        sign = direction_in(window) or headline_direction
        if sign is None:
            continue
        seen.add(category)
        values.sort(key=lambda vp: min(abs(vp[1] - start), abs(vp[1] - end)))
        candidates.append({
            "category": category,
            "amount": round(sign * values[0][0], 2),
            "effective_at": effective[0] if effective else None,
            "effective_time_source": effective[1] if effective else None,
            "citation": norm[max(0, start - 60): end + 60].strip(),
        })
    return candidates, unmapped, refused


ARTICLE_DELAY = 1.0  # seconds between article fetches

# How alike two citation spans may be before they are treated as one witness.
#
# The independence_group column is a judgement about how outlets work; this is a
# measurement of what they actually printed. Two mastheads running identical wire
# copy pass the first check and fail this one, which matters because corroboration
# between two copies of one story is corroboration between nothing.
SAME_COPY_RATIO = 0.90


def article_text(url: str) -> str:
    """The readable text of an article page.

    Fetched only when the feed summary alone cannot answer the question, which
    for these outlets is most of the time: RSS descriptions are truncated
    mid-sentence and the effective date is routinely in the half that is cut.
    An announcement whose date we cannot read produces no adjustment, so
    feed-only reading would surface nearly everything and record nearly nothing.

    Nothing here is stored. The page is read, a figure and a date are taken from
    it, and the text is discarded - only the short citation span survives, and
    only so a wrong figure can be explained later.
    """
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        body = response.read().decode("utf-8", "replace")
    body = re.sub(r"(?is)<(script|style|nav|header|footer|aside)[^>]*>.*?</\1>", " ", body)
    return normalize(body)


def same_copy(a: str, b: str) -> bool:
    """Whether two citation spans look like the same sentence."""
    return difflib.SequenceMatcher(None, a or "", b or "").ratio() >= SAME_COPY_RATIO


def corroborate(candidates: list[dict]) -> tuple[list[dict], list[dict], list[dict]]:
    """Split candidates into corroborated adjustments, conflicts, and singles.

    A candidate carries source, group, category, amount, effective_at, citation.

    Agreement is counted in independence GROUPS, not sources, and two candidates
    whose citation spans read alike are folded into one witness regardless of
    group. Both guards exist because a wrong amount is invisible from inside the
    system once it is applied: every price derived from it moves together.
    """
    by_slot: dict[tuple[str, str], list[dict]] = {}
    for c in candidates:
        if c["effective_at"] is None:
            continue
        by_slot.setdefault((c["category"], c["effective_at"].isoformat()), []).append(c)

    adjustments, conflicts, singles = [], [], []

    for (category, effective), group in by_slot.items():
        by_amount: dict[float, list[dict]] = {}
        for c in group:
            by_amount.setdefault(c["amount"], []).append(c)

        agreed = None
        for amount, witnesses in by_amount.items():
            distinct: list[dict] = []
            for w in witnesses:
                if any(d["group"] == w["group"] or same_copy(d["citation"], w["citation"])
                       for d in distinct):
                    continue
                distinct.append(w)
            if len(distinct) >= 2:
                agreed = {"category": category, "effective_at": group[0]["effective_at"],
                          "amount": amount, "witnesses": distinct}
                break

        if agreed:
            adjustments.append(agreed)
        elif len(by_amount) > 1:
            conflicts.append({"category": category, "effective_at": group[0]["effective_at"],
                              "reports": group})
        else:
            singles.append({"category": category, "effective_at": group[0]["effective_at"],
                            "reports": group})
    return adjustments, conflicts, singles


def feed_items(url: str) -> list[dict]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        body = response.read()
    root = ET.fromstring(body)
    items = []
    for node in root.iter():
        tag = node.tag.split("}")[-1]
        if tag not in ("item", "entry"):
            continue
        got = {"title": "", "body": "", "link": "", "published": None}
        for child in node:
            ctag = child.tag.split("}")[-1]
            if ctag == "title":
                got["title"] = child.text or ""
            elif ctag in ("description", "summary", "encoded", "content"):
                got["body"] = got["body"] or (child.text or "")
            elif ctag == "link":
                got["link"] = child.text or child.get("href") or ""
            elif ctag in ("pubDate", "published", "updated"):
                try:
                    got["published"] = parsedate_to_datetime(child.text)
                except (TypeError, ValueError):
                    try:
                        got["published"] = dt.datetime.fromisoformat(child.text)
                    except (TypeError, ValueError):
                        pass
        if got["published"] and got["published"].tzinfo is None:
            got["published"] = got["published"].replace(tzinfo=dt.timezone.utc)
        items.append(got)
    return items


FIXTURES = [
    ("hike, per-category amounts, stated effective day",
     "Oil price hike: gasoline up by P1.20 per liter, diesel up P0.85 effective "
     "6 a.m. Tuesday",
     "2026-08-31T20:00:00+08:00"),
    ("rollback phrasing",
     "Big-time oil price rollback this week: gasoline down by P2.50 per liter "
     "effective Tuesday",
     "2026-08-31T20:00:00+08:00"),
    ("no effective day stated",
     "Oil firms raise gasoline prices by P1.10 per liter this week",
     "2026-08-31T20:00:00+08:00"),
    ("a price, not an adjustment",
     "Gasoline now sells at P78.50 per liter in Metro Manila, up from last week, "
     "effective Tuesday",
     "2026-08-31T20:00:00+08:00"),
    ("explicit date within the bound",
     "Oil price hike: gasoline up by P0.60 per liter effective September 1",
     "2026-08-31T20:00:00+08:00"),
    ("explicit date far from publication",
     "Oil price hike: gasoline up by P0.60 per liter effective December 25",
     "2026-08-31T20:00:00+08:00"),
    ("respectively construction",
     "Oil firms will implement cuts for diesel and kerosene, reaching P3.83 and "
     "P3.84 per liter, respectively, effective Tuesday",
     "2026-08-31T20:00:00+08:00"),
    ("unmapped category phrasing",
     "LPG prices up by P1.50 per kilo effective Tuesday",
     "2026-08-31T20:00:00+08:00"),
]


def write_adjustments(adjustments: list[dict], linked: bool) -> int:
    """Expand each corroborated category into one row per covered grade.

    The expansion is a table lookup, not a rule here: which grades an announced
    category covers is a fact about the industry that changes on its own.

    `on conflict do nothing` makes a re-run idempotent. The unique constraint is
    what makes that safe - without it a second reading of one announcement would
    move every price descending from it twice, silently.
    """
    written = 0
    for adj in adjustments:
        grades = db("select fuel_type_code from adjustment_category_fuel_types "
                    f"where category = {lit(adj['category'])} order by fuel_type_code", linked)
        for row in grades:
            values = (f"({lit(row['fuel_type_code'])}, {adj['amount']}, "
                      f"{lit(adj['effective_at'].isoformat())}, "
                      f"{lit(min(w['published_at'].isoformat() for w in adj['witnesses'] if w.get('published_at')) if any(w.get('published_at') for w in adj['witnesses']) else None)})")
            rows = db(
                "with ins as (insert into price_adjustments "
                "(fuel_type_code, amount, effective_at, announced_at) values "
                f"{values} on conflict (fuel_type_code, effective_at) do nothing "
                "returning id) "
                "select id::text from ins", linked)
            if not rows:
                continue
            written += 1
            adjustment_id = rows[0]["id"]
            for w in adj["witnesses"]:
                db("insert into price_adjustment_sources "
                   "(adjustment_id, source_code, amount_reported, citation_span, article_url, published_at) "
                   f"values ({lit(adjustment_id)}, {lit(w['source'])}, {w['amount']}, "
                   f"{lit((w.get('citation') or '')[:400])}, {lit(w.get('url'))}, "
                   f"{lit(w['published_at'].isoformat() if w.get('published_at') else None)})", linked)
    return written


CORROBORATION_CASES = [
    ("two independent sources agreeing", [
        dict(source="GMA", group="GMA", category="gasoline", amount=-0.32,
             citation="gasoline price would dip by 32 centavos per liter"),
        dict(source="INQUIRER", group="INQUIRER", category="gasoline", amount=-0.32,
             citation="oil firms trim pump prices by 32 centavos a litre"),
    ]),
    ("a single source", [
        dict(source="GMA", group="GMA", category="diesel", amount=-3.80,
             citation="diesel down by three pesos eighty"),
    ]),
    ("two independent sources disagreeing", [
        dict(source="GMA", group="GMA", category="gasoline", amount=1.20,
             citation="gasoline up by P1.20 per liter"),
        dict(source="PHILSTAR", group="PHILSTAR", category="gasoline", amount=0.12,
             citation="gasoline up by P0.12 per liter"),
    ]),
    ("two mastheads, one wire story", [
        dict(source="GMA", group="GMA", category="kerosene", amount=-3.80,
             citation="kerosene prices will have downward adjustments of P3.80 per liter"),
        dict(source="PHILSTAR", group="PHILSTAR", category="kerosene", amount=-3.80,
             citation="kerosene prices will have downward adjustments of P3.80 per litre"),
    ]),
]


def self_test_corroboration() -> None:
    at = dt.datetime(2026, 9, 1, 6, 0, tzinfo=MANILA)
    for name, reports in CORROBORATION_CASES:
        for r in reports:
            r["effective_at"] = at
        adjustments, conflicts, singles = corroborate(reports)
        verdict = ("RECORDED " + ", ".join(
                       f"{a['category']} {a['amount']:+.2f} from "
                       f"{'+'.join(w['source'] for w in a['witnesses'])}"
                       for a in adjustments)) if adjustments else (
                  ("CONFLICT " + ", ".join(
                       f"{c['category']}: " + " vs ".join(
                           f"{r['source']}={r['amount']:+.2f}" for r in c["reports"])
                       for c in conflicts)) if conflicts else (
                  ("CORROBORATION MISSING " + ", ".join(
                       f"{s['category']} ({len(s['reports'])} witness)" for s in singles))
                   if singles else "nothing"))
        print(f"  {name:36s} -> {verdict}")


def self_test(aliases: dict[str, str]) -> None:
    for name, text, published in FIXTURES:
        at = dt.datetime.fromisoformat(published)
        cands, unmapped, refused = extract(text, at, aliases)
        print(f"\n{name}")
        print(f"  text: {text[:78]}...")
        if not cands and not unmapped and not refused:
            print("  -> nothing extracted")
        for c in cands:
            eff = c["effective_at"].isoformat() if c["effective_at"] else "UNDETERMINED"
            print(f"  -> {c['category']:9s} {c['amount']:+.2f}  effective {eff}"
                  f"  ({c['effective_time_source'] or 'n/a'})")
        for u in unmapped:
            print(f"  -> UNMAPPED category phrasing: {u!r}")
        for r in refused:
            print(f"  -> REFUSED {r}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--linked", action="store_true", help="use the linked project")
    parser.add_argument("--dry-run", action="store_true", help="extract and report, write nothing")
    parser.add_argument("--self-test", action="store_true", help="run the built-in extraction fixtures")
    parser.add_argument("--self-test-corroboration", action="store_true",
                        help="run the built-in corroboration scenarios")
    args = parser.parse_args()

    rows = db("select alias, category from adjustment_category_aliases order by alias", args.linked)
    aliases = {r["alias"]: r["category"] for r in rows}
    # Phrasings the extractor should recognise as categories but which have no
    # mapping. Surfaced, never guessed at.
    for probe in ("lpg", "autogas", "avgas"):
        aliases.setdefault(probe, None)
    if not aliases:
        sys.exit("no category aliases registered; seed adjustment_category_aliases first")

    if args.self_test_corroboration:
        self_test_corroboration()
        return

    if args.self_test:
        self_test(aliases)
        return

    sources = db(
        "select code, display_name, feed_url, independence_group "
        "from adjustment_sources where active order by code", args.linked)
    if not sources:
        sys.exit("no active sources registered")

    collected: list[dict] = []
    reached: list[str] = []
    consulted = [src["code"] for src in sources]
    notes: list[str] = []

    for source in sources:
        print(f"\n=== {source['code']} {source['feed_url']}")
        try:
            items = feed_items(source["feed_url"])
        except (urllib.error.URLError, ET.ParseError, OSError) as exc:
            print(f"  unreachable: {exc}")
            notes.append(f"{source['code']}: {exc}")
            continue
        reached.append(source["code"])
        print(f"  {len(items)} items")

        found = 0
        for item in items:
            if not item["published"]:
                continue
            text = f"{item['title']}. {item['body']}"
            cands, unmapped, refused = extract(text, item["published"], aliases)
            origin = "summary"

            # The summary found an announcement but not when it takes effect.
            # That is the common case: RSS descriptions are truncated and the
            # date is routinely in the half that is cut.
            if cands and any(c["effective_at"] is None for c in cands) and item["link"]:
                try:
                    time.sleep(ARTICLE_DELAY)
                    fuller = f"{item['title']}. {article_text(item['link'])}"
                except (urllib.error.URLError, OSError) as exc:
                    print(f"  article unreadable ({exc}); keeping summary result")
                else:
                    deeper, deeper_unmapped, deeper_refused = extract(
                        fuller, item["published"], aliases)
                    if deeper or deeper_refused:
                        cands, unmapped, refused, origin = (
                            deeper, deeper_unmapped, deeper_refused, "article")

            for c in cands:
                found += 1
                eff = c["effective_at"].isoformat() if c["effective_at"] else "UNDETERMINED"
                print(f"  {c['category']:9s} {c['amount']:+.2f}  effective {eff}"
                      f"  [{origin}/{c['effective_time_source'] or 'n/a'}]")
                print(f"    {item['title'][:90]}")
                collected.append({**c, "source": source["code"],
                                  "group": source["independence_group"],
                                  "url": item["link"], "published_at": item["published"]})
            for u in unmapped:
                found += 1
                print(f"  UNMAPPED {u!r} in: {item['title'][:70]}")
                notes.append(f"unmapped category {u!r} ({source['code']})")
            for r in refused:
                found += 1
                print(f"  REFUSED {r}")
                notes.append(f"refused: {r} ({source['code']})")
        if found == 0:
            print("  no adjustment announcements in this feed right now")

    adjustments, conflicts, singles = corroborate(collected)

    print("\n=== corroboration")
    for a in adjustments:
        print(f"  RECORD {a['category']} {a['amount']:+.2f} effective "
              f"{a['effective_at'].isoformat()} from "
              f"{'+'.join(w['source'] for w in a['witnesses'])}")
    for c in conflicts:
        print(f"  CONFLICT {c['category']}: " +
              " vs ".join(f"{r['source']}={r['amount']:+.2f}" for r in c["reports"]))
    for s_ in singles:
        print(f"  CORROBORATION MISSING {s_['category']} "
              f"({s_['reports'][0]['source']} only)")
    if not (adjustments or conflicts or singles):
        print("  nothing corroborable")

    # The outcome, most consequential first. A run that recorded something says
    # so even if it also saw a conflict; the conflict rows are written either way.
    if not reached:
        outcome, reason = "failed", "; ".join(notes) or "no source could be reached"
    elif adjustments:
        outcome, reason = "recorded", None
    elif conflicts:
        outcome, reason = "conflict", None
    elif singles:
        outcome, reason = "corroboration_missing", None
    else:
        outcome, reason = "none_announced", None

    if args.dry_run:
        rows = 0
        for a in adjustments:
            rows += len(db("select fuel_type_code from adjustment_category_fuel_types "
                           f"where category = {lit(a['category'])}", args.linked))
        print(f"\n=== dry run: would record outcome {outcome!r}, {rows} adjustment row(s)")
        return

    written = write_adjustments(adjustments, args.linked) if adjustments else 0
    if adjustments and written == 0:
        outcome = "none_announced"  # everything found was already on record
    run_rows = db(
        "with ins as (insert into adjustment_load_runs "
        "(outcome, sources_consulted, sources_reached, adjustments_recorded, failure_reason, note, finished_at) "
        f"values ({lit(outcome)}, {sql_array(consulted)}, {sql_array(reached)}, {written}, "
        f"{lit(reason)}, {lit('; '.join(notes)[:500] or None)}, now()) returning id) "
        "select id::text from ins", args.linked)
    run_id = run_rows[0]["id"] if run_rows else None

    for c in conflicts:
        for r in c["reports"]:
            db("insert into adjustment_run_conflicts "
               "(run_id, category, effective_at, source_code, amount, citation_span, article_url, published_at) "
               f"values ({lit(run_id)}, {lit(c['category'])}, {lit(c['effective_at'].isoformat())}, "
               f"{lit(r['source'])}, {r['amount']}, {lit((r.get('citation') or '')[:400])}, "
               f"{lit(r.get('url'))}, {lit(r['published_at'].isoformat() if r.get('published_at') else None)})",
               args.linked)

    print(f"\n=== run recorded: {outcome}, {written} adjustment row(s)")


if __name__ == "__main__":
    main()
