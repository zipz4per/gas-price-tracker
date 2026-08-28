## Why

A bug found in this project has nowhere to go. The board projects `openspec/`, and `openspec/` holds only changes — so a defect is either promoted into a change proposal it does not fit, or it lives in a commit message, a chat log, or nobody's memory. The one already found is instructive: `get_doe_reference_prices()` answers `has_data = false` for a fuel type it does not recognise, so `'RON 95'` reports no data while `'RON_95'` returns seven rows. That is a shipped read path returning a confident wrong answer, and today the only record of it is a conversation.

A bug is not a change. A change is a commitment — written up front, executed, archived. A bug is an observation, true whether or not anyone acts on it, and it can end at *won't fix* or *not a bug*, which no change ever does. It also accretes rather than being authored once: what is broken and how to reproduce it are known when it is filed, the root cause and the commit that caused it are known later, and what the fix changed is known last of all.

So a bug needs its own record with its own lifecycle, and that record needs to reach the board the same way everything else does — derived from the repository, never authored on GitHub. The alternative, filing bugs straight into GitHub, is the one option that breaks the board's founding property: nothing originates on the board, which is exactly why regenerating it is lossless.

## What Changes

- **Add `openspec/bugs/<name>/report.md`** as a first-class record alongside `openspec/changes/`, holding what is broken, how to reproduce it, the root cause, the commit that caused it, and what the fix changed.
- **Project bugs onto the existing board** through the same sync script, as issues titled `[bug] <name>` beside the existing `[change] <name>`.
- **Derive a third label axis, `kind:`, from location** — `openspec/bugs/` yields `kind: bug` and `openspec/changes/` yields `kind: feature` — so the axis cannot drift out of step with what a record is.
- **Map a bug's lifecycle onto the board's existing status column** rather than adding a field: reported and confirmed are Proposed, being fixed is In Progress, fixed is Ready to archive, archived is Done. *Won't fix* and *not a bug* are closures, not columns, and GitHub's "closed as not planned" already expresses them.
- **Record causation and repair as two symmetric commit fields.** "Never worked" is a first-class answer to what caused a bug, not an empty field.
- **Define when a bug becomes a change**: exactly when the fix changes what the system promises. A bug whose fix contradicts an existing scenario needs code and honest verification, not a proposal; a bug exposing a silent or wrong spec needs a change, and the bug record links to it.
- **Keep a bug open until its change archives**, rather than closing it the moment a change is filed. The bug is what someone searches for later; the change name is not what they will remember.
- **File the fuel-type bug through the new path** as the change's own end-to-end verification.

### Explicitly out of scope

- Fixing the fuel-type bug. This change gives it a record; repairing the read path is its own work, and the record is what says so.
- Any change to how the board's status field, capability labels, or layer labels already work. The `kind:` axis is added beside them.
- Triage process, severity ratings, assignment, or service levels. A record and a route to the board is the whole of it.
- Bidirectional sync. The board stays a projection; a bug edited on GitHub is still overwritten.

## Capabilities

### New Capabilities

None. A bug report is a record the project keeps about itself, not behaviour the project promises to anyone.

### Modified Capabilities

None.

## Impact

- **New:** `openspec/bugs/` and a `report.md` template for it.
- **Modified:** `scripts/sync-project-board.py` — discovery walks a second tree, labels gain a third derived axis, issue titles gain a second prefix, and the issue body is composed from a report rather than a proposal when the record is a bug.
- **Modified:** `docs/project-board.md` — the board now projects two kinds of record, and the labels section documents two axes.
- **New:** `openspec/bugs/doe-fuel-type-not-recognised/report.md`, the first bug filed.
- **Depends on:** the existing board sync, its derived-label convention, and its one-directional projection.
