# Tasks

> All complete on arrival — this record documents `63f9b00`. See `proposal.md`.

## 1. Establish that the change workflow cannot do it

- [x] 1.1 Confirm `openspec status --change <bug>` returns *not found*.
- [x] 1.2 Confirm every step of `/opsx:archive` after step 1 consumes that JSON.
- [x] 1.3 Confirm a custom schema cannot relocate `changesDir` away from
      `planningHome`, ruling out modelling a bug as an OpenSpec change.
- [x] 1.4 Confirm `operationGuidance` is keyed by `--change <name>` and cannot
      introduce a new record kind.

## 2. The skill

- [x] 2.1 Write `.claude/skills/openspec-archive-bug/SKILL.md`, hand-written,
      with `handWritten: true` in its metadata.
- [x] 2.2 Scope `allowed-tools` to the file operations it actually performs, and
      exclude `Bash(openspec:*)` so it cannot call the CLI by accident.
- [x] 2.3 Gate on `## Fixed by` naming a commit, a change, or `won't fix —`.
- [x] 2.4 Gate on `## Does this need a change?` being answered.
- [x] 2.5 Gate on any change it names already being in
      `openspec/changes/archive/`.
- [x] 2.6 Gate on `## Fix tasks` having no open boxes, counting `_None._` as
      done.
- [x] 2.7 Report remaining pending markers as information, not as a gate.
- [x] 2.8 Make every gate warn and confirm rather than block.
- [x] 2.9 Hard-fail on a name collision in the archive.
- [x] 2.10 Write the guardrail forbidding edits to `report.md` to pass a gate.

## 3. The command and the bridge

- [x] 3.1 Write `.claude/commands/opsx/archive-bug.md` as a thin wrapper.
- [x] 3.2 Insert the routing paragraph into `.claude/commands/opsx/archive.md`
      and `.claude/skills/openspec-archive-change/SKILL.md`, identical in both.
- [x] 3.3 Have the paragraph state that `openspec update` will remove it and
      what is lost when it does.
- [x] 3.4 Widen `allowed-tools` on both generated files to cover the `mkdir` and
      `mv` their own step 5 runs.

## 4. Documentation

- [x] 4.1 Document the workflow and its gates in `openspec/bugs/README.md`.
- [x] 4.2 Note in `docs/project-board.md` that the two archive commands are not
      interchangeable.

## 5. Verification

- [x] 5.1 Archive `board-issue-links-are-relative` through the command — the
      case where a commit is the fix and no change is waited on.
- [x] 5.2 Archive `doe-fuel-type-not-recognised` through the command — the case
      where the blocking-change gate fires on a real record and passes.
- [x] 5.3 Confirm a sync reports both as Done with report links pointing into
      `openspec/bugs/archive/`.
