## Context

See `proposal.md` — Why. The repository holds four OpenSpec changes: three archived, one active. `gh` 2.98.0 is authenticated as `zipz4per` with `gist, project, read:org, repo, workflow`, and the account currently owns no projects.

Two facts about the tooling shape this design:

- **`gh project item-edit` accepts `--field <name> --value <text>`** in this version, so setting a `Status` column does not require resolving project id, field id, and single-select option id by hand. An earlier assessment of this work assumed otherwise; the simpler path is available.
- **`tasks.md` is already GitHub-flavored checkbox markdown.** Pasted into an issue body it renders as a native task list with a progress bar, so no transformation is needed and the rendering stays correct as tasks are ticked off.

## Goals / Non-Goals

**Goals:**

- A board that cannot drift from `openspec/`, because every run recomputes from it.
- Idempotence: running the sync twice produces the same result as running it once.
- Readable at a glance — a handful of cards, each showing its own progress.

**Non-Goals:**

- CI automation. Deferred deliberately; see the last decision below.
- Writing anything back into `openspec/`. The sync is strictly one-directional.
- Board customisation beyond a `Status` field — no iterations, estimates, or custom views.
- Handling concurrent runs. This is a single-operator script.

## Decisions

### The board is derived from `openspec/`, never maintained alongside it

Status and progress are computed on every run from directory location and checkbox counts. No state file, no stored mapping of change → card.

*Why:* a board that is updated by hand drifts the moment someone forgets, and a board that drifts is worse than no board because it is believed. Deriving everything means the only way for the board to be wrong is for `openspec/` to be wrong, in which case the board is faithfully reporting a real problem.

*Alternative rejected:* recording card ids in a manifest committed to the repo. Faster lookups, and one more thing to keep consistent — and it would make a hand-deleted card permanently invisible to the sync.

### One issue per change; tasks are checkboxes in its body

A change becomes a single issue whose body is its `tasks.md`, plus links to its proposal and design.

*Why:* the four changes currently hold over sixty tasks between them. Sixty cards is not a board anyone reads. A change is also the unit that actually moves between columns — tasks within a change do not have independent lifecycles. Keeping tasks as checkboxes in the body preserves the detail without fragmenting the view, and GitHub's progress bar gives per-card progress for free.

*Alternative rejected:* one card per task. Accurate, unreadable.

### Issues are matched by title, not by a stored id

The sync finds an existing issue by searching for one whose title matches the change name, and creates one only if none exists.

*Why:* it keeps the repository free of sync bookkeeping, and it degrades well — if an issue is deleted, the next run recreates it rather than failing on a dangling reference. The cost is that renaming a change orphans its issue, which is acceptable: OpenSpec change names are stable once created, and an orphan is visible rather than silent.

### An archived change closes its issue

When a change is found under `openspec/changes/archive/`, its issue is closed and its card set to `Done`.

*Why:* it makes the repository's issue list meaningful on its own — open issues are work in flight, closed ones are shipped — rather than being a list that only makes sense next to the board. It also means the board's `Done` column and the repo's closed issues cannot disagree.

### Status lives in a custom field, because the built-in one is immovable

The board groups on a custom single-select field named `OpenSpec Status`, not GitHub's built-in `Status`.

*Why:* the built-in field is reserved. It ships with `Todo / In Progress / Done` and cannot be deleted (`Only custom fields can be deleted`), recreated (`Name cannot have a reserved value`), or extended with new options from the CLI — `gh` has no `field-edit`. Its options are editable only through the web UI.

That matters more than the column names themselves. If setting up the board required a manual step in a browser, the board would no longer be reproducible from the script, and the guarantee this change exists to provide — that the board is derived and therefore cannot drift — would depend on someone having clicked the right things once. A redundant unused `Status` field in the field list is a smaller cost than that.

It also buys back the `Ready to archive` column, which the built-in vocabulary has no room for. That state is real and useful here: a change whose tasks are all complete but which has not been archived yet is exactly the state `add-doe-price-storage` sat in earlier.

*Alternative rejected:* mapping onto `Todo / In Progress / Done`. No extra fields and the default view works untouched, at the cost of collapsing "finished" and "archived" into one column.

### Local script now, CI later — and not because CI is hard

The sync is a script run deliberately. No workflow is added.

*Why:* the same local-first reasoning as `bootstrap-repo-and-supabase`, plus a specific credential concern. GitHub Actions' built-in `GITHUB_TOKEN` **cannot** write to Projects v2; automating this requires a personal access token with Projects read/write stored as a repository secret. This repository is public and exists as a portfolio piece, so adding a broadly-scoped token to it is a decision worth making on its own terms rather than as a side effect of wanting a board. Proving the sync logic locally first also means that when it does move to CI, the only new variable is the credential.

## Risks / Trade-offs

- **The board is a projection; edits made on it are silently discarded** → Documented in the operator note. The board is for viewing, and moving a card by hand does not move the work.
- **Title-based matching breaks if a change is renamed** → Produces an orphaned card and a new issue rather than a crash. Visible, and rare: OpenSpec names are set at `openspec new change` and not normally changed.
- **Four issues appear in a repository that had none** → Intended. On a portfolio repository, issues that mirror real planned work are a feature rather than clutter.
- **The sync can create duplicates if run while a previous run is mid-flight** → Single-operator tooling; not defended against. Noted rather than engineered around.
- **`gh` API shape can change between versions** → The script pins nothing and will fail loudly on an unexpected response rather than writing a wrong value. Acceptable for a script run by hand and read by its operator.

## Migration Plan

Additive and external: a script plus a GitHub Project. Nothing in the repository depends on the board existing, and no existing file changes behaviour.

Order: create the project and its `Status` field → link it to the repository → write the script → run it → verify the four cards land in the right columns.

Rollback is deleting the project and closing or deleting the issues it created. The script can be removed independently; leaving it in place with no project simply means the next run recreates one.

## Open Questions

- **Whether to promote the sync to a GitHub Actions workflow**, and if so, whether a fine-grained PAT scoped to Projects only is acceptable in a public repository's secrets. Deferred until the script has proven itself.
- **Whether future changes should carry labels** (for example by capability) so the board can be filtered. Trivial to add later, and premature with four cards.
