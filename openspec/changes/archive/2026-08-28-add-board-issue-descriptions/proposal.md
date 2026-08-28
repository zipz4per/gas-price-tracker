## Why

Every card on the project board opens onto a bare checklist. The issue body states a status, links three files, and then lists tasks — so a reader learns what is being done and never what it is for. The rationale exists, in `proposal.md`, one click away, which in practice means unread.

The obvious fix is to write a short description into each change's `tasks.md`. That would work once and then rot. The description already exists as the opening of `## Why`, and a hand-copied second version drifts the moment scope changes in one file and not the other — leaving the board confidently displaying a summary that is no longer true. `docs/project-board.md` already states why that is worse than no summary at all: people believe a board.

So the description should be derived from the proposal, exactly as status and progress are derived from the directory and the checkboxes. The sync currently links `proposal.md` without ever reading it; this change reads it.

Two sections carry the material. The first paragraph under `## Why` is a self-contained statement of the problem in every existing proposal — between 30 and 65 words. The bullets under `## What Changes` are already the scannable inventory a reader wants, and `### Explicitly out of scope` is the section that pre-empts "why doesn't this also do X". Together they are the description, already written five times over, currently visible only to someone who goes looking.

This repository is public and serves as a portfolio. The reasoning is the artifact worth showing, and right now it is the part the board hides.

## What Changes

- **Derive each issue's description from its `proposal.md`** rather than from any new hand-written text, so the description cannot disagree with the proposal it summarises.
- **Open the issue body with the first paragraph under `## Why`**, verbatim, as the lead description.
- **Include the bullets under `## What Changes`** in full and visible — not folded behind `<details>` — because the primary reader is someone assessing the project, not someone tracking progress.
- **Include `### Explicitly out of scope` when the proposal has one**, and omit the heading entirely when it does not.
- **Place the description above the artifact links**, so the body reads as a document rather than as a link list with prose appended.
- **Fail the sync loudly when a proposal does not yield a description**, rather than publishing a degraded or empty body. A parse that silently produces a plausible wrong summary is the failure mode this project has already been bitten by twice.
- **Leave `tasks.md` untouched.** No change to task text, task counting, or the checkbox format the progress bar depends on.

### Explicitly out of scope

- Issue titles, and the issue-identity question underneath them. The sync matches issues by title, so any richer title needs identity moved off the title first — a separate change.
- Folding any part of the body behind `<details>`.
- Automating the sync on a schedule or in CI. Unchanged: it runs when it is run.
- Any change to how status, progress, labels, or assignees are derived.

## Capabilities

### New Capabilities

None. This changes what a generated issue body contains, not what the system does for its users.

### Modified Capabilities

None. `add-project-board-sync` archived with `skip_specs: true` and left no capability spec; the board remains tooling that projects `openspec/` onto GitHub, and this change adjusts the projection's output format. `.openspec.yaml` sets `skip_specs: true` accordingly.

## Impact

- **Modified:** `scripts/sync-project-board.py` — `build_issue_body()` gains a proposal parser and a reordered body; the run aborts when a description cannot be extracted.
- **Modified:** `docs/project-board.md` — the "cards" section documents what the body now contains and where each part comes from.
- **New obligation on future proposals:** the first paragraph under `## Why` must stand alone as a summary, since it is now published. All five existing proposals already satisfy this; the constraint is only visible when one does not, which is why the sync fails loudly rather than quietly.
- **Every existing issue is rewritten** on the next sync. The sync already overwrites bodies that differ, so this is the normal path, not a migration.
- **Depends on:** `add-project-board-sync` for the sync script and the board itself.
