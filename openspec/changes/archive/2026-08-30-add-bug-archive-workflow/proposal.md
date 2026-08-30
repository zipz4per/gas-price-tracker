# Give bug reports an archive workflow of their own

> **This record was written after the fact.** The work shipped in `63f9b00`
> on 2026-08-30 with no proposal behind it, and `add-commit-issue-links`
> found the gap by asking which record every commit belongs to. Nothing here
> was decided by writing it down; the decisions are reconstructed from the
> commit message and the shipped files, and the tasks are marked complete
> because they were already done. A retro record that reads as though it
> preceded the work would be worse than no record at all.

## Why

A bug could be filed and fixed but never closed out. `/opsx:archive` resolves
its target with `openspec status --change`, and the OpenSpec CLI enumerates
`openspec/changes/` only, so a bug came back *Change '<name>' not found* and the
workflow never got a directory to move. Both finished bugs sat at *Ready to
archive* with their issues still open.

The gap was this project's, not the CLI's. `add-bug-reports` priced the parallel
tree at "a second discovery walk in one script" and paid it — the sync has read
`openspec/bugs/archive/` since its task 2.5. What it did not account for is that
archiving runs through a CLI this project does not own.

## What Changes

- **A hand-written sibling skill**, `openspec-archive-bug`, that reads
  `report.md` directly and never calls the OpenSpec CLI.
- **A command wrapper**, `/opsx:archive-bug`, delegating to it.
- **Four gates** replacing the change workflow's spec-sync assessment, which has
  nothing to assess on a bug: `Fixed by` names a commit, a change, or *won't
  fix*; the "does this need a change?" question is answered; any change it names
  is already archived; fix tasks have no open boxes.
- **A one-paragraph routing bridge** in `/opsx:archive` and
  `openspec-archive-change`, handing a bug name off rather than failing on it.
- **`allowed-tools` widened** on both generated files from `Bash(openspec:*)`,
  which never covered the `mkdir` and `mv` their own step 5 already ran.
- **Documentation** of the workflow in `openspec/bugs/README.md` and of the
  two commands' non-interchangeability in `docs/project-board.md`.

## Explicitly out of scope

- **Extending the change workflow to handle bugs.** Its steps 2 through 4 —
  artifact graph, `tasks.md`, delta-spec sync — all consume the JSON from the
  one call that fails on a bug, and a bug has none of the three. Only the final
  `mv` is shared.
- **A custom OpenSpec schema for bugs.** A schema cannot relocate `changesDir`;
  it derives from `planningHome`, so a `bug-report` schema would force bugs
  under `openspec/changes/` and destroy the location-derived `kind:` label.
- **Hard-blocking gates.** They warn and confirm, matching the change workflow.

## Capabilities

None. `skip_specs: true` — see `.openspec.yaml`.

## Impact

- New: `.claude/skills/openspec-archive-bug/SKILL.md`,
  `.claude/commands/opsx/archive-bug.md`
- Modified: `.claude/commands/opsx/archive.md`,
  `.claude/skills/openspec-archive-change/SKILL.md`,
  `openspec/bugs/README.md`, `docs/project-board.md`
- Shipped in `63f9b00`.
