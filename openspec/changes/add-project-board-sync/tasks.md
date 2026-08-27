## 1. Project setup

- [x] 1.1 Verify `gh` is authenticated with `project` scope and record the exact command to restore it (`gh auth refresh -s project`); verify `gh project list --owner zipz4per` succeeds rather than erroring on scope
- [x] 1.2 Create the GitHub Project owned by `zipz4per` and capture its number; verify it appears in `gh project list`
- [x] 1.3 Create a custom single-select field `OpenSpec Status` with options `Proposed`, `In Progress`, `Ready to archive`, and `Done`; verify all four appear in `gh project field-list --format json`. The built-in `Status` field is reserved — it cannot be deleted, renamed, or extended from the CLI — so a custom field is what keeps the board reproducible from the script alone
- [x] 1.4 Link the project to `zipz4per/gas-price-tracker` and verify it is reachable from the repository's Projects tab

## 2. Reading OpenSpec state

- [x] 2.1 Implement discovery of all changes across `openspec/changes/` and `openspec/changes/archive/`, stripping the `YYYY-MM-DD-` prefix from archived names; verify all four current changes are found with their archived state correct
- [x] 2.2 Derive task progress by counting `- [x]` versus `- [ ]` in each change's `tasks.md`; verify counts match `openspec instructions apply --json` for the one active change
- [x] 2.3 Derive status from location and progress (`Proposed` / `In Progress` / `Ready to archive` / `Done`); verify the three archived changes derive `Done` and `add-doe-price-retrieval` derives `Proposed`
- [x] 2.4 Handle a change with no `tasks.md` without crashing, reporting it as zero-progress; verify against a temporary scratch change directory

## 3. Issue synchronisation

- [x] 3.1 Build the issue body from the change's `tasks.md` plus links to its proposal and design, preserving checkbox markdown verbatim so GitHub renders a task list; verify a created issue shows a progress bar matching the change's real counts
- [x] 3.2 Find an existing issue by title match and create one only when absent; verify a second run creates no duplicate issues
- [x] 3.3 Update an existing issue's body when task state has changed; verify ticking a task and re-running moves the issue's progress bar
- [x] 3.4 Close the issue for any archived change and reopen nothing; verify the three archived changes have closed issues and the active one remains open
- [x] 3.5 Assign every synced issue to the repository owner, skipping any already assigned; verify all five issues show `zipz4per` in the board's Assignees column and that a second run reports no assignment changes

## 4. Board synchronisation

- [x] 4.1 Add each change's issue to the project, skipping any already present; verify a second run adds no duplicate cards
- [x] 4.2 Set each card's `OpenSpec Status` field from the derived status using `gh project item-edit --field "OpenSpec Status" --value`; verify all four cards land in their expected columns
- [x] 4.3 Verify idempotence end to end: run the sync twice in succession and confirm the second run reports no changes and alters no issue or card

## 5. Operator documentation

- [x] 5.1 Write the operator note covering prerequisites, how to run the sync, and what each column means; verify a second person can run it unaided from the note alone
- [x] 5.2 Record that the board is a one-directional projection of `openspec/` and that edits made on the board are overwritten by the next sync; verify the note states this explicitly

## 6. Verification

- [x] 6.1 Run the sync against the real repository and verify the board shows three `Done` cards and one `Proposed` card matching the current OpenSpec state
- [x] 6.2 Verify progress bars are correct per card, including that archived changes show all tasks complete
- [x] 6.3 Verify the sync writes nothing to `openspec/` by confirming `git status` is clean for that directory after a run
