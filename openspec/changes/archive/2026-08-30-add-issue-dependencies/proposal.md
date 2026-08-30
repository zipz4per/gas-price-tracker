## Why

The board publishes every fact a record knows about its own dependencies as prose, and none of it as structure. `[bug] doe-fuel-type-not-recognised` says *Fixed by `fix-unrecognised-read-inputs`* in its body and *Caused by `1a3f1e9  Add DOE reference price retrieval function`* beside it. Both name real records with real issues — #12 and #1 — and neither is a link. A reader on the board sees a bug that mentions a change; they cannot see that the change is on the same board, already archived, two cards away.

The `Fixed by` relationship in particular is already enforced. `/opsx:archive-bug` refuses to archive a bug whose report names a change until that change is in `openspec/changes/archive/`, because what someone searches for later is the symptom rather than the change that repaired it. That is a dependency in the ordinary sense — the bug cannot close until the change does — and the tooling checks it on every archive while the board shows no sign of it. GitHub has a first-class representation for exactly this, and the repository already holds everything needed to derive it.

The gap is wider than bugs. Nothing in `openspec/` lets one change say it depends on another, so an ordering that is real — a frontend change that cannot start until `add-station-registry` lands — lives only in conversation. The board can only project what the repository states, and the repository has no way to state it.

## What Changes

- **Derive `blocked_by` for a bug from its report.** When `## Fixed by` names a change rather than a commit, the bug's issue is marked blocked by that change's issue. GitHub derives the inverse itself, so the change shows *blocking* without a second write.
- **Let a change declare `blocked_by:` in `.openspec.yaml`**, as a list of change names. Declared rather than derived, because no artifact in a change states what it waits on. Each name must resolve to a change in the tree — active or archived — and one that does not aborts the sync, matching how a bug's declared `capability:` is already validated.
- **Resolve `## Caused by` to the change that carries the commit** and publish it as a body cross-reference — `1a3f1e9  Add DOE reference price retrieval function (never worked) — add-doe-price-retrieval #1` — so GitHub links it and records the reference on the causing issue's timeline.
- **Reconcile edges rather than only adding them.** Every run computes the full set an issue should carry and removes the ones it should not, exactly as managed labels already work. An edge added by hand on GitHub is overwritten, because the board is a projection.
- **Report edges in the dry run**, so the links a sync would write are inspectable before it writes them — the check that `add-bug-reports` learned to want after the relative-link bug shipped invisibly.

### Explicitly out of scope

- **`relates to`, `parent`, and sub-issues.** The REST API exposes `dependencies/blocked_by` and `dependencies/blocking` only; `dependencies/relates_to` returns 404. This is why `Caused by` becomes a cross-reference rather than an edge.
- **Marking a causing change as `blocking` its bug.** It is available, and it is wrong: `add-doe-price-retrieval` is archived and cannot unblock anything, so the edge would display a live obligation that no one can act on. Causation is history; a dependency is an obligation.
- **Deriving `blocked_by` for a change from its content.** A change's proposal names capabilities, not other changes. Inferring an ordering from overlapping capability names would guess, and a wrong edge is worse than an absent one.
- **Blocking the sync on an unsatisfied dependency.** The board reports; it does not enforce. `/opsx:archive-bug` is where the `Fixed by` wait is enforced, and it stays there.
- **Bidirectional sync.** Unchanged: nothing originates on the board.

## Capabilities

### New Capabilities

None. A dependency edge between two issues is a fact about the repository's own records, not behaviour the project promises to anyone.

### Modified Capabilities

None.

## Impact

- **Modified:** `scripts/sync-project-board.py` — a `Record` gains resolved dependency and causation fields, discovery resolves them across both trees, `check_declarations()` validates a declared `blocked_by:`, the bug body builder writes a cross-reference in place of a bare sha, and a reconcile step joins the label and status steps.
- **Modified:** `openspec/bugs/report-template.md` — `Caused by` gains the resolved-change form beside the sha.
- **Modified:** `docs/project-board.md` and `openspec/bugs/README.md` — what the edges mean, which are derived and which declared, and why causation is not one.
- **New GitHub API surface:** `GET`, `POST`, and `DELETE` on `/repos/{owner}/{repo}/issues/{n}/dependencies/blocked_by`. Covered by the existing `repo` token scope.
- **Data already present:** both bug reports resolve today — #10 blocked by #12, #11 caused by #2 — so the change is verifiable end to end against real records on its first run. No change declares `blocked_by:` yet, so that half ships exercised by tests rather than by live data.
