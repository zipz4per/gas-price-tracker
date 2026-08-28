## 1. The bug record

- [x] 1.1 Create `openspec/bugs/` with a `README.md` stating what belongs there, how a bug differs from a change, and when a bug becomes one; verify it names *won't fix* and *not a bug* as legitimate endings
- [x] 1.2 Write the `report.md` template with sections for what is broken, reproduction, impact, root cause, caused by, fixed by, and what the fix changed; verify every section that is unknown at filing time has an explicit pending form rather than being left blank
- [x] 1.3 Verify the template's reproduction section calls for actual and expected output side by side, not a narrative of steps
- [x] 1.4 Verify `caused by` admits "never worked" as an answer alongside a commit reference, and that the template says which one means what
- [x] 1.5 Verify a report using the template renders as valid GitHub-flavoured markdown, including any checkbox list of fix tasks
- [x] 1.6 Declare `capability:` and `layer:` in a bug's `.openspec.yaml`, and verify a capability naming no directory under `openspec/specs/` aborts the run rather than creating a label

## 2. Discovery

- [x] 2.1 Walk `openspec/bugs/` alongside `openspec/changes/` in `scripts/sync-project-board.py`, and verify a dry run lists records from both trees
- [x] 2.2 Verify a bug's task progress is counted from checkboxes in `report.md`, and that a report with no checkboxes is treated as no tasks rather than as an error
- [x] 2.3 Verify a bug with no fix tasks lands in the Proposed column
- [x] 2.4 Verify a malformed or unreadable report aborts the run in preflight with the other problems, before anything is written to the board
- [x] 2.5 Verify an archived bug is discovered and reported as Done, matching how archived changes behave

## 3. The kind axis

- [x] 3.1 Derive `kind: bug` and `kind: feature` from which tree a record sits in, and verify neither value can be set or overridden from `.openspec.yaml`
- [x] 3.2 Add `kind:` to the managed label prefixes so reconciliation removes a stale one, and verify a label outside the managed prefixes is still left untouched
- [x] 3.3 Verify the two `kind:` values are a closed set that cannot create an unrecognised label, matching how the layer values are guarded
- [x] 3.4 Verify every existing change issue gains `kind: feature` on the first sync without losing its capability or layer labels

## 4. Issues

- [x] 4.1 Title bug issues `[bug] <name>`, and verify the title-matching that finds an existing issue does not confuse a bug with a change of the same name
- [x] 4.2 Compose a bug's issue body from `report.md`, and verify it leads with what is broken, carries the reproduction visibly rather than folded, and links back to the file
- [x] 4.3 Verify a bug's body shows caused-by and fixed-by together, including when one or both are pending
- [x] 4.4 Verify a bug that links to a change renders that link, and that the bug is not closed when the change is filed
- [x] 4.5 Verify a re-run makes no changes to an already-synced bug issue, so the sync stays idempotent

## 5. Documentation

- [x] 5.1 Update `docs/project-board.md` to describe two kinds of record rather than one, and verify the source table names `openspec/bugs/` alongside `openspec/changes/`
- [x] 5.2 Document the three label axes together, and verify the text says which are derived and which are declared, and why `kind:` is derived
- [x] 5.3 Document the bug lifecycle against the existing status column, including that *won't fix* and *not a bug* are closures rather than columns
- [x] 5.4 Verify the counts and examples in `docs/project-board.md` still match the repository after this change

## 6. End-to-end verification

- [x] 6.1 File the fuel-type bug as `openspec/bugs/doe-fuel-type-not-recognised/report.md`, recording the five-input reproduction, the normalize-versus-exact-match root cause with line references, and `1a3f1e9` as a never-worked cause
- [x] 6.2 Sync the board and verify the bug appears as `[bug] doe-fuel-type-not-recognised` with `kind: bug`, `capability: doe-reference-prices`, and `layer: backend`, in the Proposed column
- [x] 6.3 Verify the change issues on the board are unchanged apart from gaining `kind: feature`
- [x] 6.4 Record whether the `Impact` section earned its place once filled with real content, and either keep it or fold it into what is broken
- [x] 6.5 Run the sync twice and verify the second run reports no changes
