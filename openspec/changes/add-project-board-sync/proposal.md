## Why

The project's state lives in `openspec/` — which changes exist, how many of their tasks are done, and which have been archived. That is readable by running CLI commands or listing directories, but it is invisible to anyone looking at the repository, and it offers no at-a-glance view of what is in flight versus finished.

A Kanban board answers that in one screen. The useful observation is that **no new bookkeeping is required to build one**: OpenSpec's own directory layout and task checkboxes already encode exactly the state a board needs. A change's location says which column it belongs in, and its task counts give its progress.

```
  openspec/changes/<name>/          0 tasks done   →  Proposed
  openspec/changes/<name>/          some done      →  In Progress
  openspec/changes/<name>/          all done       →  Ready to archive
  openspec/changes/archive/<name>/                 →  Done
```

Because this is derived rather than maintained, the board cannot drift from reality the way a hand-updated board does. Nothing needs to be kept in sync by hand; the sync recomputes from the source of truth.

## What Changes

- **Create a GitHub Project (v2)** for the repository, with a `Status` field whose options match the four states above.
- **Introduce a sync script** that reads `openspec/changes/` and `openspec/changes/archive/`, derives each change's status and task progress, and reflects it onto the board.
- **Represent each change as a GitHub issue**, one per change, whose body is that change's `tasks.md`. OpenSpec already writes tasks as GitHub-flavored checkboxes, so GitHub renders them as a native task list with a progress bar without any transformation.
- **Make the sync idempotent**: re-running it updates existing issues and cards rather than creating duplicates, so it is safe to run at any time and after any change to `openspec/`.
- **Close the issue when its change is archived**, so the card lands in `Done` and the repository's issue list reflects completed work.
- **Link the project to the repository** so it is reachable from the repo's Projects tab.
- **Assign every issue to the repository owner**, so the board's Assignees column is populated and filtering by assignee returns the whole project rather than nothing.
- **Derive labels from each change's capabilities** — `capability: <name>` for every spec the change touches, and `tooling` for changes that declare `skip_specs`. Missing labels are created on demand, so the scheme needs no setup.

### Explicitly out of scope

- Any GitHub Actions workflow or CI automation. The script is run deliberately; promoting it to run on push is a separate change, once the sync logic is proven and the credential question it raises has been decided.
- Any change to application behaviour, schema, or the OpenSpec workflow itself. Nothing under `supabase/` is touched.
- Per-task cards. Tasks appear as checkboxes inside a change's issue, not as separate board items — 60-plus cards would make the board unreadable, and a change is the unit actually moved between columns.
- Bidirectional sync. The board is a projection of `openspec/`; edits made on the board are not written back and will be overwritten by the next sync.

## Capabilities

### New Capabilities

None. This change adds project tooling and introduces no externally observable product behaviour — nothing about the app, its data, or its API changes. `.openspec.yaml` sets `skip_specs: true` accordingly.

### Modified Capabilities

None.

## Impact

- **New:** a sync script under `scripts/`, and a short operator note covering prerequisites and how to run it.
- **New (external):** a GitHub Project owned by `zipz4per`, linked to `gas-price-tracker`, plus one issue per OpenSpec change.
- **Requires:** the `gh` CLI authenticated with `project` scope. Already satisfied.
- **Depends on:** `bootstrap-repo-and-supabase` only for the repository and its remote.
- **No impact on:** `supabase/`, the migrations, the loader, either capability spec, or how changes are proposed, applied, and archived. The sync reads `openspec/` and never writes to it.
- **Reversible:** deleting the project and its issues removes everything this change produces; nothing in the repository depends on the board existing.
