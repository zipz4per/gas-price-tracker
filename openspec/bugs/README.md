# Bugs

A record of things this project does wrong. One directory per bug, holding a
`report.md` and an `.openspec.yaml`:

```
  openspec/bugs/<name>/
  ├── .openspec.yaml     capability: and layer:, both declared
  └── report.md          the record itself
```

`scripts/sync-project-board.py` projects these onto the project board as issues
titled `[bug] <name>`, beside the `[change] <name>` issues it derives from
`openspec/changes/`. Copy `report-template.md` to start one.

## A bug is not a change

A change is a **commitment** — written up front, executed, archived. A bug is
an **observation**: true whether or not anyone acts on it.

The difference shows up in three places.

**A bug can end without being fixed.** *Won't fix* and *not a bug* are
legitimate endings, and no change has an equivalent. A bug nobody intends to
repair should be closed as not planned, with the reason recorded in `Fixed by`.
Leaving it open as decoration is worse than closing it honestly.

**A bug accretes.** What broke and how to reproduce it are known when it is
filed. The root cause and the commit that caused it are known after
investigation. What the fix changed is known last. That is why a report is one
file with pending sections rather than four artifacts, three of them empty.

**A bug is what someone searches for later.** Six months on, the search is for
the symptom, not for the change that fixed it. So a bug stays open until its
change archives, rather than closing the moment a change is filed.

## When a bug becomes a change

Exactly when the fix changes what the system promises:

```
  spec says          code does          delta      route
  ─────────────────────────────────────────────────────────────────────────
  the right thing    the wrong thing    none       fix + verify. Commit only.
  nothing            something wrong    ADDED      a change; report links to it
  the wrong thing    what spec said     MODIFIED   a change; report links to it
```

The first row is why a bug is not necessarily a change. It looks unsafe — a fix
that leaves no scenario behind can regress — but the scenario **already
exists**; it was never exercised. Every task in this project ends with "and
verify", so a defect contradicting an existing scenario is a verification
failure, and the repair is to actually run it. Inventing a requirement there
would be inventing one to satisfy a workflow.

## The board

`kind:` is derived from location — a record under `openspec/bugs/` is
`kind: bug`, one under `openspec/changes/` is `kind: feature`. It is not
declared, and a `kind:` key in `.openspec.yaml` is rejected rather than ignored.

`capability:` is the one label on a bug that can be wrong. A change derives it
from the capabilities its `specs/` directory writes deltas for; a bug has no
`specs/` directory, so it declares the capability instead. The declared value
must name a directory under `openspec/specs/`, and one that does not aborts the
sync.

A bug's lifecycle maps onto the board's existing status column:

```
  reported / confirmed       →  Proposed
  being fixed                →  In Progress
  fixed, record not closed   →  Ready to archive
  archived                   →  Done
```

*Won't fix* and *not a bug* have no column because they are not stages. They are
closures, and GitHub's "closed as not planned" already says so.
