## Context

See `proposal.md` — Why.

Today `Change.labels` returns capability labels or `tooling`, never both, and `sync()` applies them add-only:

```python
missing = [l for l in change.labels if l not in have]
if missing:
    gh("issue", "edit", ..., "--add-label", ...)
```

There is no branch that removes anything. Every other part of the board is recomputed each run; labels alone accumulate.

Constraints that shape the approach:

- **The layer of a change is not derivable from `openspec/`.** The sync reads only the planning directory — it never sees a diff, a file list, or the implementation. Nothing in a proposal or a task list reliably says "this is client work" in a form worth parsing.
- **`.openspec.yaml` is already trusted for exactly this kind of fact.** `skip_specs: true` is a declaration, not a derivation, and the board has depended on it since labels existed.
- **The preflight from `add-board-issue-descriptions` is the natural home for validation** — it reads every change before the first GitHub write and aborts naming what is wrong.
- **Six changes are already archived and already labelled** on live issues. Whatever the new scheme is, those issues have to converge on it without hand-editing.
- **GitHub labels are repository-wide.** Removing a label from an issue is safe and reversible; deleting the label itself removes it from every issue that ever carried it.

## Goals / Non-Goals

**Goals:**

- Two axes that can be filtered independently, both derived or declared at the change.
- A change that cannot say what layer it belongs to stops the run rather than being labelled by guess.
- Labels converge: an issue ends each run carrying exactly the managed labels it should, no more.

**Non-Goals:**

- Inferring a layer from implementation. If it were inferable, it would not need declaring.
- Owning the whole label namespace. The sync manages two prefixes and nothing else.
- Choosing layers for future changes. This defines the vocabulary, not the assignments.

## Decisions

### The layer is a property of the change, not the capability

A capability spans layers. PRD FR-12 puts rate limiting on the server *because* a client can be bypassed, while FR-5 describes the client flow it protects; both belong to the same eventual `price-reports` capability. A layer attached to the capability is therefore wrong for any capability worth having on both sides of the wire.

A change does not have that problem — it is a unit of work, and this project already splits changes narrowly enough that nearly all of them sit on one side. A change that genuinely spans both declares both, which is a true statement rather than a compromise.

Rejected alternatives:

- **A mapping table** `{capability: layer}` in the script. Goes stale silently the first time a capability is added without a corresponding entry, and produces no label rather than an error.
- **Nested capability paths** (`specs/backend/doe-reference-prices/`). Structural and drift-free, but it encodes the layer *on the capability*, which is the thing established above to be wrong. It would also rewrite `read_capabilities()`, which reads `p.parent.name`.

### Three values, closed set, validated in preflight

`backend`, `frontend`, `tooling`. A missing or unrecognised value aborts the run, naming the change and listing what is allowed.

Validation matters more than it looks. An unvalidated `layer: backedn` would flow straight through `ensure_labels()`, which creates any label it is handed, and the change would appear correctly labelled with a label nobody else shares — visibly fine, quietly wrong. That is the same failure shape the description preflight exists to prevent, so it belongs in the same pass.

`tooling` is a layer value rather than a separate marker because it answers the same question the other two do: where does this work live. Treating it as a pseudo-capability is what produced the false exclusivity in the first place.

### The sync owns two label prefixes and nothing else

```
  capability: …  ─┐
                  ├─ managed: reconciled every run, added and removed
  layer: …       ─┘

  bug, enhancement, good first issue, …  ─ untouched, forever
```

Reconciliation computes the desired set, adds what is missing, and removes any *managed* label not in it. An unmanaged label is never removed, because someone applying `bug` by hand is making a statement the board has no business overruling.

This is deliberately narrower than "make the issue's labels equal the derived set". A board that deletes a human's label teaches people not to use labels.

### Backfill the archive rather than grandfathering it

All six archived changes gain the layer they always had. The alternative — treat a missing `layer` as unlabelled for old changes — leaves the filter useless against the only work that actually exists, which is the work a visitor to the repository sees.

Assignments, and the one judgement call among them:

| Change | Layer |
|---|---|
| `add-locality-registry` | backend |
| `add-doe-price-storage` | backend |
| `add-doe-price-retrieval` | backend |
| `add-project-board-sync` | tooling |
| `add-board-issue-descriptions` | tooling |
| `bootstrap-repo-and-supabase` | tooling |

`bootstrap-repo-and-supabase` is the arguable one. It created the Supabase project and the migrations directory that every backend change since has written into, so calling it backend is defensible. It is `tooling` here because what it actually delivered was repository and environment scaffolding — version control, a credential convention, a linked project, a working migration path — and it shipped no schema. The distinction is one line in one file if it reads wrong later.

Adding metadata to an archived change is not rewriting its history: the layer is a fact that was true when the change shipped and simply had nowhere to be recorded.

### Colour by family

Capability labels stay green — they already read as a family. Layers take their own pair plus the existing purple:

```
  capability: …    green   (unchanged)
  layer: backend   blue
  layer: frontend  orange
  layer: tooling   purple  (the colour the bare `tooling` label already used)
```

Keeping tooling's colour means the visual change on existing cards is a rename, not a reshuffle.

## Risks / Trade-offs

- **A future change forgets `layer:`** → the sync aborts naming it. Loud by design; the fix is one line.
- **Reconciliation removes a label someone applied deliberately** → only if it starts with `capability:` or `layer:`, which are the sync's own namespaces. Everything else is out of reach.
- **The bare `tooling` label lingers in the repository** unused after it is removed from its three issues → left deliberately. Deleting a label is destructive and belongs in a human's hands, and an unused label costs nothing.
- **The first run after this change rewrites labels on all six issues** → expected, and visible in the run output. A second run reports zero.
- **`layer` is a declaration, so it can be wrong** → unlike a derivation, nothing cross-checks it. Accepted: the alternative is inferring it, which cannot be done honestly from the planning directory alone.

## Migration Plan

Add the `layer` line to all seven changes, then run the sync once. Existing issues gain their layer label and shed the bare `tooling`; nothing else moves. Rollback is reverting the script and running again — the previous labels are recomputed, since none of this is stored.
