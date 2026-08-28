#!/usr/bin/env python3
"""Project the OpenSpec workflow onto a GitHub Project board.

The board is DERIVED, never maintained. Every run recomputes each record's
status and progress from `openspec/` — the directory a record sits in says
which column it belongs in, and its task checkboxes give its progress:

    openspec/changes/<name>/           0 tasks done   ->  Proposed
    openspec/changes/<name>/           some done      ->  In Progress
    openspec/changes/<name>/           all done       ->  Ready to archive
    openspec/changes/archive/<name>/                  ->  Done

Two kinds of record are projected. A change is a commitment, described by a
proposal and tracked by tasks.md. A bug is an observation, described by a
report and tracked by whatever fix tasks that report carries. They share the
columns because their lifecycles are parallel:

    openspec/changes/<name>/  ->  [change] <name>  ->  kind: feature
    openspec/bugs/<name>/     ->  [bug] <name>     ->  kind: bug

Because nothing is stored, the board cannot drift out of sync. The only way for
it to be wrong is for openspec/ to be wrong, in which case it is faithfully
reporting a real problem.

This is one-directional. Editing a card on the board does not move the work,
and the next run will overwrite it.

Usage:  python3 scripts/sync-project-board.py [--dry-run]

Requires: gh CLI authenticated with `project` scope (gh auth refresh -s project)
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

REPO = "zipz4per/gas-price-tracker"

# Artifact links are absolute, pointing at the default branch. An issue body is
# not in the repository tree, so GitHub resolves a repo-relative href against
# the issue's own URL — /issues/openspec/... — which is a 404. The relative
# form is correct inside a committed file and wrong here, which is why it went
# unnoticed: it is exactly what a link in README.md looks like.
DEFAULT_BRANCH = "main"
PROJECT_NUMBER = "6"
PROJECT_OWNER = "zipz4per"

# Every issue is assigned to the repository owner so the board's Assignees
# column is populated and filtering by assignee returns the whole project.
ISSUE_ASSIGNEE = "zipz4per"

# Custom field, not GitHub's built-in "Status". The built-in one is reserved:
# it cannot be deleted, recreated, or extended from the CLI, so relying on it
# would make the board impossible to set up without clicking through the web UI.
STATUS_FIELD = "OpenSpec Status"

PROPOSED, IN_PROGRESS, READY, DONE = (
    "Proposed",
    "In Progress",
    "Ready to archive",
    "Done",
)

# What a record is. Derived from which tree it sits in and from nothing else:
# the directory is the answer, completely, so there is no field to mistype and
# no way for the label to disagree with the file it describes.
FEATURE, BUG = "feature", "bug"
KINDS = (FEATURE, BUG)
TITLE_PREFIXES = {FEATURE: "[change] ", BUG: "[bug] "}

# Three axes, filtered independently. `capability:` says what a record is
# about, `layer:` says where the work lives, `kind:` says whether it is work
# or a defect. They are not alternatives — collapsing two of them into one
# field is what once made `tooling` look like a capability.
#
# Two are declared and one is derived. A change's capabilities come from the
# specs/ directory it writes deltas for, so they cannot disagree with it; a
# bug has no specs/ directory and must declare a capability instead, which
# makes it the one label on a bug that can be wrong. `layer:` is declared
# because the sync reads only the planning directory and cannot tell client
# work from server work by looking. `kind:` is derived, because location
# answers it completely.
CAPABILITY_LABEL_PREFIX = "capability: "
LAYER_LABEL_PREFIX = "layer: "
KIND_LABEL_PREFIX = "kind: "
MANAGED_LABEL_PREFIXES = (
    CAPABILITY_LABEL_PREFIX, LAYER_LABEL_PREFIX, KIND_LABEL_PREFIX,
)

# Closed sets. An unrecognised value would otherwise flow into ensure_labels(),
# which creates whatever it is handed, and the record would look correctly
# labelled while carrying a label nobody else shares.
LAYERS = ("backend", "frontend", "tooling")

CAPABILITY_LABEL_COLOR = "0e8a16"
LAYER_LABEL_COLORS = {
    "backend": "1d76db",
    "frontend": "d93f0b",
    "tooling": "5319e7",  # the colour the retired bare `tooling` label used
}
KIND_LABEL_COLORS = {FEATURE: "0052cc", BUG: "b60205"}
ARCHIVE_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}-")

# A checkbox anywhere in an issue body is counted by GitHub's task-list
# progress bar, so one in quoted prose would inflate an issue's task count
# while the board's own count — read from tasks.md — stayed right.
CHECKBOX_RE = re.compile(r"^- \[[ xX]\] ")

# A lead paragraph must be prose. These prefixes mark a bullet, heading,
# blockquote, or table row, none of which reads as a description.
NON_PROSE_PREFIXES = ("-", "*", "+", "#", ">", "|")

REPO_ROOT = Path(__file__).resolve().parent.parent
OPENSPEC_DIR = REPO_ROOT / "openspec"
CHANGES_DIR = OPENSPEC_DIR / "changes"
BUGS_DIR = OPENSPEC_DIR / "bugs"
SPECS_DIR = OPENSPEC_DIR / "specs"

# Each tree keeps its own archive, so an archived bug and an archived change
# are found the same way.
ARCHIVE_DIR = CHANGES_DIR / "archive"
BUGS_ARCHIVE_DIR = BUGS_DIR / "archive"

# The document a record is described by. A change is described by a proposal
# and tracked by tasks.md; a bug is one file that is both.
DOC_FILE = {FEATURE: "proposal.md", BUG: "report.md"}
TASK_FILE = {FEATURE: "tasks.md", BUG: "report.md"}


def gh(*args: str, check: bool = True) -> str:
    """Run a gh command and return stdout. Fails loudly rather than guessing."""
    result = subprocess.run(
        ["gh", *args], capture_output=True, text=True, cwd=REPO_ROOT
    )
    if check and result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)}\n{result.stderr.strip()}")
    return result.stdout.strip()


@dataclass
class Record:
    """A change or a bug — everything the board projects.

    One type, because the board treats them the same way: a column derived
    from progress, an issue derived from a document, three derived labels. The
    differences are which file describes it and which file its tasks live in,
    and those are looked up from `kind`."""
    name: str
    path: Path
    kind: str
    archived: bool
    done: int
    total: int
    capabilities: tuple[str, ...] = ()
    skip_specs: bool = False
    layer: str = ""

    @property
    def status(self) -> str:
        if self.archived:
            return DONE
        if self.total == 0 or self.done == 0:
            return PROPOSED
        if self.done == self.total:
            return READY
        return IN_PROGRESS

    @property
    def issue_title(self) -> str:
        return f"{TITLE_PREFIXES[self.kind]}{self.name}"

    @property
    def doc_path(self) -> Path:
        return self.path / DOC_FILE[self.kind]

    @property
    def progress(self) -> str:
        return f"{self.done}/{self.total}" if self.total else "no tasks"

    @property
    def labels(self) -> list[str]:
        """All three axes together. Capabilities come from a change's specs/
        directory or a bug's declaration, the layer from .openspec.yaml, and
        the kind from which tree the record sits in, so none of them can fall
        out of step with what the record actually is."""
        labels = [f"{CAPABILITY_LABEL_PREFIX}{c}" for c in self.capabilities]
        if self.layer:
            labels.append(f"{LAYER_LABEL_PREFIX}{self.layer}")
        labels.append(f"{KIND_LABEL_PREFIX}{self.kind}")
        return labels


def count_tasks(record_dir: Path, filename: str) -> tuple[int, int]:
    """Count completed vs total tasks. A record with no task file is not an
    error — some changes are pure planning, and a bug whose fix lives in a
    change tracks its tasks there — so it reports zero progress."""
    tasks = record_dir / filename
    if not tasks.is_file():
        return 0, 0
    text = tasks.read_text(encoding="utf-8")
    done = len(re.findall(r"(?m)^- \[x\] ", text))
    todo = len(re.findall(r"(?m)^- \[ \] ", text))
    return done, done + todo


def read_capabilities(change_dir: Path) -> tuple[str, ...]:
    """A change's capabilities, derived from the deltas it writes."""
    specs = change_dir / "specs"
    if not specs.is_dir():
        return ()
    return tuple(sorted(p.parent.name for p in specs.rglob("spec.md")))


def reads_skip_specs(change_dir: Path) -> bool:
    cfg = change_dir / ".openspec.yaml"
    if not cfg.is_file():
        return False
    return "skip_specs: true" in cfg.read_text(encoding="utf-8")


def _declared(record_dir: Path, field: str) -> str:
    """A single scalar field from .openspec.yaml, or "" when absent.

    Deliberately not a YAML parse: the sync reads three flat scalars and
    depending on a parser to do that would be the larger risk."""
    cfg = record_dir / ".openspec.yaml"
    if not cfg.is_file():
        return ""
    found = re.search(rf"(?m)^{field}:\s*(\S+)\s*$",
                      cfg.read_text(encoding="utf-8"))
    return found.group(1) if found else ""


def read_layer(record_dir: Path) -> str:
    """The layer a record declares, or "" when it declares none.

    Declared rather than derived: the sync reads only the planning directory,
    never a diff, so nothing here can tell client work from server work by
    looking. Validation happens in preflight, where a bad value can stop the
    run before it reaches ensure_labels()."""
    return _declared(record_dir, "layer")


def read_declared_capability(bug_dir: Path) -> tuple[str, ...]:
    """A bug's capability, which it must declare.

    A change derives this from the specs/ directory it writes deltas for, so
    the two cannot disagree. A bug has no specs/ directory — it is a record
    about behaviour that already exists — so it declares one instead, and
    preflight checks the value names a real capability."""
    declared = _declared(bug_dir, "capability")
    return (declared,) if declared else ()


def discover_records() -> list[Record]:
    """Both trees, active and archived."""
    records: list[Record] = []

    def add(d: Path, kind: str, archived: bool) -> None:
        # Archived directories carry a YYYY-MM-DD- prefix; the record's real
        # name is what the issue title must match, so strip it.
        name = ARCHIVE_DATE_RE.sub("", d.name) if archived else d.name
        done, total = count_tasks(d, TASK_FILE[kind])
        caps = (read_capabilities(d) if kind == FEATURE
                else read_declared_capability(d))
        records.append(Record(name, d, kind, archived, done, total,
                              caps, reads_skip_specs(d), read_layer(d)))

    for root, kind, archive in (
        (CHANGES_DIR, FEATURE, ARCHIVE_DIR),
        (BUGS_DIR, BUG, BUGS_ARCHIVE_DIR),
    ):
        for d in sorted(root.iterdir()) if root.is_dir() else []:
            if d.is_dir() and d.name != "archive":
                add(d, kind, archived=False)
        for d in sorted(archive.iterdir()) if archive.is_dir() else []:
            if d.is_dir():
                add(d, kind, archived=True)

    return records


class DocumentError(RuntimeError):
    """A proposal or report that cannot supply a description.

    Raised during preflight, before anything is written, because the
    alternative — publishing whatever the parse happened to return — produces
    an issue that looks fine and describes the wrong thing."""


@dataclass(frozen=True)
class Description:
    """The parts of a proposal that get published on its issue."""
    lead: str
    changes: tuple[str, ...]
    out_of_scope: tuple[str, ...]


@dataclass(frozen=True)
class BugReport:
    """The parts of a report that get published on its issue.

    `caused_by` and `fixed_by` are single lines and are published together,
    because a defect that shipped broken and one that was working until a
    known commit are different findings, and seeing only one of them invites
    the wrong conclusion."""
    broken: str
    impact: tuple[str, ...]
    reproduction: tuple[str, ...]
    root_cause: tuple[str, ...]
    caused_by: str
    fixed_by: str
    needs_change: tuple[str, ...]
    fix_tasks: tuple[str, ...]


def _section(lines: list[str], heading: str) -> list[str] | None:
    """Lines under `heading`, stopping at the next heading of ANY level.

    Stopping at any heading is what keeps `### Explicitly out of scope` out of
    the `## What Changes` bullets — it is nested under that section, so a
    scanner that only stopped at `##` would quote every out-of-scope bullet
    twice. Returns None when the heading is absent, which is different from a
    heading that is present and empty."""
    out: list[str] | None = None
    for line in lines:
        if line.strip() == heading:
            out = []
            continue
        if out is not None:
            if line.startswith("#"):
                break
            out.append(line)
    return out


def _lead_paragraph(lines: list[str]) -> list[str]:
    """The first block of non-blank lines."""
    para: list[str] = []
    for line in lines:
        if not line.strip():
            if para:
                break
            continue
        para.append(line.rstrip())
    return para


def _bullets(lines: list[str] | None) -> tuple[str, ...]:
    return tuple(l.rstrip() for l in (lines or []) if l.startswith("- "))


def _trimmed(lines: list[str] | None) -> tuple[str, ...]:
    """A section kept verbatim, with blank lines trimmed from both ends."""
    kept = list(lines or [])
    while kept and not kept[0].strip():
        kept.pop(0)
    while kept and not kept[-1].strip():
        kept.pop()
    return tuple(l.rstrip() for l in kept)


def _where(path: Path) -> str:
    try:
        return path.relative_to(REPO_ROOT).as_posix()
    except ValueError:  # outside the repo; the absolute path is still useful
        return str(path)


def _no_checkboxes(lines, fail) -> None:
    """A checkbox anywhere in published prose is counted by GitHub's task-list
    progress bar, so it would inflate an issue's task count while the board's
    own count — read from the record's task file — stayed right."""
    for line in lines:
        if CHECKBOX_RE.match(line):
            raise fail(
                f"published text contains a checkbox: {line.strip()[:48]!r}; "
                "GitHub would count it in the issue's task-list progress"
            )


def extract_description(record: Record) -> Description | BugReport:
    """Read a record's published description out of the document that
    describes it. Nothing here is inferred or repaired. Every failure raises,
    because the failures this guards against are the quiet ones: a summary
    that is merely plausible reads exactly like a correct one."""
    return (_extract_proposal if record.kind == FEATURE
            else _extract_report)(record)


def _extract_proposal(record: Record) -> Description:
    path = record.doc_path
    where = _where(path)

    def fail(problem: str) -> DocumentError:
        return DocumentError(f"{record.name}: {problem} ({where})")

    if not path.is_file():
        raise fail("no proposal.md")
    lines = path.read_text(encoding="utf-8").splitlines()

    why = _section(lines, "## Why")
    if why is None:
        raise fail("no '## Why' section")
    lead = _lead_paragraph(why)
    if not lead:
        raise fail("'## Why' has no opening paragraph")
    if lead[0].lstrip().startswith(NON_PROSE_PREFIXES):
        raise fail(
            f"'## Why' opens with {lead[0].strip()[:48]!r} rather than prose; "
            "its first paragraph is published as the issue description"
        )

    what = _section(lines, "## What Changes")
    if what is None:
        raise fail("no '## What Changes' section")
    changes = _bullets(what)
    if not changes:
        raise fail("'## What Changes' has no top-level bullets")

    out_of_scope = _bullets(_section(lines, "### Explicitly out of scope"))
    _no_checkboxes((*lead, *changes, *out_of_scope), fail)
    return Description(" ".join(lead), changes, out_of_scope)


# Sections a report must carry. Each is required even when its answer is not
# yet known, because a report keeps a pending marker rather than a blank —
# an absent section reads as an oversight, a pending one as a stage not
# reached.
REPORT_SECTIONS = (
    "## What's broken",
    "## Impact",
    "## Reproduction",
    "## Root cause",
    "## Caused by",
    "## Fixed by",
    "## Does this need a change?",
)


def _extract_report(record: Record) -> BugReport:
    path = record.doc_path
    where = _where(path)

    def fail(problem: str) -> DocumentError:
        return DocumentError(f"{record.name}: {problem} ({where})")

    if not path.is_file():
        raise fail("no report.md")
    lines = path.read_text(encoding="utf-8").splitlines()

    found = {h: _section(lines, h) for h in REPORT_SECTIONS}
    missing = [h for h, body in found.items() if body is None]
    if missing:
        raise fail(f"report is missing {', '.join(repr(h) for h in missing)}")

    broken = _lead_paragraph(found["## What's broken"])
    if not broken:
        raise fail("\"## What's broken\" has no opening paragraph")
    if broken[0].lstrip().startswith(NON_PROSE_PREFIXES):
        raise fail(
            f"\"## What's broken\" opens with {broken[0].strip()[:48]!r} rather "
            "than prose; its first paragraph is published as the issue "
            "description"
        )

    reproduction = _trimmed(found["## Reproduction"])
    if not reproduction:
        raise fail(
            "'## Reproduction' is empty; a report nobody else can reproduce "
            "is a claim, not a finding"
        )

    def one_line(heading: str) -> str:
        para = _lead_paragraph(found[heading])
        if not para:
            raise fail(f"{heading!r} is empty; use its pending marker instead")
        return " ".join(l.strip() for l in para)

    report = BugReport(
        broken=" ".join(broken),
        impact=_trimmed(found["## Impact"]),
        reproduction=reproduction,
        root_cause=_trimmed(found["## Root cause"]),
        caused_by=one_line("## Caused by"),
        fixed_by=one_line("## Fixed by"),
        needs_change=_trimmed(found["## Does this need a change?"]),
        fix_tasks=_trimmed(_section(lines, "## Fix tasks")),
    )
    _no_checkboxes(
        (report.broken, *report.impact, *report.reproduction,
         *report.root_cause, report.caused_by, report.fixed_by,
         *report.needs_change),
        fail,
    )
    return report


def check_declarations(record: Record) -> list[str]:
    """Validate what a record declares, returning problems rather than
    raising, so one pass can report everything that needs attention.

    An undeclared value is an omission and an unrecognised one is a typo, and
    both produce the same silent outcome if allowed through: a card that looks
    labelled and filters into nothing."""
    where = _where(record.path / ".openspec.yaml")
    problems: list[str] = []

    # `kind:` is derived from location. A declared one would be ignored, and
    # an ignored declaration is worse than a rejected one: it reads as though
    # it took effect.
    if _declared(record.path, "kind"):
        problems.append(
            f"{record.name}: 'kind:' is declared but is derived from which "
            f"tree the record sits in; remove it ({where})")

    allowed = ", ".join(LAYERS)
    if not record.layer:
        problems.append(f"{record.name}: no 'layer:' declared; expected one of "
                        f"{allowed} ({where})")
    elif record.layer not in LAYERS:
        problems.append(f"{record.name}: unrecognised layer {record.layer!r}; "
                        f"expected one of {allowed} ({where})")

    if record.kind == BUG:
        # A bug declares its capability because it has no specs/ directory to
        # derive one from, so this is the one label on a bug that can be
        # wrong. Checking it against openspec/specs/ is what stops a typo from
        # creating a brand-new label nobody else shares.
        for cap in record.capabilities:
            if not (SPECS_DIR / cap).is_dir():
                problems.append(
                    f"{record.name}: capability {cap!r} names no directory "
                    f"under {_where(SPECS_DIR)}/ ({where})")
        if not record.capabilities and record.layer != "tooling":
            problems.append(
                f"{record.name}: no 'capability:' declared; a bug has no "
                f"specs/ directory to derive one from ({where})")

    return problems


def blob_url(path: Path) -> str:
    """An absolute link to a file on the default branch."""
    return f"https://github.com/{REPO}/blob/{DEFAULT_BRANCH}/{_where(path)}"


def artifact_links(record: Record) -> list[tuple[str, str]]:
    """The (label, url) pairs a record's issue links to.

    Shared by the body builders and the dry run, so what a reader would click
    is the same thing a dry run prints. The sync never renders the markdown it
    writes, so a link it gets wrong fails silently — printing them is the only
    check available without fetching the rendered issue."""
    if record.kind == BUG:
        return [("report", blob_url(record.path / "report.md"))]

    links = [("proposal", blob_url(record.path / "proposal.md"))]
    if (record.path / "design.md").is_file():
        links.append(("design", blob_url(record.path / "design.md")))
    specs = record.path / "specs"
    for spec in sorted(specs.rglob("spec.md")) if specs.is_dir() else []:
        links.append((f"spec: {spec.parent.name}", blob_url(spec)))
    return links


def build_issue_body(record: Record, desc: Description | BugReport) -> str:
    if isinstance(desc, BugReport):
        return build_bug_body(record, desc)
    return build_change_body(record, desc)


def build_change_body(record: Record, desc: Description) -> str:
    """Compose the issue body from the proposal and tasks.md.

    Order matters. The description leads, because a body opening with a link
    list reads as navigation rather than as a document. Status stays high — it
    is the one line someone scanning for state wants. Links sit below the
    prose: they are what you click after deciding you care. Nothing here is
    folded behind <details>; a summary nobody expands is the state this
    change exists to fix."""
    lines = [
        "<!-- Generated by scripts/sync-project-board.py. Edits here are overwritten. -->",
        "",
        desc.lead,
        "",
        f"**Status:** {record.status} · **Tasks:** {record.progress}",
        "",
        "**What changes**",
        "",
        *desc.changes,
    ]
    if desc.out_of_scope:
        lines += ["", "**Out of scope**", "", *desc.out_of_scope]

    lines.append("")
    lines += [f"- [{label}]({url})" for label, url in artifact_links(record)]
    lines.append("")

    tasks = record.path / "tasks.md"
    if tasks.is_file():
        # Verbatim: OpenSpec already writes GitHub checkbox markdown, so the
        # native task list and its progress bar need no transformation.
        lines.append("---")
        lines.append("")
        lines.append(tasks.read_text(encoding="utf-8").rstrip())
    else:
        lines.append("_No tasks file._")

    return "\n".join(lines) + "\n"


def build_bug_body(record: Record, report: BugReport) -> str:
    """Compose the issue body from the report.

    Same shape as a change's: the description leads, status stays high, links
    sit below the prose, nothing is folded. What differs is that causation and
    repair are published together on one line directly under the status, and
    that the reproduction is carried in full rather than summarised — a report
    somebody has to open the repository to act on is a report that gets
    argued with instead of run."""
    lines = [
        "<!-- Generated by scripts/sync-project-board.py. Edits here are overwritten. -->",
        "",
        report.broken,
        "",
        f"**Status:** {record.status} · **Tasks:** {record.progress}",
        "",
        f"**Caused by:** {report.caused_by} · **Fixed by:** {report.fixed_by}",
        "",
        "**Reproduction**",
        "",
        *report.reproduction,
    ]
    if report.impact:
        lines += ["", "**Impact**", "", *report.impact]
    lines += ["", "**Root cause**", "", *report.root_cause]
    lines += ["", "**Does this need a change?**", "", *report.needs_change]
    lines.append("")
    lines += [f"- [{label}]({url})" for label, url in artifact_links(record)]
    lines.append("")

    if report.fix_tasks:
        # Verbatim, for the same reason a change's tasks.md is: the checkbox
        # markdown is already what GitHub's task-list progress bar reads.
        lines += ["---", "", *report.fix_tasks]
    else:
        lines.append("_No fix tasks — see the linked change, if any._")

    return "\n".join(lines) + "\n"


def find_issue(title: str) -> dict | None:
    """Match by title. No stored ids: if an issue is deleted the next run
    recreates it rather than failing on a dangling reference."""
    raw = gh(
        "issue", "list", "--repo", REPO, "--state", "all",
        "--limit", "200", "--json", "number,title,state,body,url,assignees,labels",
    )
    for issue in json.loads(raw or "[]"):
        if issue["title"] == title:
            return issue
    return None


def project_items() -> dict[str, str]:
    """Map issue url -> project item id, fetched once per run.

    Newly added items are folded into this map from the item-add response
    rather than re-queried: `item-add` returns before `item-list` reflects the
    new item, so looking it up immediately is a race.
    """
    raw = gh(
        "project", "item-list", PROJECT_NUMBER,
        "--owner", PROJECT_OWNER, "--limit", "200", "--format", "json",
    )
    items: dict[str, str] = {}
    for item in json.loads(raw or "{}").get("items", []):
        content = item.get("content") or {}
        if content.get("url"):
            items[content["url"]] = item["id"]
    return items


def ensure_labels(records: list[Record]) -> None:
    """Create any label the sync is about to use. --force makes this
    idempotent: it updates an existing label rather than failing.

    Every colour lookup here is a dict subscript on a closed set, so an
    unrecognised layer or kind raises rather than reaching GitHub. That is the
    point: this function creates whatever it is handed, so a typo that got
    past preflight would otherwise become a real label nobody else shares."""
    wanted: dict[str, tuple[str, str]] = {}
    for record in records:
        for label in record.labels:
            if label.startswith(CAPABILITY_LABEL_PREFIX):
                cap = label[len(CAPABILITY_LABEL_PREFIX):]
                wanted[label] = (CAPABILITY_LABEL_COLOR,
                                 f"Records affecting the {cap} capability")
            elif label.startswith(LAYER_LABEL_PREFIX):
                layer = label[len(LAYER_LABEL_PREFIX):]
                wanted[label] = (LAYER_LABEL_COLORS[layer],
                                 f"Records whose work lives in the {layer} layer")
            else:
                kind = label[len(KIND_LABEL_PREFIX):]
                wanted[label] = (KIND_LABEL_COLORS[kind],
                                 "Defects in behaviour that already exists"
                                 if kind == BUG else
                                 "Work the project has committed to")
    existing = {l["name"] for l in json.loads(
        gh("label", "list", "--repo", REPO, "--limit", "100", "--json", "name") or "[]")}
    for name, (color, desc) in sorted(wanted.items()):
        if name not in existing:
            gh("label", "create", name, "--repo", REPO,
               "--color", color, "--description", desc, "--force")
            print(f"  label created: {name}")


def sync(dry_run: bool) -> int:
    records = discover_records()
    if not records:
        print("No records found under openspec/changes/ or openspec/bugs/.")
        return 1

    print(f"Found {len(records)} record(s)\n")

    # Preflight. Every document is read before anything is written, so one
    # that cannot supply a description stops the whole run rather than leaving
    # one card stale beside four current ones — the exact condition a derived
    # board exists to make impossible. Every failure is reported, not just the
    # first, so one pass names all the work.
    #
    # Keyed by issue title, not by name: a bug and a change may share a name,
    # and the titles are what distinguish them.
    descriptions: dict[str, Description | BugReport] = {}
    failures: list[str] = []
    for record in records:
        try:
            descriptions[record.issue_title] = extract_description(record)
        except DocumentError as exc:
            failures.append(str(exc))
        failures.extend(check_declarations(record))
    if failures:
        sys.stdout.flush()  # keep the report above the errors, not after them
        for failure in failures:
            print(f"error: {failure}", file=sys.stderr)
        print(f"\n{len(failures)} problem(s) in openspec/. Nothing was written.",
              file=sys.stderr)
        return 1

    if not dry_run:
        ensure_labels(records)
    on_board = {} if dry_run else project_items()
    actions = 0

    for record in records:
        body = build_issue_body(record, descriptions[record.issue_title])
        issue = find_issue(record.issue_title)
        want_state = "CLOSED" if record.archived else "OPEN"

        print(f"  {record.issue_title}")
        print(f"    status   {record.status}  ({record.progress})")
        if record.labels:
            print(f"    labels   {', '.join(record.labels)}")

        if dry_run:
            for label, url in artifact_links(record):
                print(f"    link     {label}: {url}")
            print(f"    issue    {'update' if issue else 'create'} (dry run)")
            print(f"    board    set {STATUS_FIELD} = {record.status} (dry run)\n")
            continue

        if issue is None:
            url = gh(
                "issue", "create", "--repo", REPO,
                "--title", record.issue_title, "--body", body,
                "--assignee", ISSUE_ASSIGNEE,
                *sum((["--label", l] for l in record.labels), []),
            ).splitlines()[-1]
            issue = {"url": url, "number": url.rsplit("/", 1)[-1], "state": "OPEN",
                     "body": body, "assignees": [{"login": ISSUE_ASSIGNEE}],
                     "labels": [{"name": l} for l in record.labels]}
            print(f"    issue    created {url}")
            actions += 1
        else:
            url = issue["url"]
            if issue.get("body", "").strip() != body.strip():
                gh("issue", "edit", str(issue["number"]), "--repo", REPO, "--body", body)
                print(f"    issue    body updated")
                actions += 1
            else:
                print(f"    issue    up to date")

        # Labels are reconciled, not merely added. The sync owns exactly
        # three prefixes; a stale one inside them is removed, and every other
        # label — anything applied by hand — is left alone, because a board
        # that deletes someone's label teaches people not to use labels.
        have = {l["name"] for l in issue.get("labels", [])}
        want = set(record.labels)
        missing = sorted(want - have)
        stale = sorted(l for l in have - want
                       if l.startswith(MANAGED_LABEL_PREFIXES) or l == "tooling")
        if missing or stale:
            gh("issue", "edit", str(issue["number"]), "--repo", REPO,
               *sum((["--add-label", l] for l in missing), []),
               *sum((["--remove-label", l] for l in stale), []))
            if missing:
                print(f"    issue    labelled {', '.join(missing)}")
            if stale:
                print(f"    issue    unlabelled {', '.join(stale)}")
            actions += 1

        assignees = {a["login"] for a in issue.get("assignees", [])}
        if ISSUE_ASSIGNEE not in assignees:
            gh("issue", "edit", str(issue["number"]), "--repo", REPO,
               "--add-assignee", ISSUE_ASSIGNEE)
            print(f"    issue    assigned to {ISSUE_ASSIGNEE}")
            actions += 1

        # An archived record closes its issue, so the repo's open issues mean
        # "work in flight" without needing the board next to them.
        if issue.get("state", "OPEN").upper() != want_state:
            verb = "close" if want_state == "CLOSED" else "reopen"
            gh("issue", verb, str(issue["number"]), "--repo", REPO)
            print(f"    issue    {verb}d")
            actions += 1

        if url not in on_board:
            added = gh("project", "item-add", PROJECT_NUMBER, "--owner", PROJECT_OWNER,
                       "--url", url, "--format", "json")
            on_board[url] = json.loads(added)["id"]
            print(f"    board    card added")
            actions += 1
        else:
            print(f"    board    card present")

        gh(
            "project", "item-edit",
            "--project-id", project_id(),
            "--id", on_board[url],
            "--field-id", status_field_id(),
            "--single-select-option-id", status_option_id(record.status),
        )
        print(f"    board    {STATUS_FIELD} = {record.status}\n")

    print(f"{'Dry run — nothing changed.' if dry_run else f'{actions} update(s) applied.'}")
    return 0


# --- project metadata, resolved once per run -------------------------------

_cache: dict[str, object] = {}


def project_id() -> str:
    if "pid" not in _cache:
        raw = gh("project", "view", PROJECT_NUMBER, "--owner", PROJECT_OWNER, "--format", "json")
        _cache["pid"] = json.loads(raw)["id"]
    return _cache["pid"]  # type: ignore[return-value]


def _status_field() -> dict:
    if "field" not in _cache:
        raw = gh("project", "field-list", PROJECT_NUMBER, "--owner", PROJECT_OWNER, "--format", "json")
        for f in json.loads(raw)["fields"]:
            if f["name"] == STATUS_FIELD:
                _cache["field"] = f
                break
        else:
            raise RuntimeError(f"project field {STATUS_FIELD!r} not found")
    return _cache["field"]  # type: ignore[return-value]


def status_field_id() -> str:
    return _status_field()["id"]


def status_option_id(name: str) -> str:
    for opt in _status_field().get("options", []):
        if opt["name"] == name:
            return opt["id"]
    raise RuntimeError(f"{STATUS_FIELD} has no option {name!r}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true",
                        help="show what would change without touching GitHub")
    args = parser.parse_args()
    try:
        return sync(args.dry_run)
    except RuntimeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
