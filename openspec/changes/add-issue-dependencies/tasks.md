## 1. Prove the API before building on it

- [x] 1.1 Verify `POST /issues/{n}/dependencies/blocked_by` writes an edge and that GitHub shows the inverse on the blocker without a second write, using #10 and #12 — the design assumes one write per edge and everything else rests on it
- [x] 1.2 Verify `DELETE` removes an edge and that `GET blocked_by` then reports it gone, so reconciliation has a working remove half
- [x] 1.3 Verify the request body identifies the blocker by issue **id** rather than number, and record which, since the two are adjacent and easy to confuse
- [x] 1.4 Verify an edge pointing at a closed issue is accepted and renders as satisfied rather than as an open constraint
- [x] 1.5 Verify what the API does with a duplicate `POST` and with a `DELETE` of an edge that is not there, so reconciliation can be written without a pre-read if the endpoints are idempotent

## 2. Resolving records to issues

- [x] 2.1 Add a `git` helper beside the existing `gh` one, running with `cwd=REPO_ROOT` and returning output the same way, and verify it is the only place the sync shells out to git
- [x] 2.2 Resolve a `Fixed by` line to a change name, and verify a line naming a commit rather than a change resolves to nothing instead of guessing
- [x] 2.3 Resolve a `Caused by` sha to the change directory the commit touched, and verify the resolution is taken only on a unique match
- [x] 2.4 Verify a sha touching no change directory resolves to nothing, using `dbcb277`
- [x] 2.5 Verify a sha touching several change directories resolves to nothing rather than picking one, using `d67611d`, which scaffolded four
- [x] 2.6 Verify an unparseable or absent `Caused by` — including `spec was silent` — is a normal outcome that prints the section unchanged, not an error
- [x] 2.7 Verify a change name written explicitly in the report wins over resolution, so an author can name a link the sync cannot derive
- [x] 2.8 Map a resolved change name to its issue number across both the active tree and the archive, and verify a name that matches no record aborts the run in preflight

## 3. Declared dependencies for changes

- [x] 3.1 Read `blocked_by:` as a list from a change's `.openspec.yaml`, and verify a missing key, an empty list, and a single string are all handled without an error
- [x] 3.2 Verify a declared name resolving to no change directory aborts the run in preflight, matching how a bug's declared `capability:` already behaves
- [x] 3.3 Verify a declared name resolving to an archived change is accepted, since a dependency on finished work is the ordinary case
- [x] 3.4 Verify a change declaring itself as its own blocker is rejected
- [x] 3.5 Detect a cycle among declared edges and abort naming the records in it, and verify a two-change cycle is caught before any API call
- [x] 3.6 Verify `blocked_by:` is rejected on a **bug**, whose blocker is derived rather than declared, matching how a declared `kind:` is already rejected

## 4. Writing and reconciling edges

- [x] 4.1 Compute the full set of blockers each issue should carry, and verify it is derived for bugs and declared for changes with no path by which one becomes the other
- [x] 4.2 Write missing edges, and verify `[bug] doe-fuel-type-not-recognised` ends up blocked by `[change] fix-unrecognised-read-inputs`
- [x] 4.3 Remove edges the repository does not state, and verify an edge added by hand on GitHub does not survive the next sync
- [x] 4.4 Verify an edge to an issue the board did not create is left alone, so the managed set stays bounded the way managed labels are
- [x] 4.5 Verify a second consecutive run reports `0 update(s) applied`, which is the invariant proving the projection is complete
- [x] 4.6 Verify the run order puts edge reconciliation after issue creation, so an edge never names an issue that does not exist yet

## 5. Causation in the body

- [x] 5.1 Publish a resolved `Caused by` as `<sha>  <subject> — <change> #<n>`, and verify #10's body links to #1
- [x] 5.2 Verify the reference appears on the causing issue's timeline, which is the bidirectional half of the cross-reference
- [x] 5.3 Verify an unresolved `Caused by` prints exactly what it prints today, so no existing issue body changes without cause
- [x] 5.4 Verify rewriting a body on every run does not repeat the timeline event on the referenced issue

## 6. Reporting

- [x] 6.1 Print every edge a run would add and remove in the dry run, and verify both directions are visible before anything is written
- [x] 6.2 Verify the dry run prints a resolved cross-reference too, since a link the sync writes but never renders is what the relative-link bug was
- [x] 6.3 Verify a record with no dependencies prints nothing rather than an empty section

## 7. Documentation and close-out

- [x] 7.1 Update `openspec/bugs/report-template.md` so `Caused by` shows the resolved form beside the sha, and verify it says resolution is automatic and the explicit name is an override
- [x] 7.2 Update `openspec/bugs/README.md` with what a bug's blocker means and why causation is a reference rather than an edge
- [x] 7.3 Update `docs/project-board.md` with the derived-versus-declared split, the reconciliation rule, and that a closed blocker is satisfied rather than removed
- [x] 7.4 Verify `docs/project-board.md` still describes the board as losslessly regenerable, now that edges are part of what a run produces
- [x] 7.5 Run a live sync and verify the two real edges and one real cross-reference appear, then run it again and verify `0 update(s) applied`
