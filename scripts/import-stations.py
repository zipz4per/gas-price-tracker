#!/usr/bin/env python3
"""Import fuel stations from OpenStreetMap into the station registry.

Runs server-side and deliberately. Overpass is a free, volunteer-run service
whose usage policy rules out per-page-view querying, so there is no path from a
client request to a provider query — the client reads `stations` and never
contacts the provider.

Each locality is identified by the OSM relation id of its administrative
boundary, never by name. There is no boundary called "Lipa City" (OSM calls it
"Lipa"), and roughly twenty administrative relations worldwide are named "Lipa",
so a name query would either return nothing or union Poland into Batangas.

The query asks for `nwr`, not `node`. Most stations are mapped as building
footprints (ways) or forecourt relations: Malvar returns 2 elements to a
node-only query and 10 to nwr. `out center` gives ways and relations a point so
the import reads one shape regardless of element type.

Idempotent. A station is matched on (provider, provider_place_id) — the
provider's own identifier — so a re-import updates rather than duplicating, even
when a contributor nudges a pin or renames a station.

Usage:  python3 scripts/import-stations.py [--dry-run] [--linked]

Requires: supabase CLI, and the local stack running unless --linked.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

OVERPASS = "https://overpass-api.de/api/interpreter"
USER_AGENT = "gas-price-tracker/0.1 (station registry import; github.com/zipz4per)"

# Overpass area ids are the relation id offset by this constant.
AREA_OFFSET = 3_600_000_000

# Measured 2026-08-31. A run materially short of these is investigated rather
# than accepted: a plausible number is exactly what a silently broken query
# returns.
EXPECTED = {"Malvar": 10, "Lipa City": 52, "Taguig City": 34}

RETRIES = 4
BACKOFF = 6

UPSERT = """insert into stations (
    provider, provider_place_id, name, brand_code,
    locality_id, address, latitude, longitude, provider_fetched_at
) values
{values}
on conflict (provider, provider_place_id) do update set
    name                = excluded.name,
    brand_code          = excluded.brand_code,
    locality_id         = excluded.locality_id,
    address             = excluded.address,
    latitude            = excluded.latitude,
    longitude           = excluded.longitude,
    provider_fetched_at = excluded.provider_fetched_at"""


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
        # The CLI reports failures on stdout and progress on stderr, so the
        # useful half is the one you would not think to print.
        sys.exit(f"db query failed:\n{result.stdout.strip()}\n{result.stderr.strip()}")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        # A statement returning no rows answers with a bare command tag
        # ("INSERT 0 96"), not JSON. That is success, not a parse failure.
        return []
    return payload.get("result") or payload.get("rows") or []


def overpass(relation_id: int) -> list[dict]:
    """Fuel stations inside one administrative boundary.

    Raises rather than returning [] on failure. Overpass reports errors as an
    HTTP 200 carrying an HTML page, so a status check passes and the body fails
    to parse — and an import that treated that as "no stations here" would
    silently empty a locality.
    """
    query = (
        "[out:json][timeout:90];\n"
        f"area({AREA_OFFSET + relation_id})->.a;\n"
        'nwr["amenity"="fuel"](area.a);\n'
        "out center tags;\n"
    )
    data = urllib.parse.urlencode({"data": query}).encode()
    last = ""
    for attempt in range(1, RETRIES + 1):
        try:
            request = urllib.request.Request(
                OVERPASS, data=data, headers={"User-Agent": USER_AGENT}
            )
            with urllib.request.urlopen(request, timeout=120) as response:
                body = response.read().decode("utf-8", "replace")
            return json.loads(body)["elements"]
        except (json.JSONDecodeError, KeyError):
            last = "provider returned a non-JSON body (an HTML error page)"
        except (urllib.error.URLError, OSError, TimeoutError) as exc:
            last = f"{type(exc).__name__}: {exc}"
        if attempt < RETRIES:
            print(f"      attempt {attempt} failed ({last}); retrying")
            time.sleep(BACKOFF * attempt)
    raise RuntimeError(f"provider unavailable after {RETRIES} attempts: {last}")


def address_of(tags: dict) -> str | None:
    """The addr:* tags assembled into one line, or None when there are none."""
    parts = [
        tags.get("addr:housenumber"),
        tags.get("addr:street"),
        tags.get("addr:village") or tags.get("addr:town") or tags.get("addr:city"),
        tags.get("addr:postcode"),
    ]
    joined = ", ".join(p for p in parts if p)
    return joined or None


def point_of(element: dict) -> tuple[float, float] | None:
    centre = element.get("center") or element
    lat, lon = centre.get("lat"), centre.get("lon")
    return (lat, lon) if lat is not None and lon is not None else None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true",
                        help="query the provider and report, but write nothing")
    parser.add_argument("--linked", action="store_true",
                        help="run against the linked hosted project")
    args = parser.parse_args()

    localities = db(
        "select id, display_name, osm_relation_id, osm_name from localities "
        "where osm_relation_id is not null order by display_name",
        args.linked,
    )
    if not localities:
        sys.exit("no locality has an osm_relation_id; nothing to import")

    statements: list[str] = []
    fetched: dict[str, int] = {}
    skipped: list[str] = []

    for locality in localities:
        name = locality["display_name"]
        print(f"  {name} (rel/{locality['osm_relation_id']}, OSM name "
              f"{locality['osm_name']!r})")
        try:
            elements = overpass(int(locality["osm_relation_id"]))
        except RuntimeError as exc:
            # A provider failure is not an empty locality. Leave the existing
            # rows alone and say so.
            print(f"      SKIPPED — {exc}")
            skipped.append(name)
            continue

        kept = 0
        for element in elements:
            point = point_of(element)
            if point is None:
                continue
            tags = element.get("tags", {})
            place_id = f"{element['type']}/{element['id']}"
            statements.append(
                f"('openstreetmap', {lit(place_id)}, "
                f"{lit(tags.get('name') or place_id)}, "
                f"resolve_station_brand({lit(tags.get('brand'))}, "
                f"{lit(tags.get('operator'))}, {lit(tags.get('name'))}), "
                f"{lit(locality['id'])}::uuid, {lit(address_of(tags))}, "
                f"{point[0]}, {point[1]}, now())"
            )
            kept += 1

        fetched[name] = kept
        expected = EXPECTED.get(name)
        flag = ""
        if expected and kept < expected * 0.9:
            flag = f"  ** SHORT of the {expected} measured 2026-08-31 — investigate"
        print(f"      {kept} station(s){flag}")
        time.sleep(2)  # a courtesy to a free volunteer service

    if args.dry_run:
        print(f"\n  dry run — {len(statements)} row(s) withheld")
    elif statements:
        # One statement, not 96. `supabase db query` runs a prepared statement,
        # which takes a single command — and a multi-row upsert is the right
        # shape regardless: every station lands or none does, so a provider
        # failure part-way through cannot leave a locality half-imported.
        db(UPSERT.format(values=",\n".join(statements)), args.linked)
        print(f"\n  {len(statements)} station(s) written")

    if skipped:
        print(f"\n  {len(skipped)} locality skipped after provider failure: "
              f"{', '.join(skipped)}")
        print("  Existing rows for these were left untouched.")

    if not args.dry_run:
        rows = db(
            "select l.display_name as locality, count(*) as stations, "
            "count(*) filter (where s.brand_code is null) as review "
            "from stations s join localities l on l.id = s.locality_id "
            "group by 1 order by 1", args.linked)
        print()
        for row in rows:
            print(f"  {row['locality']:<14}{row['stations']:>4} stored"
                  f"{row['review']:>6} awaiting brand review")

    print()
    total = sum(fetched.values())
    print(f"  {total} station(s) fetched across {len(fetched)} locality(ies)")
    if skipped:
        sys.exit(1)


if __name__ == "__main__":
    main()
