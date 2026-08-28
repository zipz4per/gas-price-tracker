## 1. Proposal extraction

- [ ] 1.1 Implement a heading-scoped extractor over `proposal.md` returning the lead paragraph, the `## What Changes` bullets, and the `### Explicitly out of scope` bullets; verify it returns the expected text for all six current proposals
- [ ] 1.2 Treat a missing or non-prose lead paragraph as an error, and verify a proposal whose `## Why` opens with a bullet, a sub-heading, a blockquote, or a table row is rejected rather than coerced into a one-line description
- [ ] 1.3 Treat a missing `## What Changes` section, or one with no top-level bullets, as an error; verify the error names the change and the missing section
- [ ] 1.4 Treat a missing `### Explicitly out of scope` as an omission rather than an error, and verify `bootstrap-repo-and-supabase` extracts cleanly without one
- [ ] 1.5 Stop extraction at the next heading of equal or higher level; verify `## What Changes` bullets exclude the out-of-scope bullets nested beneath it
- [ ] 1.6 Reject any extracted line matching `- [ ]` or `- [x]`; verify a proposal containing one aborts the run rather than publishing a line GitHub would count in the issue's progress bar

## 2. Issue body composition

- [ ] 2.1 Rewrite `build_issue_body()` to emit description, status line, what-changes bullets, out-of-scope bullets when present, artifact links, then `tasks.md` verbatim; verify the rendered body for one change matches the order in `design.md`
- [ ] 2.2 Verify extracted text is passed through unmodified — bold, inline code, and em-dashes intact — by diffing the emitted lines against the proposal source
- [ ] 2.3 Verify `tasks.md` is still appended verbatim and that `count_tasks()` reports the same totals as before the change for every change

## 3. Preflight and failure behaviour

- [ ] 3.1 Run extraction for every discovered change before any GitHub write, and verify a single unparseable proposal aborts the run with nothing written
- [ ] 3.2 Verify the abort message names the change, the missing or malformed section, and the file path
- [ ] 3.3 Verify `--dry-run` reports the same extraction errors and still writes nothing

## 4. End-to-end verification

- [ ] 4.1 Run `--dry-run` against the current repository and verify all six changes extract successfully with no errors reported
- [ ] 4.2 Run the sync and verify every issue body updates, then run it a second time and verify it reports `0 change(s) applied`
- [ ] 4.3 Verify on GitHub that one updated issue renders the description above the checklist, that the task-list progress bar still counts only real tasks, and that the board's status, labels, and assignees are unchanged
- [ ] 4.4 Verify the sync writes nothing into `openspec/` by comparing a checksum of the directory before and after a run

## 5. Documentation

- [ ] 5.1 Update the "cards" section of `docs/project-board.md` to state what the body contains and which proposal section each part comes from
- [ ] 5.2 Document the obligation that a proposal's first `## Why` paragraph must stand alone as a published summary, and that the sync fails loudly when it does not; verify the troubleshooting table covers the new abort
