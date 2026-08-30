# Design

> Reconstructed from `63f9b00` and the files it shipped. See the note in
> `proposal.md`.

## Context

`add-bug-reports` put bug records in `openspec/bugs/<name>/`, deliberately
beside `openspec/changes/` rather than inside it, so that the `kind:` label
could be derived from location and never mistyped. The sync was taught to walk
both trees, including both archives.

Archiving was not. It runs through `/opsx:archive`, whose first step is
`openspec status --change <name>` — and the OpenSpec CLI enumerates
`openspec/changes/` only:

```
  openspec status --change board-issue-links-are-relative
  ✖ Error: Change 'board-issue-links-are-relative' not found
```

Every subsequent step of that workflow consumes the JSON from that call.

## Goals

- Close out a bug with the same ceremony a change gets, so a finished bug does
  not sit at *Ready to archive* indefinitely.
- Make the rule "a bug whose fix lives in a change waits for that change to
  archive" mechanical rather than remembered.
- Survive `openspec update`, which regenerates the vendored `opsx` files.

## Non-Goals

- Teaching the OpenSpec CLI about bugs. This project does not own it.
- Sharing implementation with the change workflow beyond the final `mv`.

## Decisions

### A hand-written sibling, not an extension

The change workflow's steps 2 through 4 — build the artifact graph, read
`tasks.md`, sync delta specs into `openspec/specs/` — all consume the JSON from
the call that fails, and a bug has none of the three inputs. Only the final
`mv` is common. Extending a workflow where four of five steps do not apply
produces a branch, not a shared path.

So `openspec-archive-bug` reads `report.md` directly and never calls the
OpenSpec CLI at all. Its `allowed-tools` say so.

### The bridge into the generated files is one paragraph

`/opsx:archive` and `openspec-archive-change` are generated
(`generatedBy: "1.10.0"`) and `openspec update` will rewrite them. The edit is
confined to a single paragraph that routes a bug name elsewhere and stops, and
that paragraph says so in its own text.

Losing it costs the `/opsx:archive` shorthand, not the capability —
`/opsx:archive-bug` is hand-written and survives. That asymmetry is the reason
the logic lives in the sibling and only the routing lives upstream: recovery is
re-pasting a paragraph rather than reconstructing a branch.

### Four gates, and one of them has no counterpart

```
  Fixed by names a commit, a change, or "won't fix — "
  "Does this need a change?" is answered
  any change it names is already archived        <- no counterpart
  fix tasks have no open boxes ("_None._" counts as done)
```

The third is why this is a workflow and not a documented `mv`. A bug whose fix
lives in a change waits for that change to archive, because what someone
searches for later is the symptom, not the change that repaired it. The rule
was being applied from memory.

### Gates warn and confirm; only a collision is fatal

Matching the change workflow. The single hard failure is a name collision in
`openspec/bugs/archive/`, which would overwrite a record.

### Never edit `report.md` to satisfy a gate

A gate that fails is a fact about the report. Rewriting the record to pass it
falsifies the history the report exists to keep. This is stated as a guardrail
in the skill rather than left to judgement.

## Risks / Trade-offs

- **Two archive commands that are not interchangeable.** Documented in
  `docs/project-board.md`; the bridge makes the common mistake self-correcting.
- **A generated-file edit that will be lost.** Bounded to one paragraph, by
  construction. See above.
- **Gates that warn rather than block can be waved through.** Accepted, for
  parity with the change workflow, and because the alternative is a workflow
  people route around.
