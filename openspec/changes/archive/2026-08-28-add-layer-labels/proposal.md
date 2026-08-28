## Why

The board's labels answer one question where there are two. A change is labelled by the capabilities it touches, or — if it declares `skip_specs` — as `tooling`, never both. That reads as one taxonomy but is really two collapsed together: `doe-reference-prices` says *what* a change is about, while `tooling` says *where the work lives*, and a change cannot currently say both.

The gap becomes concrete now that the client work is starting. Six changes have shipped and every one of them is server-side or repository tooling; nothing on the board distinguishes them from the client changes about to follow, and the capability labels never will, because a capability spans layers. `price-reports` will carry both the server-side rate limiting that PRD FR-12 insists on precisely because a client can be bypassed, and the submission flow FR-5 describes. Attaching a layer to that capability would mislabel it whichever value were chosen.

A change, unlike a capability, sits in exactly one place. So the layer is declared by the change, in its `.openspec.yaml`, beside the `skip_specs` marker the board already trusts — one line, written where the change is defined, rather than inferred from a mapping table that goes stale the first time someone adds a capability and forgets to update it.

Separately, the label projection is one-directional in a way the rest of the board is not. The sync adds labels an issue is missing and never removes one it should no longer carry, so any change to what labels mean leaves the old ones sitting on old issues while the sync reports everything up to date. Renaming `tooling` to `layer: tooling` would demonstrate the bug immediately. Reconciling labels rather than only adding them is what makes this change land at all.

## What Changes

- **Every change declares its layer** in `.openspec.yaml` as `layer: backend`, `layer: frontend`, or `layer: tooling`, alongside the existing `schema` and `skip_specs` keys.
- **Labels become two independent axes** — `capability: <name>` for what a change is about, `layer: <name>` for where the work lives — so a change can carry both, and the board can be filtered by either.
- **`tooling` becomes `layer: tooling`**, a value of the layer axis rather than a pseudo-capability, removing the false exclusivity between the two axes.
- **Backfill the six archived changes** with the layer each one always had, so the filter is useful against the work that exists rather than only against work not yet done.
- **Reject an undeclared or unrecognised layer**, naming the change, in the same preflight that already rejects a proposal with no description. A typo would otherwise create a plausible new label and quietly mislabel the change.
- **Reconcile labels instead of only adding them**: the sync removes a `capability:` or `layer:` label an issue should no longer carry, and leaves every other label alone.
- **Leave labels the sync does not own untouched** — `bug`, `enhancement`, and anything added by hand stay, because a board that fights its operator over a hand-applied label is worse than one that ignores it.

### Explicitly out of scope

- Any new capability, spec, or product behaviour. This changes how work is labelled, not what the system does.
- Deleting retired labels from the repository. Removing a label deletes it everywhere it has ever been applied, which is destructive and worth doing deliberately rather than as a side effect of a sync.
- Splitting a change that genuinely spans two layers. Two labels describe it honestly; forcing a split is a judgement for whoever writes that change.
- Issue titles, board views, columns, and the status derivation, all unchanged.

## Capabilities

### New Capabilities

None. Labelling is how the board describes work, not behaviour the system offers its users.

### Modified Capabilities

None. `.openspec.yaml` sets `skip_specs: true`, as the two prior board changes did.

## Impact

- **Modified:** `scripts/sync-project-board.py` — a `layer` reader beside `reads_skip_specs()`, a two-axis `Change.labels`, layer validation in the existing preflight, and label reconciliation in the sync loop.
- **Modified:** seven `.openspec.yaml` files — the six archived changes and this one — each gaining a single `layer:` line.
- **Modified:** `docs/project-board.md` — what each axis means and what the sync will and will not touch.
- **Operational:** the bare `tooling` label is removed from three issues and left in the repository unused. Deleting it is a separate, deliberate act.
- **Depends on:** `add-project-board-sync` for the board, and `add-board-issue-descriptions` for the preflight this extends.
- **New obligation on future changes:** every change declares a layer, or the sync stops.
