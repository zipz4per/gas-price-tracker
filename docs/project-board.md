# Project Board

A Kanban view of the OpenSpec workflow, at
[github.com/users/zipz4per/projects/6](https://github.com/users/zipz4per/projects/6).

## The one thing to know

**The board is a projection of `openspec/`, and it is one-directional.**

Every run recomputes each card from the repository. Moving a card between
columns, editing an issue body, or ticking a checkbox on GitHub does **not**
move any work — and the next sync overwrites it.

To change what the board shows, change the repository: tick a task in a
change's `tasks.md` or a bug report's fix tasks, or archive the record. Then run
the sync.

The board carries **two kinds of record**. A change is a commitment, described
by a proposal and tracked by `tasks.md`. A bug is an observation, described by
a report under `openspec/bugs/` and tracked by whatever fix tasks that report
carries. They share the columns because their lifecycles are parallel; the
`kind:` label tells them apart.

That constraint is the point. A board maintained by hand drifts the moment
someone forgets to update it, and a drifted board is worse than none because
people believe it. Deriving everything means the only way the board can be
wrong is if `openspec/` is wrong — in which case it is correctly reporting a
real problem.

## Running it

```bash
python3 scripts/sync-project-board.py            # sync
python3 scripts/sync-project-board.py --dry-run  # show what would change
```

Start with `--dry-run`. It touches nothing on GitHub and prints the status and
progress it derived for every record, which is the fastest way to see whether
the board will land where you expect.

The sync is **idempotent** — running it twice in a row reports
`0 update(s) applied` the second time. Run it as often as you like.

### Prerequisites

`gh` authenticated with `project` scope:

```bash
gh auth status                # check: scopes must include 'project'
gh auth refresh -s project    # add it (opens a browser)
```

Without it, `gh project list` fails with a scope error and the sync stops
before writing anything.

## The columns

Status is derived from where a record lives and how many of its tasks are done:

| Column | A change means | A bug means | Derived from |
|---|---|---|---|
| **Proposed** | Planned, not started | Reported or confirmed | 0 tasks done |
| **In Progress** | Being implemented | Being fixed | Some tasks done |
| **Ready to archive** | Implementation finished, not yet archived | Fixed, record not yet closed | All tasks done |
| **Done** | Archived | Archived | In the tree's `archive/` |

**Won't fix** and **not a bug** have no column, because they are not stages —
they are closures. Close the issue as *not planned* and record the reason in
the report's `Fixed by`. A bug nobody intends to repair is worse as decoration
on a board of live work than it is closed honestly.

A bug also stays open until its change archives, rather than closing the moment
a change is filed to fix it. Six months on, the search is for the symptom, not
for the change that fixed it — a closed bug pointing at a change is a redirect,
an open one is the answer.

That wait is enforced rather than remembered: `/opsx:archive-bug` refuses to
move a bug whose report names a change until that change is itself in
`openspec/changes/archive/`.

**The two archive commands are not interchangeable.** `/opsx:archive` handles
changes; `/opsx:archive-bug` handles bugs. The OpenSpec CLI enumerates
`openspec/changes/` only, so it cannot see a bug at all, and the change
workflow's middle steps — artifact graph, `tasks.md`, delta-spec sync — have no
counterpart in a report. `openspec/bugs/README.md` covers the split and what it
costs to maintain.

`Ready to archive` is the one worth having. It catches a change whose work is
complete but which hasn't been archived and whose specs haven't been synced —
a real state that's easy to leave sitting.

Grouping uses a custom field called **`OpenSpec Status`**, not GitHub's
built-in `Status`. The built-in field is reserved: it ships with
`Todo / In Progress / Done` and cannot be deleted, recreated, or extended from
the CLI. Depending on it would mean the board could only be set up by clicking
through the web UI, which would break the guarantee that the board is
reproducible from the script alone.

If the board opens grouped by the wrong field, change the view's grouping to
`OpenSpec Status` once — a view preference, not something the sync manages.

## The cards

One issue per record. A change is titled `[change] <name>` and a bug
`[bug] <name>`, so the two can share a name without colliding. Every part of a
body is read out of the record itself.

**A change**, from `openspec/changes/<name>/`:

| Part of the body | Comes from |
|---|---|
| Description | the first paragraph under `## Why` in `proposal.md` |
| **What changes** | the bullets under `## What Changes` |
| **Out of scope** | the bullets under `### Explicitly out of scope`, when there are any |
| Status and progress | the change's directory and its task checkboxes |
| Links | the artifacts present in the change directory |
| The checklist | `tasks.md` verbatim, so GitHub renders a native task list with a progress bar |

**A bug**, from `openspec/bugs/<name>/`:

| Part of the body | Comes from |
|---|---|
| Description | the first paragraph under `## What's broken` in `report.md` |
| **Caused by** / **Fixed by** | those two sections, published together on one line |
| **Reproduction** | that section verbatim, in full |
| **Impact**, **Root cause**, **Does this need a change?** | those sections verbatim |
| Status and progress | the bug's directory and any checkboxes under `## Fix tasks` |
| The checklist | `## Fix tasks` verbatim, when the fix is tracked in the report rather than in a change |

Causation and repair are published together because a defect that shipped
broken and one that was working until a known commit are different findings,
and seeing only one of them invites the wrong conclusion. `never worked` is a
first-class answer, not an empty field.

The reproduction is carried in full rather than summarised. A report somebody
has to open the repository to act on is a report that gets argued with instead
of run.

Nothing in an issue is written by hand, so nothing in an issue can disagree
with the repository. Changing what an issue says means editing the proposal.

The description sits **above** the checklist and is never folded behind a
`<details>` block. That costs roughly 200–280 words before the progress bar,
which is a deliberate trade: this repository is public and serves as a
portfolio, so the reader worth optimising for is one assessing the project
rather than one tracking a burndown, and a summary nobody expands is the same
as no summary.

### What this asks of a proposal or a report

Because the opening paragraph of `## Why` is published, it has to stand on its
own — a reader sees it with no surrounding document. A proposal that opens with
a bullet, a sub-heading, a blockquote, or a table row **stops the sync** rather
than being trimmed into something that merely looks like a description, and so
does a proposal with no `## What Changes` bullets.

That is deliberate. Every one of these failures is silent if you let it pass:
a truncated summary reads exactly like a correct one. The sync would rather
refuse than publish a plausible wrong answer.

`### Explicitly out of scope` is the one optional part — a change that has no
out-of-scope section simply omits it.

A report is held to the same standard, section by section. It must carry
`## What's broken`, `## Impact`, `## Reproduction`, `## Root cause`,
`## Caused by`, `## Fixed by`, and `## Does this need a change?`, and each must
have content — a section whose answer is not yet known keeps a pending marker
like `_Not yet investigated._` rather than being left blank or dropped. An
absent section reads as an oversight; a pending one reads as a stage not yet
reached. An empty `## Reproduction` stops the sync outright: a report nobody
else can reproduce is a claim, not a finding.

Start from `openspec/bugs/report-template.md`, which carries every section and
its pending form.

The same check rejects a proposal whose published text contains a `- [ ]` or
`- [x]` line. GitHub counts a checkbox anywhere in an issue body toward that
issue's task-list progress, so one in quoted prose would inflate the count on
GitHub while the board's own count, read from `tasks.md`, stayed correct.

Tasks are **not** separate cards. Nine changes hold 188 tasks between them;
that many cards is not a board anyone reads, and a record is the unit that
actually moves between columns.

An archived record has its issue **closed**, so the repository's issue list is
meaningful on its own — open issues are work in flight, closed ones shipped.

## The labels

Three axes, filtered independently:

| Label | Answers | Comes from | Derived or declared |
|---|---|---|---|
| `capability: <name>` | what the record is about | a change's `specs/` directories; a bug's `capability:` | derived for a change, **declared** for a bug |
| `layer: <backend\|frontend\|tooling>` | where the work lives | `layer:` in `.openspec.yaml` | **declared** |
| `kind: <feature\|bug>` | work, or a defect | which tree the record sits in | derived |

A record carries one label from each axis, except a tooling one, which touches
no capability and carries only its layer and kind.

`capability:` and `layer:` are separate axes because a capability spans layers. `price-reports` will
eventually hold both the server-side rate limiting PRD FR-12 requires — the
client can be bypassed, so the check cannot live there — and the submission
flow FR-5 describes. A layer attached to that capability would be wrong
whichever value it took. A change, by contrast, sits on one side; the rare one
that genuinely spans both says so with two labels.

### Why `kind:` is derived and the others are not

`kind:` is the only label here that nothing declares. A record under
`openspec/bugs/` is `kind: bug` and one under `openspec/changes/` is
`kind: feature`, and the directory answers the question completely — there is
no case where the path is right and the label should differ.

Deriving beats declaring whenever deriving cannot be wrong. `layer:` has to be
declared because nothing in the tree implies it: the sync reads the planning
directory, never a diff, so it cannot tell client work from server work by
looking. `kind:` has no such gap, so declaring it would only add a field that
can be mistyped in contradiction of a path that is already correct.

A `kind:` key in an `.openspec.yaml` is therefore **rejected**, not ignored. An
ignored declaration is worse than a rejected one, because it reads as though it
took effect.

### The one label on a bug that can be wrong

A change's capabilities are derived from the `specs/` directories it writes
deltas for, so they cannot disagree with the change. A bug has no `specs/`
directory — it is a record about behaviour that already exists, not a proposal
to change it — so it declares its capability instead:

```yaml
capability: doe-reference-prices
layer: backend
```

The declared value must name a directory under `openspec/specs/`. One that does
not **stops the sync**, for the same reason a bad layer does: a typo would
otherwise create a plausible new label that filters into nothing. A bug whose
layer is `tooling` may omit the capability, matching how a tooling change
carries none.

### Declaring a layer

Nothing in `openspec/` reveals whether a change is client or server work — the
sync reads the planning directory, never a diff — so each record states it,
beside the `skip_specs` marker the board already trusts:

```yaml
schema: spec-driven
created: 2026-08-28
skip_specs: true
layer: tooling
```

A change with no `layer:`, or with a value outside `backend`, `frontend`, and
`tooling`, **stops the sync** and is named in the error. A typo would otherwise
create a plausible new label — `layer: backedn` looks right on a card and
filters into nothing.

### What the sync will and will not touch

The sync reconciles labels rather than only adding them: each run computes what
an issue should carry, adds what is missing, and removes anything stale. That
removal is scoped to the three prefixes above.

```
  capability: …  ─┐
  layer: …        ├─ managed: added and removed every run
  kind: …        ─┘

  enhancement, good first issue, anything applied by hand  ─  never touched
```

An unmanaged label is left alone permanently. A board that deletes a label
someone applied by hand teaches people not to use labels.

One consequence worth knowing: the retired bare `tooling` label is removed from
the issues that carried it, but the label itself is left in the repository,
unused. Deleting a label removes it from every issue that ever carried it,
which is destructive enough to be a person's decision rather than a sync's.

Comments are in the second category, permanently. The sync never reads or writes
them.

## Commits

Every commit names the record that explains it, in a trailer:

```
Refs: add-commit-issue-links #14
```

GitHub turns that into a *referenced this issue* event on the card's issue, so
each card links to the commits that implemented it and each commit links back to
the reasoning behind it. The full convention, the one-time
`git config core.hooksPath .githooks`, and why there is no exemption are in
[commit-conventions.md](commit-conventions.md).

This is not part of the projection. `openspec/` still decides everything the
sync writes; a commit trailer only asks GitHub to draw a line between an issue
that already exists and a commit that already exists.

One thing on those issues is neither derived nor managed. The thirty commits
that predate the convention carry no trailer, and history was not rewritten to
add one, so `scripts/backfill-commit-links.py` posted each issue's commits as a
**comment** instead. Those comments:

```
  are written once, by hand, by that script     not by the sync
  survive every sync                            the sync never touches comments
  are lost if the board is rebuilt              re-run the script
```

They are the one place this board holds something it cannot regenerate from
`openspec/`, and the trade was deliberate: the alternative was rewriting from
the root commit, which moves all thirty shas and dangles the thirteen the
records cite.

## Dependencies

An issue's **blocked by** edges are derived the same way everything else is,
and from two different places depending on the record.

```
  a bug      derived   from its report's `## Fixed by`, when that names a
                       change rather than a commit
  a change   declared  in .openspec.yaml, as blocked_by: [<change-name>, …]
```

That asymmetry is deliberate. A bug's report already names the change that
fixes it, and `/opsx:archive-bug` already reads that same line to decide whether
the bug may close — deriving the edge means the board and the gate cannot
disagree. A change has no equivalent sentence; its proposal names capabilities,
not other changes. So it says what it waits on outright, and a bug declaring
`blocked_by:` is rejected the way a declared `kind:` is.

A declared name must resolve to a change directory, active or archived, and one
that does not stops the run. A change that names itself, or a set of changes
that form a loop, stops it too — the repository is where that mistake is, and
GitHub would otherwise reject one edge and leave the rest written.

**Edges are reconciled, exactly like labels.**

```
  between two board issues  ─  added and removed every run
  to any other issue        ─  never touched
```

An edge the repository does not state is removed, or a hand-drawn one would
become a second source of truth the projection cannot see. An edge pointing at
an issue this board did not create was drawn by a person about something
outside this workflow, and is left alone for the same reason an unmanaged label
is.

**A closed blocker stays written.** `[bug] doe-fuel-type-not-recognised` is
blocked by `[change] fix-unrecognised-read-inputs`, which is archived and
closed. The edge is the record of why the bug waited; GitHub renders a closed
blocker as satisfied rather than as an open constraint, so there is nothing to
clean up.

**Causation is a reference, not an edge.** A bug's `## Caused by` names a
commit, and the sync resolves that commit to the change that carries it — but
only when the commit touched exactly one change directory, since most touch
none and the repository's first commit touched three. A resolved cause is
published in the body as `add-doe-price-retrieval #1`, which GitHub links and
records on the causing issue's timeline.

It is not marked as *blocking*. The causing change is finished and cannot
discharge an obligation, so a blocking edge would show a live constraint nobody
can act on, and Done would stop meaning finished. GitHub's API has no
`relates to`, so a body reference is the accurate representation available.

Edges are written after every issue exists, so one can never name a card that
has not been created yet. This costs nothing on an established board and means
a first run on an empty one still ends correct.

## When something looks wrong

| Symptom | Cause | Fix |
|---|---|---|
| A card didn't move | The sync hasn't run since the change did | Run the sync |
| Duplicate cards for one change | The change was renamed; issues match by title | Close the orphaned issue and delete its card |
| `gh project list` scope error | Token lost `project` scope | `gh auth refresh -s project` |
| `N problem(s) in openspec/` | A record has no valid `layer:`, a bug's `capability:` names no spec directory, a `kind:` or a bug's `blocked_by:` is declared, a `blocked_by:` names no change or forms a cycle, or a proposal or report can't supply a description | Fix what the error names; the sync wrote nothing |
| An edge you drew by hand vanished | Edges between board issues are reconciled from `openspec/` | Declare it in `.openspec.yaml`, or accept that the repository doesn't state it |
| A card is missing entirely | Its issue was deleted | Just run the sync; it recreates from scratch |
| A commit isn't shown on its issue | The reference only appears once the commit is on the default branch | Push |
| `commit-msg: no Refs: trailer` | Every commit names its record; there is no exemption | Add `Refs: <name> #<n>`, or create the record it belongs to first |
| `commit-msg` never fires | `core.hooksPath` isn't set in this clone | `git config core.hooksPath .githooks` |
| Backfill comments gone after a rebuild | They are comments, not projection; the sync cannot regenerate them | Re-run `scripts/backfill-commit-links.py` |

Nothing here needs repair by hand beyond deleting orphans and re-running the
backfill — the sync stores no state, so there is no bookkeeping to get out of
step. That still holds now that
edges are part of what a run produces: they are recomputed from `openspec/` and
matched through issue titles, so a deleted issue is recreated and its edges are
redrawn with it, new number and all.

## Not automated

The sync runs when you run it. There is deliberately no GitHub Actions
workflow: Actions' built-in `GITHUB_TOKEN` cannot write to Projects v2, so
automating this needs a personal access token with Projects read/write stored
as a repository secret. This repository is public, so that is a decision worth
making on its own terms rather than as a side effect of wanting a board.
