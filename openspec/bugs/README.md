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

A bug's issue carries its dependencies too, both derived from the report:

```
  Fixed by names a change   ->  the bug's issue is BLOCKED BY that change's
                                issue. The bug cannot close until the change
                                archives, and now the board says so.

  Fixed by names a commit   ->  no edge. The work is already in the tree and
                                there is no record still to archive.

  Caused by resolves        ->  a CROSS-REFERENCE in the body, not an edge.
```

Causation is not a dependency, which is why it is only a reference. The change
that caused a bug is finished; marking it as *blocking* would put an obligation
on a card nobody can act on, and the Done column would stop meaning finished.
GitHub has no `relates to` in its API, so a link in the body is the honest
representation — it still shows on the causing issue's timeline.

A bug never declares `blocked_by:` in its `.openspec.yaml`; a declaration is
rejected the way a declared `kind:` is. Its blocker is read from `## Fixed by`,
the same line `/opsx:archive-bug` reads to decide whether the bug may close, so
the board and the gate cannot disagree.

A bug's lifecycle maps onto the board's existing status column:

```
  reported / confirmed       →  Proposed
  being fixed                →  In Progress
  fixed, record not closed   →  Ready to archive
  archived                   →  Done
```

*Won't fix* and *not a bug* have no column because they are not stages. They are
closures, and GitHub's "closed as not planned" already says so.

## Archiving one

```
  /opsx:archive-bug <name>
```

`/opsx:archive` cannot do it. That workflow resolves its target with
`openspec status --change`, and the OpenSpec CLI enumerates `openspec/changes/`
only, so a bug comes back *"Change '<name>' not found"* and it never gets a
directory to move. Its middle steps would not fit one anyway — the artifact
graph, `tasks.md` and the delta-spec sync all read that same JSON, and a bug has
none of the three.

`/opsx:archive-bug` reads `report.md` directly and checks four things:

```
  Fixed by                    names a commit, a change, or won't fix — not still pending
  Does this need a change?    answered
  the change it names         already in openspec/changes/archive/
  Fix tasks                   no open boxes (_None._ counts as done)
```

The third has no counterpart in the change workflow, and it is why this is a
workflow rather than a bare `mv`. A bug whose fix lives in a change waits for
that change to archive, because the thing someone searches for later is the
symptom, not the change that repaired it.

None of the four blocks — each warns and asks. The only hard failure is a name
collision in `openspec/bugs/archive/`, which would overwrite a record. A gate
that fails is a fact about the report, so the fix is to finish the report, never
to edit it into passing.

Archiving does not touch the board; `scripts/sync-project-board.py` is what moves
the card to **Done** and closes the issue.

**Where these live.** `.claude/skills/openspec-archive-bug/SKILL.md` and
`.claude/commands/opsx/archive-bug.md` are hand-written and permanent. The
routing paragraph in `.claude/commands/opsx/archive.md` and
`.claude/skills/openspec-archive-change/SKILL.md` — the part that makes
`/opsx:archive <a-bug>` redirect instead of failing — is a local edit to a
generated file, and `openspec update` will delete it. Losing it costs the
shorthand, not the capability: `/opsx:archive-bug` still works. Re-paste it from
this file's history when it goes.
