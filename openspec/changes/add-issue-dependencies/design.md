## Context

GitHub's issue sidebar offers four relationships — *parent*, *blocked by*, *blocking*, *relates to*. The REST API offers two:

```
  GET/POST/DELETE  /issues/{n}/dependencies/blocked_by    200
  GET              /issues/{n}/dependencies/blocking      200
                   /issues/{n}/dependencies/relates_to    404
                   /issues/{n}/dependencies/parent        404
```

`blocking` is the read side of the same edge — writing `blocked_by` on the blocked issue is what makes it appear — so there is exactly one write. The existing `repo` token scope covers it.

Verified against the live API before building on it:

```
  blocker is identified by issue id, not number   an id-shaped number 404s, so a
                                                  confusion fails loudly
  one POST writes both sides                      #12 showed blocking #10 with no
                                                  second call
  DELETE clears both sides                        both endpoints drop to zero
  a closed blocker is accepted                    #12 is closed/completed and the
                                                  edge held
  POST is NOT idempotent                          a duplicate returns 422
                                                  "Target issue has already been taken"
  DELETE IS idempotent                            removing an absent edge returns 200
```

The last two are asymmetric, and that asymmetry decides the shape of reconciliation: the current edge set must be read before writing, because a no-op `POST` is an error rather than a no-op. A no-op `DELETE` is safe, so the read is needed for the add half only.

`scripts/sync-project-board.py` already shells out through one helper (`subprocess.run(["gh", *args], cwd=REPO_ROOT)`) and already reconciles a managed set: `MANAGED_LABEL_PREFIXES` bounds which labels the sync owns, so it can remove a `capability:` label that no longer applies without touching a hand-added label it never wrote. Dependency edges need the same treatment for the same reason, and the pattern is in place.

The data is present today. Both bug reports carry a `Caused by` sha and a `Fixed by` line; the twelve issues are numbered #1–#12 and their ids are readable in one call.

## Goals / Non-Goals

**Goals:**

- A bug whose fix lives in a change shows that change as its blocker, without anyone typing it into GitHub.
- A change can state what it waits on, in the repository, in a form the sync validates.
- Causation stays legible and clickable without being misrepresented as an obligation.
- A hand-added edge on GitHub does not survive the next sync, so the board keeps its one-directional property.
- A dry run shows every edge it would write, and every one it would remove.

**Non-Goals:**

- Enforcing dependencies. The board reports; `/opsx:archive-bug` enforces.
- Representing causation as an edge. See *Causation is not a dependency*.
- Inferring a change's dependencies from its content.
- Any use of `parent`, sub-issues, or `relates to`, which the API does not expose.

## Decisions

**Derived for bugs, declared for changes.** These look inconsistent and are not. A bug's report already contains the answer — `## Fixed by` names the change, and the archive workflow already parses that same line to decide whether the bug may close. Deriving it adds no new authoring burden and cannot drift from the gate that enforces it. A change has no equivalent sentence: its proposal names capabilities, not other changes. So a change declares `blocked_by:` in `.openspec.yaml`, beside the `layer:` it already declares, and a bug declares nothing.

The rule the project already follows is *derive what the repository states, declare what it does not*. `kind:` is derived from location because location is unambiguous; a bug's `capability:` is declared because a bug has no `specs/` directory to read it from. This is the same rule applied once more.

**Causation is not a dependency.** `add-doe-price-retrieval` caused `doe-fuel-type-not-recognised`, and it is archived and Done. Marking it *blocking* would be available and wrong: a blocking edge is an obligation, and an archived change has none. The board would show a live-looking constraint that nobody can discharge, and the Done column would stop meaning finished.

So causation is published as a **cross-reference in the body** — `1a3f1e9  Add DOE reference price retrieval function (never worked) — add-doe-price-retrieval #1`. GitHub renders `#1` as a link and records a *referenced* event on #1's timeline, which is bidirectional visibility with no false obligation. It is a weaker representation than an edge, and it is the accurate one.

**Resolving a sha to a change is best-effort, never a guess.** The obvious resolution — the change directory the commit touched, since implementation commits tick their own `tasks.md` — does not generalise. Across this repository's history:

```
  resolves to   commits   what they are
  ────────────────────────────────────────────────────────────────────────
  0 changes        20     docs, fixes, bootstrap, board-sync work
  1 change          9     ordinary implementation commits
  3 changes         1     d67611d, which scaffolded three at once
```

Both shas that matter today resolve uniquely, and most commits do not resolve at all. So the rule is: **resolve only on a unique match; otherwise print the sha alone.** A `Caused by` that lands on `d67611d` gets no cross-reference rather than an arbitrary one of three, and a bug caused by a commit outside any change — which is most of them — reads exactly as it does now. An author who wants the link anyway can name the change in the report, and an explicit name wins over resolution.

This keeps a wrong edge impossible. The cost is that some causation stays unlinked, which is the right direction to fail: the sha and subject are still printed, and they are what `git log -S` needs.

**Reconcile, do not append.** Each run computes the set of blockers an issue should have and issues the difference — `POST` for missing, `DELETE` for extra. Without the delete half, an edge added by hand on GitHub would persist forever and become a second source of truth the repository cannot see, which is the exact property the board exists to avoid. Reconciliation is also what makes a re-run report `0 update(s) applied`, the invariant that proves the projection is complete.

The managed set is bounded the way labels are: the sync owns edges between issues it created, and both endpoints of every edge it writes are board issues. There is no case today of an edge to an issue outside the board, and treating any such edge as unmanaged is the conservative reading if one appears.

**A closed blocker is a satisfied blocker, not an absent one.** `#10` will be blocked by `#12`, which is archived and closed. The edge stays written: it is the record of why the bug waited, and removing it once satisfied would erase the reason. GitHub renders a closed blocker as satisfied rather than as an open constraint, which is the correct display.

**Validation matches the existing precedent.** A declared `blocked_by:` name must resolve to a change directory in either the active tree or the archive, and one that does not aborts the sync — the same treatment a bug's declared `capability:` already gets when it names no directory under `openspec/specs/`. A typo that silently produced no edge would be worse than a stopped sync, because the board would look complete and be wrong.

## Risks / Trade-offs

**The dependencies API is young.** These endpoints are newer than the rest of the surface the sync uses, and their shape could move. The mitigation is containment: one helper that writes edges, one that reads them, and a dry run that prints both. If the API changes, the blast radius is two functions.

**A cycle is expressible.** Nothing stops `a` declaring `blocked_by: [b]` while `b` declares `blocked_by: [a]`. GitHub may or may not reject it. The sync should detect a cycle among declared edges and abort rather than discovering it as an API error, since the repository is where the mistake is.

**`Caused by` parsing is looser than the rest.** It is prose with a conventional shape rather than a field, and the template's three forms — a sha, a sha with `(never worked)`, and `spec was silent` — are convention, not schema. Parsing looks for a leading sha and gives up otherwise, which is why unresolved is a normal outcome rather than an error.

**Half the change ships unexercised by live data.** No change declares `blocked_by:` today, so that path is verified by tests and by a temporary declaration rather than by a real edge. The bug half is fully exercised: #10 → #12 and #11's cross-reference to #2 are real records with real numbers.
