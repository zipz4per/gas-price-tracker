## Context

See `proposal.md` — Why.

What exists: `scripts/sync-project-board.py` walks `openspec/changes/` and its `archive/`, derives a status from `tasks.md` progress, derives `capability:` labels from the change's `specs/` directory and a `layer:` label from its `.openspec.yaml`, composes an issue body from `proposal.md` and `tasks.md`, and writes issues titled `[change] <name>` onto project board #6. Everything on the board is derived; board edits are overwritten on the next run.

Constraints that shape the approach:

- **Nothing may originate on the board.** That is what makes overwriting safe and regeneration lossless. A record that exists only as a GitHub issue would end that property.
- **A bug is known in stages.** What broke and how to reproduce it are known at filing. The root cause and the commit that introduced it are known after investigation. What the fix changed is known last.
- **A bug can end without being fixed.** *Won't fix* and *not a bug* are legitimate terminal states with no equivalent in a change.
- **The existing derived-label convention is load-bearing.** Capability comes from a directory, layer from a declared field; a third axis has to justify which of those it is.

## Goals / Non-Goals

**Goals:**

- A bug found in this project has one obvious place to go, and gets there without being dressed as a change.
- The board shows bugs and changes side by side, still entirely derived from the repository.
- A bug record answers what broke, how to see it, what caused it, and what the fix changed — and says so even when the answer is "never worked" or "not fixed."

**Non-Goals:**

- Fixing the bug that motivated this. The record is the deliverable.
- Triage, severity, assignment, or response times. This is a filing cabinet, not a process.
- Making the board writable. It stays a projection.
- Generalising to a defect tracker for anything but this repository.

## Decisions

### Bugs get a parallel tree, not a slot under `changes/`

`openspec/bugs/<name>/report.md`, beside `openspec/changes/`.

Three placements were considered. Filing straight to GitHub was rejected outright: the board's whole safety property is that nothing originates there, and one record that does makes "run the sync" lossy rather than idempotent.

A bug-report *schema* under `openspec/changes/` was the near miss. The CLI supports it — `openspec new change --schema <name>`, and a schema is a YAML file with arbitrary artifact ids. But `openspec validate` and `openspec archive` both special-case `specs/`, and archiving is defined as merging spec deltas into `openspec/specs/`; a record type with no deltas and a *won't fix* terminal state is being carried by machinery built for something else. It also puts a record under a directory named for the thing it explicitly is not.

A parallel tree costs a second discovery walk in one script. It buys two lifecycles that cannot contaminate each other.

### `kind:` is derived from location, not declared

```
  openspec/bugs/<name>/     →  kind: bug       →  [bug] <name>
  openspec/changes/<name>/  →  kind: feature   →  [change] <name>
```

The `layer:` axis had to be declared in `.openspec.yaml` because nothing in the tree implied it — a change touching `price-reports` could be backend or frontend work. `kind:` is not like that. The directory a record sits in *is* the answer, completely and unambiguously.

Deriving beats declaring whenever deriving cannot be wrong. A declared `kind:` would be a field that can be typed incorrectly, contradicting a path that is already correct; the same reasoning that took capability labels from the `specs/` directory rather than from a list someone maintains.

This means the third axis adds no obligation to anyone writing a record. It appears because of where the file is.

### A bug declares its capability, because it has nothing to derive one from

A change's `capability:` labels come from its `specs/` directory — the capabilities it writes deltas for are the capabilities it touches, and the two cannot disagree. A bug has no `specs/` directory. It is a record about behaviour that already exists, not a proposal to change it.

So `capability:` is declared in `openspec/bugs/<name>/.openspec.yaml`, alongside `layer:`, and this is the one label on a bug that can be wrong. That is worth stating plainly rather than pretending the derivation holds: a mistyped capability on a bug produces a plausible label nobody notices, exactly the failure mode the closed value set guards against for layers. The same guard applies — the value must name a capability that exists under `openspec/specs/`, and an unrecognised one aborts the run rather than creating a new label.

Deriving it from a spec path was considered — the report names the requirement it violates, and the capability falls out of the path. It is appealing because it forces the filer to say which promise is broken, which is the same question that decides whether the bug needs a change at all. It fails on the case where the spec was silent: there is no requirement to point at, which is precisely the defect. A declared field covers all three cases; a derived one covers two.

### The board's status column already fits

No second field. The lifecycles turn out to be parallel:

```
  bug                          change                     column
  ─────────────────────────────────────────────────────────────────────
  reported / confirmed         proposed                   Proposed
  being fixed                  tasks under way            In Progress
  fixed, record not closed     all tasks done             Ready to archive
  archived                     archived                   Done
```

*Won't fix* and *not a bug* have no column because they are not stages — they are closures. GitHub's "closed as not planned" already carries that meaning, and inventing a fifth column would put a dead record permanently on a board of live work.

A bug with no fix tasks yet sits at Proposed, which is exactly right: it has been observed and nothing has been committed to.

### One file that accretes, not a four-artifact quartet

A change is authored once and then executed, which is why proposal, specs, design, and tasks are separate documents written in dependency order. A bug is not authored once. It is filed knowing two things and completed knowing five.

```
  filed                confirmed              fixed
    │                      │                    │
    ├─ what's broken       │                    │
    ├─ reproduction        │                    │
    ├─ impact              │                    │
    │                      ├─ root cause        │
    │                      ├─ caused by ────────┤
    │                                           ├─ fixed by
    │                                           └─ what the fix changed
```

Splitting that across four files would mean three of them are empty at filing time, and an empty artifact reads as neglect rather than as a stage not yet reached. One file with sections that are explicitly *pending* says the true thing.

The fix tasks, when there are any, are checkboxes in the report — so the board's existing progress counter works unchanged.

### Causation and repair are two symmetric commit fields

```
  Caused by:  1a3f1e9  Add DOE reference price retrieval function  (never worked)
  Fixed by:   —        pending
```

Both name a commit. **"Never worked" is a first-class answer to causation, not a blank** — it distinguishes a regression from a defect that shipped with the feature, and those carry different lessons. A regression means something that worked was broken and nothing caught it; a never-worked means it was never verified in the first place.

The causing commit is cheap to find (`git log -S`, `git log --` on the file) and expensive to reconstruct a year later, which is the argument for a field rather than a habit.

### A bug becomes a change when the fix changes a promise

```
  spec says          code does          delta      route
  ───────────────────────────────────────────────────────────────────────
  the right thing    the wrong thing    none       fix + verify. Commit only.
  nothing            something wrong    ADDED      a change; report links to it
  the wrong thing    what spec said     MODIFIED   a change; report links to it
```

The first row is the one that justifies "a bug is not necessarily a change." It looks dangerous — a fix that leaves no scenario behind can regress — but the scenario **already exists**; it was simply never exercised. Every task in this project ends with "and verify", so a defect contradicting an existing scenario is a verification failure, and the repair is to actually run it. No new spec text is honest there, and inventing some to satisfy a workflow would be inventing a requirement to satisfy validation.

### A bug stays open until its change archives

When a bug spawns a change, the obvious move is to close the bug and let the change carry the work. That loses the story. Six months later someone searches for the symptom — "no data for RON 95" — not for `fix-fuel-type-matching`. A closed bug pointing at a change is a redirect; an open bug is the thing that answers the search.

The cost is a longer-lived open issue. That is a cost worth paying for a board whose whole purpose is that the record can be found.

## Risks / Trade-offs

- **A second discovery walk is a second place for the script to be wrong** → both trees are read by one function shape, and the preflight that already aborts on unreadable proposals covers reports too, so a malformed report stops the run rather than producing a half-synced board.
- **A third label axis crowds the card** → `kind:` has two values and is derived, so it costs nothing to maintain; if the board becomes noisy, the axis to question is this one, because it carries the least information.
- **Bugs may accumulate unfixed and clutter a board of live work** → *won't fix* and *not a bug* are real closures and should be used; a bug nobody will fix should be closed as not planned, not left as decoration.
- **The report format may not survive its second bug** → filing the fuel-type bug through it is a task in this change precisely so the format meets real content before it is settled. The `Impact` section is the one most likely to collapse into `What's broken`.
- **Two record types under one board make "how much work is left" ambiguous** → the `kind:` filter is the answer, which is most of why the axis exists.

## Migration Plan

Additive. `openspec/bugs/` does not exist, so nothing moves; existing changes keep their titles, labels, and columns. The `kind:` label is new on every card, so the first sync after this change relabels the whole board — expected, and covered by the existing label reconciliation, which only touches managed prefixes.

The one ordering constraint: the sync script must learn `[bug]` titles before the first report is filed, or the report exists in the repository with no issue and the board is briefly not a complete projection.

## Open Questions

None. The one this change carried — whether `Impact` earns a section of its own or collapses into `What's broken` — was deferred until the fuel-type bug filled it with real content, and it is now settled: **kept**.

Filled in, `Impact` carried two things `What's broken` did not and should not. Blast radius: every consumer of the read path, which is currently the only way to get a DOE figure out of the database. And detectability: the failure is silent by construction, because `has_data = false` is a documented legitimate state, so a monitor watching for errors sees nothing and a developer reading the response sees a shape the spec explicitly blesses.

Neither belongs in a description of the symptom. `What's broken` answers *have I hit this*; `Impact` answers *how much does it matter and would we ever notice*. The second question was the one that made this bug worth filing before the frontend rather than after.
