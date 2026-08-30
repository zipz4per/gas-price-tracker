# Link every commit to the record that explains it

## Why

Thirty commits, and nothing in any of them says which record it belongs to. The
mapping exists — 24 of the 30 touch exactly one record's directory, and that is
how the table in this change's tasks was built — but it is recovered by
inspection, not stated. From a commit you cannot reach the proposal that
justified it; from an issue you cannot reach the code that closed it.

Two commits show what the absence costs, and they are the two the path
inference cannot recover:

- `dbcb277 Write board issue links as absolute blob URLs` is the fix for
  `board-issue-links-are-relative`, committed a day before the bug was filed.
  The record exists. Nothing connects them but the sha typed into the report's
  *Fixed by* line, which points one way only.
- `63f9b00 Give bug reports an archive workflow of their own` shipped a skill,
  a command, four gates and two edits to generated files. **No record in
  `openspec/` describes any of it.** The board shows nothing, because the board
  projects `openspec/`, and `openspec/` never heard about it.

The second is the real failure. A change is supposed to be a commitment
authored before the work; that one was authored nowhere. Nothing caught it,
because nothing was looking.

## What Changes

- **A `Refs:` trailer on every commit**, naming the record and its issue:
  `Refs: add-commit-issue-links #14`. A commit touching several records repeats
  the trailer, once per record. GitHub turns the `#14` into a cross-reference
  event on the issue, so the link is live in both directions.
- **A tracked `commit-msg` hook** at `.githooks/commit-msg` that rejects a
  message with no trailer, or one naming a record that does not exist under
  `openspec/`. Offline and self-contained; it verifies the issue number too when
  `gh` happens to be authenticated, and stays silent when it is not.
- **No exemption.** There is no `Refs: none`. Repository hygiene gets a record
  like everything else. The four historical commits that have none stay as they
  are and are named in this proposal rather than quietly grandfathered.
- **A one-time backfill** posting each issue's pre-rule commits as a comment, so
  past work carries the same link. Idempotent by reading its own marker back;
  it stores nothing.
- **`change_for_commit()` prefers the trailer.** The sync infers a commit's
  change from the paths it touched, which leaves 10 commits of 30 unresolved —
  8 touching no change directory and 2 touching several. Reading a trailer
  resolves it exactly, and the fallback stays for everything older.
- **A retro record for `63f9b00`**, filed and archived in the same breath,
  describing what already shipped and saying plainly that it was written after
  the fact.

## Explicitly out of scope

- **Rewriting history to add trailers.** `8f2488e` is the root, so annotating it
  moves all 30 shas. This repository cites its own shas in 13 places, two of
  them inside sealed records in `openspec/bugs/archive/`; the live bodies of #10
  and #11 embed three more, and the cross-references derived from them would
  degrade to nothing without erroring. The uniformity is not worth a force-push
  and two falsified reports.
- **Retro records for the four hygiene commits.** `8f2488e`, `0d0be1e`,
  `4fb82e3` and `6902259` predate the rule and get none. Naming them here is the
  record.
- **Blocking the sync on an unreferenced commit.** The sync projects
  `openspec/`; git history is not its input. The hook is the enforcement point.
- **Requiring a particular subject line, body, or conventional-commit prefix.**
  This change constrains one trailer and nothing else about how a message reads.
- **Closing an issue from a commit** (`Fixes #14`). Status is derived from which
  directory a record sits in. A keyword that closes an issue would let git
  history move a card, which is the one thing the board forbids.

## Capabilities

None. `skip_specs: true` — see `.openspec.yaml`.

## Impact

- New: `.githooks/commit-msg`, `docs/commit-conventions.md`,
  `scripts/backfill-commit-links.py`
- Modified: `scripts/sync-project-board.py` (`change_for_commit()`)
- New record: `openspec/changes/archive/2026-08-30-add-bug-archive-workflow/`
- Requires a one-time `git config core.hooksPath .githooks` per clone. A
  repository cannot set that for you, so the hook is opt-in by construction and
  the documentation has to say so.
