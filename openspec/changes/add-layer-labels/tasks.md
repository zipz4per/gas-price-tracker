## 1. Layer declaration

- [x] 1.1 Read `layer` from a change's `.openspec.yaml` beside the existing `skip_specs` reader, and verify all three values parse for a change declaring each
- [x] 1.2 Reject a change with no `layer` key, naming the change and the file; verify the message says which values are allowed
- [x] 1.3 Reject an unrecognised value such as `layer: backedn`, and verify no label is created for it
- [x] 1.4 Run the rejection inside the existing preflight so it happens before the first GitHub write; verify a single undeclared change aborts the run with nothing written, in `--dry-run` too

## 2. Two-axis labels

- [x] 2.1 Return `capability:` and `layer:` labels together rather than exclusively, and verify a change with specs and a layer carries both
- [x] 2.2 Verify a `skip_specs` change carries only its layer label and no capability label
- [x] 2.3 Replace the bare `tooling` label with `layer: tooling`, and verify no code path can still emit the bare form
- [x] 2.4 Register the layer label colours in `ensure_labels()` and verify each label is created once with its intended colour

## 3. Label reconciliation

- [x] 3.1 Compute the desired label set per issue and remove any `capability:` or `layer:` label not in it; verify an issue carrying a stale managed label converges in one run
- [x] 3.2 Verify unmanaged labels are never removed by applying `bug` to an issue by hand, running the sync, and confirming it survives
- [x] 3.3 Verify reconciliation is idempotent: a second consecutive run reports no label actions

## 4. Backfill

- [x] 4.1 Add `layer:` to all six archived changes per the table in `design.md`, and verify `openspec validate` still passes for every change and spec
- [x] 4.2 Add `layer: tooling` to this change itself, and verify the sync accepts it
- [x] 4.3 Verify every change discovered by the sync now declares a layer, with none falling back to a default

## 5. End-to-end verification

- [x] 5.1 Run `--dry-run` and verify all seven changes resolve both axes with no errors reported
- [x] 5.2 Run the sync and verify each issue ends with exactly its capability and layer labels, the bare `tooling` gone from all three issues that carried it
- [x] 5.3 Verify on GitHub that filtering the board by `layer: backend` returns the three DOE and registry changes, and by `layer: tooling` returns the three board and bootstrap changes
- [x] 5.4 Run the sync a second time and verify it reports `0 change(s) applied`
- [x] 5.5 Verify the sync writes nothing into `openspec/` by comparing a checksum of the directory before and after a run

## 6. Documentation

- [x] 6.1 Document the two axes in `docs/project-board.md` — what each answers, where each comes from, and that a change declares its layer
- [x] 6.2 Document that the sync reconciles only its own two label prefixes and leaves every other label alone, and note that the retired bare `tooling` label is left in the repository for a human to delete
