# <One line: the wrong thing the system does>

<!-- Copy this file to openspec/bugs/<name>/report.md and fill it in. Sections
     not yet known keep their pending marker; none of them is left blank. The
     board publishes What's broken, Impact, Reproduction, Root cause, Caused
     by, Fixed by, and Does this need a change. -->

## What's broken

<The observable symptom, not the diagnosis. What does the system do that it
should not, or fail to do that it should? Someone who has never seen this code
should be able to read this first paragraph and know whether they have hit the
same thing — it is published as the issue description.>

## Impact

<Who or what is affected, and how far it reaches. An unknown blast radius is
itself a finding: say so rather than leaving it out.>

## Reproduction

<Actual and expected side by side — a table, a transcript, or a query and its
output. Not a narrative of steps. The reader should be able to run this and see
the wrong answer for themselves.>

```
  input                     actual                   expected
  ──────────────────────────────────────────────────────────────────────────
```

## Root cause

_Not yet investigated._

<When known: why the system does this, naming files and lines. If the code is
wrong in a way that looks right — a comment justifying the wrong branch, a
plausible default, a believable number — quote it. That is what let it survive
review, and it is the part a later reader cannot reconstruct.>

## Caused by

_Not yet investigated._

<Once the root cause is known, exactly one of:

  `<sha>  <subject>`                  a regression — this worked, and this
                                      commit broke it. A guard was missing.

  `<sha>  <subject>  (never worked)`  shipped defective with the feature. The
                                      behaviour was never verified.

  `spec was silent`                   nothing said which behaviour was correct,
                                      so the implementation chose.

These carry different lessons, which is why the field is not a free-text
blank. `git log -S` and `git log -- <path>` find the commit in one command now
and are expensive to reconstruct in a year.

The board resolves the sha to the change that carries it and publishes the
issue beside it, so the line above becomes:

  `1a3f1e9  Add DOE reference price retrieval function`  (never worked)
      — add-doe-price-retrieval #1

Resolution is automatic and needs nothing here. It is deliberately timid: it
takes a match only when the commit touched exactly one change directory, so a
commit touching none — most of them — or several resolves to nothing and the
line prints unchanged. Naming the change yourself overrides that, which is the
way to link a cause the commit itself cannot point at.

This is a reference, not a dependency. The causing change is finished; it is
not blocking the bug and is not marked as doing so.>

## Fixed by

_Pending._

<One of: `<sha>  <subject>`, the change that carries the fix, or
`won't fix — <reason>`. A bug closed as not planned records its reason here.>

## What the fix changed

_Pending._

<What is different afterwards, in behaviour rather than in diff. If the fix
left behind a scenario that would have caught this, name it — a fix with no
scenario behind it can come back.>

## Does this need a change?

_Not yet decided._

<One of:

  **No** — the spec already promises the right thing. The code contradicted it
  and the scenario was never exercised. Fix and verify; no proposal.

  **Yes, added requirement** — the spec was silent. Link the change.

  **Yes, modified requirement** — the spec promised the wrong thing. Link the
  change.>

## Fix tasks

_None._

<Checkboxes only when there is work tracked here rather than in a change. They
are what the board counts for this bug's progress, so a bug whose fix lives in
a change tracks its tasks there and leaves this section as `_None._`. The form
is the same as tasks.md:>

```
  - [ ] 1.1 Do the thing and verify the thing is done
```
