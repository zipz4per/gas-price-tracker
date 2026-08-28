#!/usr/bin/env python3
"""Project the OpenSpec workflow onto a GitHub Project board.

The board is DERIVED, never maintained. Every run recomputes each change's
status and progress from `openspec/` — a change's directory says which column
it belongs in, and its task checkboxes give its progress:

    openspec/changes/<name>/           0 tasks done   ->  Proposed
    openspec/changes/<name>/           some done      ->  In Progress
    openspec/changes/<name>/           all done       ->  Ready to archive
    openspec/changes/archive/<name>/                  ->  Done

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

ISSUE_TITLE_PREFIX = "[change] "

# Labels are derived like everything else: a change's specs/ directory names
# the capabilities it touches, and a change declaring skip_specs is tooling.
# Two axes, filtered independently: `capability:` says what a change is about,
# `layer:` says where the work lives. They are not alternatives — a change has
# both, except a tooling change, which touches no capability. Collapsing them
# into one field is what made `tooling` look like a capability.
CAPABILITY_LABEL_PREFIX = "capability: "
LAYER_LABEL_PREFIX = "layer: "
MANAGED_LABEL_PREFIXES = (CAPABILITY_LABEL_PREFIX, LAYER_LABEL_PREFIX)

# A closed set. An unrecognised value would otherwise flow into ensure_labels(),
# which creates whatever it is handed, and the change would look correctly
# labelled while carrying a label nobody else shares.
LAYERS = ("backend", "frontend", "tooling")

CAPABILITY_LABEL_COLOR = "0e8a16"
LAYER_LABEL_COLORS = {
    "backend": "1d76db",
    "frontend": "d93f0b",
    "tooling": "5319e7",  # the colour the retired bare `tooling` label used
}
ARCHIVE_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}-")

# A checkbox anywhere in an issue body is counted by GitHub's task-list
# progress bar, so one in quoted prose would inflate an issue's task count
# while the board's own count — read from tasks.md — stayed right.
CHECKBOX_RE = re.compile(r"^- \[[ xX]\] ")

# A lead paragraph must be prose. These prefixes mark a bullet, heading,
# blockquote, or table row, none of which reads as a description.
NON_PROSE_PREFIXES = ("-", "*", "+", "#", ">", "|")

REPO_ROOT = Path(__file__).resolve().parent.parent
CHANGES_DIR = REPO_ROOT / "openspec" / "changes"
ARCHIVE_DIR = CHANGES_DIR / "archive"


def gh(*args: str, check: bool = True) -> str:
    """Run a gh command and return stdout. Fails loudly rather than guessing."""
    result = subprocess.run(
        ["gh", *args], capture_output=True, text=True, cwd=REPO_ROOT
    )
    if check and result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)}\n{result.stderr.strip()}")
    return result.stdout.strip()


@dataclass
class Change:
    name: str
    path: Path
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
        return f"{ISSUE_TITLE_PREFIX}{self.name}"

    @property
    def progress(self) -> str:
        return f"{self.done}/{self.total}" if self.total else "no tasks"

    @property
    def labels(self) -> list[str]:
        """Both axes together. Capabilities come from the change's specs/
        directory and the layer from its .openspec.yaml, so neither can fall
        out of step with what the change actually is."""
        labels = [f"{CAPABILITY_LABEL_PREFIX}{c}" for c in self.capabilities]
        if self.layer:
            labels.append(f"{LAYER_LABEL_PREFIX}{self.layer}")
        return labels


def count_tasks(change_dir: Path) -> tuple[int, int]:
    """Count completed vs total tasks. A change with no tasks.md is not an
    error — some changes are pure planning — so it reports zero progress."""
    tasks = change_dir / "tasks.md"
    if not tasks.is_file():
        return 0, 0
    text = tasks.read_text(encoding="utf-8")
    done = len(re.findall(r"(?m)^- \[x\] ", text))
    todo = len(re.findall(r"(?m)^- \[ \] ", text))
    return done, done + todo


def read_capabilities(change_dir: Path) -> tuple[str, ...]:
    specs = change_dir / "specs"
    if not specs.is_dir():
        return ()
    return tuple(sorted(p.parent.name for p in specs.rglob("spec.md")))


def reads_skip_specs(change_dir: Path) -> bool:
    cfg = change_dir / ".openspec.yaml"
    if not cfg.is_file():
        return False
    return "skip_specs: true" in cfg.read_text(encoding="utf-8")


LAYER_RE = re.compile(r"(?m)^layer:\s*(\S+)\s*$")


def read_layer(change_dir: Path) -> str:
    """The layer a change declares, or "" when it declares none.

    Declared rather than derived: the sync reads only the planning directory,
    never a diff, so nothing here can tell client work from server work by
    looking. Validation happens in preflight, where a bad value can stop the
    run before it reaches ensure_labels()."""
    cfg = change_dir / ".openspec.yaml"
    if not cfg.is_file():
        return ""
    found = LAYER_RE.search(cfg.read_text(encoding="utf-8"))
    return found.group(1) if found else ""


def discover_changes() -> list[Change]:
    changes: list[Change] = []

    for d in sorted(CHANGES_DIR.iterdir()) if CHANGES_DIR.is_dir() else []:
        if not d.is_dir() or d.name == "archive":
            continue
        done, total = count_tasks(d)
        changes.append(Change(d.name, d, False, done, total,
                              read_capabilities(d), reads_skip_specs(d),
                              read_layer(d)))

    for d in sorted(ARCHIVE_DIR.iterdir()) if ARCHIVE_DIR.is_dir() else []:
        if not d.is_dir():
            continue
        # Archived directories carry a YYYY-MM-DD- prefix; the change's real
        # name is what the issue title must match, so strip it.
        name = ARCHIVE_DATE_RE.sub("", d.name)
        done, total = count_tasks(d)
        changes.append(Change(name, d, True, done, total,
                              read_capabilities(d), reads_skip_specs(d),
                              read_layer(d)))

    return changes


class ProposalError(RuntimeError):
    """A proposal that cannot supply a description.

    Raised during preflight, before anything is written, because the
    alternative — publishing whatever the parse happened to return — produces
    an issue that looks fine and describes the wrong thing."""


@dataclass(frozen=True)
class Description:
    """The parts of a proposal that get published on its issue."""
    lead: str
    changes: tuple[str, ...]
    out_of_scope: tuple[str, ...]


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


def extract_description(change: Change) -> Description:
    """Read a change's published description out of its proposal.

    Nothing here is inferred or repaired. Every failure raises, because the
    failures this guards against are the quiet ones: a summary that is merely
    plausible reads exactly like a correct one."""
    path = change.path / "proposal.md"
    try:
        where = path.relative_to(REPO_ROOT).as_posix()
    except ValueError:  # outside the repo; the absolute path is still useful
        where = str(path)

    def fail(problem: str) -> ProposalError:
        return ProposalError(f"{change.name}: {problem} ({where})")

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

    for line in (*lead, *changes, *out_of_scope):
        if CHECKBOX_RE.match(line):
            raise fail(
                f"published text contains a checkbox: {line.strip()[:48]!r}; "
                "GitHub would count it in the issue's task-list progress"
            )

    return Description(" ".join(lead), changes, out_of_scope)


def check_layer(change: Change) -> list[str]:
    """Validate a change's declared layer, returning problems rather than
    raising, so one pass can report every change that needs attention.

    An undeclared layer is an omission and an unrecognised one is a typo, and
    both produce the same silent outcome if allowed through: a card that looks
    labelled and filters into nothing."""
    cfg = (change.path / ".openspec.yaml")
    try:
        where = cfg.relative_to(REPO_ROOT).as_posix()
    except ValueError:
        where = str(cfg)
    allowed = ", ".join(LAYERS)
    if not change.layer:
        return [f"{change.name}: no 'layer:' declared; expected one of "
                f"{allowed} ({where})"]
    if change.layer not in LAYERS:
        return [f"{change.name}: unrecognised layer {change.layer!r}; expected "
                f"one of {allowed} ({where})"]
    return []


def build_issue_body(change: Change, desc: Description) -> str:
    """Compose the issue body from the proposal and tasks.md.

    Order matters. The description leads, because a body opening with a link
    list reads as navigation rather than as a document. Status stays high — it
    is the one line someone scanning for state wants. Links sit below the
    prose: they are what you click after deciding you care. Nothing here is
    folded behind <details>; a summary nobody expands is the state this
    change exists to fix."""
    rel = change.path.relative_to(REPO_ROOT).as_posix()
    lines = [
        "<!-- Generated by scripts/sync-project-board.py. Edits here are overwritten. -->",
        "",
        desc.lead,
        "",
        f"**Status:** {change.status} · **Tasks:** {change.progress}",
        "",
        "**What changes**",
        "",
        *desc.changes,
    ]
    if desc.out_of_scope:
        lines += ["", "**Out of scope**", "", *desc.out_of_scope]

    lines += ["", f"- [proposal]({rel}/proposal.md)"]
    if (change.path / "design.md").is_file():
        lines.append(f"- [design]({rel}/design.md)")
    specs = sorted((change.path / "specs").rglob("spec.md")) if (change.path / "specs").is_dir() else []
    for spec in specs:
        lines.append(f"- [spec: {spec.parent.name}]({spec.relative_to(REPO_ROOT).as_posix()})")
    lines.append("")

    tasks = change.path / "tasks.md"
    if tasks.is_file():
        # Verbatim: OpenSpec already writes GitHub checkbox markdown, so the
        # native task list and its progress bar need no transformation.
        lines.append("---")
        lines.append("")
        lines.append(tasks.read_text(encoding="utf-8").rstrip())
    else:
        lines.append("_No tasks file._")

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


def ensure_labels(changes: list[Change]) -> None:
    """Create any label the sync is about to use. --force makes this
    idempotent: it updates an existing label rather than failing."""
    wanted: dict[str, tuple[str, str]] = {}
    for change in changes:
        for label in change.labels:
            if label.startswith(CAPABILITY_LABEL_PREFIX):
                cap = label[len(CAPABILITY_LABEL_PREFIX):]
                wanted[label] = (CAPABILITY_LABEL_COLOR,
                                 f"Changes affecting the {cap} capability")
            else:
                layer = label[len(LAYER_LABEL_PREFIX):]
                wanted[label] = (LAYER_LABEL_COLORS[layer],
                                 f"Changes whose work lives in the {layer} layer")
    existing = {l["name"] for l in json.loads(
        gh("label", "list", "--repo", REPO, "--limit", "100", "--json", "name") or "[]")}
    for name, (color, desc) in sorted(wanted.items()):
        if name not in existing:
            gh("label", "create", name, "--repo", REPO,
               "--color", color, "--description", desc, "--force")
            print(f"  label created: {name}")


def sync(dry_run: bool) -> int:
    changes = discover_changes()
    if not changes:
        print("No changes found under openspec/changes/.")
        return 1

    print(f"Found {len(changes)} change(s)\n")

    # Preflight. Every proposal is read before anything is written, so a
    # proposal that cannot supply a description stops the whole run rather
    # than leaving one card stale beside four current ones — the exact
    # condition a derived board exists to make impossible. Every failure is
    # reported, not just the first, so one pass names all the work.
    descriptions: dict[str, Description] = {}
    failures: list[str] = []
    for change in changes:
        try:
            descriptions[change.name] = extract_description(change)
        except ProposalError as exc:
            failures.append(str(exc))
        failures.extend(check_layer(change))
    if failures:
        sys.stdout.flush()  # keep the report above the errors, not after them
        for failure in failures:
            print(f"error: {failure}", file=sys.stderr)
        print(f"\n{len(failures)} problem(s) in openspec/. Nothing was written.",
              file=sys.stderr)
        return 1

    if not dry_run:
        ensure_labels(changes)
    on_board = {} if dry_run else project_items()
    actions = 0

    for change in changes:
        body = build_issue_body(change, descriptions[change.name])
        issue = find_issue(change.issue_title)
        want_state = "CLOSED" if change.archived else "OPEN"

        print(f"  {change.name}")
        print(f"    status   {change.status}  ({change.progress})")
        if change.labels:
            print(f"    labels   {', '.join(change.labels)}")

        if dry_run:
            print(f"    issue    {'update' if issue else 'create'} (dry run)")
            print(f"    board    set {STATUS_FIELD} = {change.status} (dry run)\n")
            continue

        if issue is None:
            url = gh(
                "issue", "create", "--repo", REPO,
                "--title", change.issue_title, "--body", body,
                "--assignee", ISSUE_ASSIGNEE,
                *sum((["--label", l] for l in change.labels), []),
            ).splitlines()[-1]
            issue = {"url": url, "number": url.rsplit("/", 1)[-1], "state": "OPEN",
                     "body": body, "assignees": [{"login": ISSUE_ASSIGNEE}],
                     "labels": [{"name": l} for l in change.labels]}
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

        # Labels are reconciled, not merely added. The sync owns exactly two
        # prefixes; a stale one inside them is removed, and every other label
        # — `bug`, anything applied by hand — is left alone, because a board
        # that deletes someone's label teaches people not to use labels.
        have = {l["name"] for l in issue.get("labels", [])}
        want = set(change.labels)
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

        # An archived change closes its issue, so the repo's open issues mean
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
            "--single-select-option-id", status_option_id(change.status),
        )
        print(f"    board    {STATUS_FIELD} = {change.status}\n")

    print(f"{'Dry run — nothing changed.' if dry_run else f'{actions} change(s) applied.'}")
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
