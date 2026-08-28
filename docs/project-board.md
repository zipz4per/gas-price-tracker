# Project Board

A Kanban view of the OpenSpec workflow, at
[github.com/users/zipz4per/projects/6](https://github.com/users/zipz4per/projects/6).

## The one thing to know

**The board is a projection of `openspec/`, and it is one-directional.**

Every run recomputes each card from the repository. Moving a card between
columns, editing an issue body, or ticking a checkbox on GitHub does **not**
move any work — and the next sync overwrites it.

To change what the board shows, change the repository: tick a task in a
change's `tasks.md`, or archive the change. Then run the sync.

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
progress it derived for every change, which is the fastest way to see whether
the board will land where you expect.

The sync is **idempotent** — running it twice in a row reports
`0 change(s) applied` the second time. Run it as often as you like.

### Prerequisites

`gh` authenticated with `project` scope:

```bash
gh auth status                # check: scopes must include 'project'
gh auth refresh -s project    # add it (opens a browser)
```

Without it, `gh project list` fails with a scope error and the sync stops
before writing anything.

## The columns

Status is derived from where a change lives and how many of its tasks are done:

| Column | Means | Derived from |
|---|---|---|
| **Proposed** | Planned, not started | In `openspec/changes/`, 0 tasks done |
| **In Progress** | Being implemented | In `openspec/changes/`, some tasks done |
| **Ready to archive** | Implementation finished, not yet archived | In `openspec/changes/`, all tasks done |
| **Done** | Archived | In `openspec/changes/archive/` |

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

One issue per change, titled `[change] <name>`. Every part of the body is read
out of the change itself:

| Part of the body | Comes from |
|---|---|
| Description | the first paragraph under `## Why` in `proposal.md` |
| **What changes** | the bullets under `## What Changes` |
| **Out of scope** | the bullets under `### Explicitly out of scope`, when there are any |
| Status and progress | the change's directory and its task checkboxes |
| Links | the artifacts present in the change directory |
| The checklist | `tasks.md` verbatim, so GitHub renders a native task list with a progress bar |

Nothing in an issue is written by hand, so nothing in an issue can disagree
with the repository. Changing what an issue says means editing the proposal.

The description sits **above** the checklist and is never folded behind a
`<details>` block. That costs roughly 200–280 words before the progress bar,
which is a deliberate trade: this repository is public and serves as a
portfolio, so the reader worth optimising for is one assessing the project
rather than one tracking a burndown, and a summary nobody expands is the same
as no summary.

### What this asks of a proposal

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

The same check rejects a proposal whose published text contains a `- [ ]` or
`- [x]` line. GitHub counts a checkbox anywhere in an issue body toward that
issue's task-list progress, so one in quoted prose would inflate the count on
GitHub while the board's own count, read from `tasks.md`, stayed correct.

Tasks are **not** separate cards. The six changes hold over a hundred tasks
between them; that many cards is not a board anyone reads, and a change is the
unit that actually moves between columns.

An archived change has its issue **closed**, so the repository's issue list is
meaningful on its own — open issues are work in flight, closed ones shipped.

## When something looks wrong

| Symptom | Cause | Fix |
|---|---|---|
| A card didn't move | The sync hasn't run since the change did | Run the sync |
| Duplicate cards for one change | The change was renamed; issues match by title | Close the orphaned issue and delete its card |
| `gh project list` scope error | Token lost `project` scope | `gh auth refresh -s project` |
| A card is missing entirely | Its issue was deleted | Just run the sync; it recreates from scratch |
| `N proposal(s) could not be read` | A proposal can't supply a description | Fix the section the error names; the sync wrote nothing |

Nothing here needs repair by hand beyond deleting orphans — the sync stores no
state, so there is no bookkeeping to get out of step.

## Not automated

The sync runs when you run it. There is deliberately no GitHub Actions
workflow: Actions' built-in `GITHUB_TOKEN` cannot write to Projects v2, so
automating this needs a personal access token with Projects read/write stored
as a repository secret. This repository is public, so that is a decision worth
making on its own terms rather than as a side effect of wanting a board.
