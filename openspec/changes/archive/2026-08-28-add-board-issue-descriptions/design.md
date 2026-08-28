## Context

See `proposal.md` — Why.

`build_issue_body()` in `scripts/sync-project-board.py` composes the body from three sources today: a header line of derived status and progress, a list of relative links to the change's artifacts, and `tasks.md` verbatim. It links `proposal.md` and never opens it.

Constraints that shape the approach:

- **The script is standard library only** — `argparse`, `json`, `re`, `subprocess`, `sys`, `dataclasses`, `pathlib`. Adding a markdown parser to read four sections would be the project's first runtime dependency on a script that is otherwise a single file anyone can read.
- **The sync is a projection.** Every run recomputes the body from the repository. There is no stored state, so there is nothing to migrate and no reconciliation step — a changed format simply lands on the next run.
- **The bodies are already overwritten when they differ** (`scripts/sync-project-board.py:294`), so republishing every issue once is the normal code path.
- **All five existing proposals share a fixed shape**: `## Why` opening with a prose paragraph, `## What Changes` with top-level bullets, and in four of five a `### Explicitly out of scope` subsection. None contains a markdown link or a checkbox-shaped line.
- **GitHub counts `- [ ]` anywhere in an issue body** toward the issue's task-list progress. Task counting on the board is derived from `tasks.md` on disk and is unaffected, but the progress bar GitHub renders on the issue is not.

## Goals / Non-Goals

**Goals:**

- The description a reader sees is the proposal's own words, with no second copy anywhere.
- A proposal that cannot supply a description stops the run rather than producing a plausible one.
- `tasks.md` and everything derived from it — status, progress, labels — behave exactly as before.

**Non-Goals:**

- Rendering or validating markdown. The extracted text is passed through unmodified; GitHub renders it.
- Tolerating arbitrary proposal shapes. The extractor targets the structure OpenSpec's proposal template produces, and says so when it does not find it.
- Any change to issue identity, titles, or the matching in `find_issue()`.

## Decisions

### Extract by scanning headings, not by parsing markdown

A line scanner that tracks the current `##` and `###` heading is enough for all four extractions and keeps the script dependency-free. The alternative — `markdown-it-py` or similar — buys correct handling of nested constructs the proposals do not contain, at the cost of an install step for a script whose whole appeal is that `python3 scripts/sync-project-board.py` just works.

The extractor is deliberately literal about structure rather than tolerant. Tolerance is what produces a confident wrong summary.

### Four extractions, with distinct failure semantics

| Extraction | Rule | Missing means |
|---|---|---|
| Lead paragraph | Lines under `## Why` up to the first blank line | **error** |
| What Changes bullets | `- ` lines under `## What Changes`, before any `###` | **error** |
| Out of scope bullets | `- ` lines under `### Explicitly out of scope` | omit the section |
| Everything else | unchanged | — |

The lead paragraph must be prose: if the first non-blank line under `## Why` begins with `-`, `#`, `>`, or `|`, that is an error rather than something to coerce. A single bullet published as a change's description reads as if the summary were truncated, and nothing about it looks broken enough to notice.

Out-of-scope is the one optional part because `bootstrap-repo-and-supabase` genuinely has none — absence there is a fact about the change, not a defect in the proposal.

### Preflight every proposal before touching GitHub

Extraction runs for all changes first. If any fails, the run aborts having written nothing, naming the change and the missing section.

The alternative is skipping the offending change and syncing the rest, which leaves the board in a state where one card is silently stale and four are current — the exact condition the board exists to prevent. Aborting matches the existing behaviour for a missing `project` scope, where the sync stops before writing anything, and it keeps the invariant that a completed run means the whole board is correct.

`--dry-run` reports the same errors without the abort being consequential, which makes it the natural way to check a new proposal.

### Reject checkbox-shaped lines in extracted prose

If any extracted line matches `- [ ]` or `- [x]`, the run aborts. Such a line would be silently absorbed into the issue's task-list progress bar, so an issue with 16 real tasks would report 17 items and a wrong percentage. Escaping the brackets instead would publish text that differs from the proposal, which defeats the point of quoting it verbatim.

No current proposal contains one. This is a guard against a future one, and it costs a single check.

### Body order: description, then status, then links, then tasks

```
  ┌────────────────────────────────┐
  │ <!-- generated -->             │
  │ lead paragraph      ← ## Why   │
  │ Status · Tasks                 │
  │ **What changes**    ← bullets  │
  │ **Out of scope**    ← if any   │
  │ proposal · design · spec links │
  │ ────────────────────────────   │
  │ tasks.md verbatim              │
  └────────────────────────────────┘
```

The description leads because a body that opens with a link list reads as navigation. Status stays high because it is the one line someone scanning for state wants. Links move below the prose: they are what you click *after* deciding you care.

### Sections stay visible rather than folded

Chosen deliberately over `<details>`. The body grows to roughly 200–280 words above the checklist, which pushes GitHub's progress bar below the fold on a change with many tasks. That cost is accepted: this repository is public and serves as a portfolio, so the reader being optimised for is one assessing the project, not one tracking a burndown. A folded summary is a summary nobody reads, which returns the board to its current state.

## Risks / Trade-offs

- **A future proposal opens `## Why` with a bullet or a sub-heading** → the sync aborts and names the change. Loud by design; the fix is one paragraph in the proposal.
- **The first paragraph becomes a published surface**, so proposal authors now carry an unstated obligation to make it stand alone → stated explicitly in `docs/project-board.md`, and enforced only in the sense that a violation is visible rather than silent.
- **The checklist sits below ~250 words** on every issue → accepted, per the visible-not-folded decision above.
- **Prose containing a relative markdown link would not resolve from an issue** → no proposal contains one; they reference files as backticked paths, which render as text. Not guarded, because a broken link is visibly broken, unlike a wrong summary.
- **Every issue body is rewritten on the next run** → the sync already updates bodies that differ; the run reports each one, and a second run reports zero changes.

## Migration Plan

None required. Run the sync; every body updates in one pass. Rollback is reverting the script and running it again — the previous bodies are recomputed from the same repository, since nothing about them was ever stored.
