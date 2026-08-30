# Design

## Context

Every record in `openspec/` is already projected onto a board issue, and since
`add-issue-dependencies` the issues carry edges to each other. What none of them
carry is a link to the code. The board describes intent; git holds the work; the
two do not touch.

The mapping is mostly recoverable today, by asking which record directory a
commit touched:

```
  24 of 30 commits  resolve to one or more records by path
   6 of 30 commits  resolve to none

       8f2488e  Add .gitignore as the repository's first commit     hygiene
       0d0be1e  Harden .gitignore against latent credential paths   hygiene
       4fb82e3  Stop committing .env.example                        hygiene
       6902259  Ignore session context-usage dumps                  hygiene
       dbcb277  Write board issue links as absolute blob URLs       HAS a record
       63f9b00  Give bug reports an archive workflow of their own   has NONE
```

Path inference is weaker than it looks even where it works. Only 9 of the 30
touch exactly one change directory; 20 touch none, and `d67611d` touches three.
That is the same measurement that forced `change_for_commit()` into
unique-match-or-nothing, and it is why inference cannot be the mechanism here —
it silently produces no answer four times out of five.

GitHub's own mechanism is a `#N` in the message. On push to the default branch
it becomes a *referenced this issue* timeline event pointing back at the commit,
which is exactly the two-way link that is missing. It costs one line and no API
calls.

### Verified before anything was built on it

Measured against this repository, not assumed:

```
  #N in a message -> a `referenced` event on N     yes, and only after push
        #13 carried 0 such events with the commit local, 1 once pushed
  the event links back to the commit               yes, via commit_url
  a bare 7-char sha autolinks in a comment         yes, with a hovercard
  git parses `Refs:` as a trailer                  yes, alongside Co-Authored-By
  commit-msg fires on rebase replay                NO
  commit-msg fires on amend and on reword          yes, and a reword that fails
                                                   halts the rebase recoverably
```

Two of these changed the build.

**`gh` can tell "no such issue" from "cannot ask".** A missing issue returns
exit 1 with *Could not resolve to an issue or pull request with the number of
99999*, which is distinguishable from an auth or network failure. The design
above said the number check is skipped whenever `gh` does not answer; that would
have waved `#99999` through on a fully working machine. So `issue_title()`
returns three things — the title, `False` for a definitive not-found, and `None`
for genuinely unavailable — and only `None` skips.

**`commit-msg` not firing on rebase replay is what makes the rule safe to
adopt.** Had it fired, every rebase would re-validate historical messages
against a working tree that may not contain those records yet, and the 30
untrailered commits would make any rebase across them impossible. It fires only
where a message is being authored, which is exactly where it should.

The sha autolink was confirmed through GitHub's `/markdown` endpoint with
`context` set to the repository, so the backfill's central assumption was
tested without posting a comment to withdraw later.

## Goals

- From any commit, reach the record that explains why it exists.
- From any issue, reach the commits that implemented it.
- Catch the `63f9b00` case — substantive work with no record — at the moment the
  message is written, when it is still cheap to stop and file one.
- Store nothing. No map from record to issue number lives in the repository.

## Non-Goals

- Uniformity across existing history. See *Backfill writes comments, never
  history* below.
- Deriving anything on the board from git. The projection stays one-directional:
  `openspec/` → board. A commit may point at an issue; an issue's status,
  labels, body and edges still come from `openspec/` alone.
- Replacing the prose commit messages this repository already writes. The
  trailer adds a line; it does not license a shorter body.

## Decisions

### The trailer names the record and the issue, not just the issue

```
Refs: add-commit-issue-links #14
```

`#14` is what GitHub links. The name is what survives it. Issue numbers are
assigned by the board and a board can be rebuilt; if it ever is, every number in
history points somewhere arbitrary and the name is the only thing that still
resolves. The name is also what makes `git log` readable offline, where `#14`
says nothing.

The order and shape match the cross-reference the bug bodies already write —
`— add-doe-price-retrieval #1` — so the repository has one way of writing
"this record, that issue" rather than two.

A commit spanning several records repeats the trailer:

```
Refs: add-doe-price-retrieval #1
Refs: add-locality-registry #4
```

Repeating beats a comma-separated list because git's own trailer conventions
already allow repeats, and because a parser that splits on commas has to decide
what a comma inside a record name means. Record names cannot contain commas
today, and relying on that is a rule nobody wrote down.

### There is no exemption trailer

The alternative considered was `Refs: none — <reason>`: an escape hatch that has
to be justified in the message. It was rejected on the evidence above. The
entire population that would legitimately have used it is four `.gitignore`-class
commits. The population that would have *reached* for it is larger and includes
`63f9b00`, which is the commit this change exists because of — a whole feature
that felt like tooling housekeeping at the time, and would have been waved
through by any rule whose test is "does this feel like a chore".

So repository hygiene gets a record. The cost is a directory and three short
files for work that takes one line; the benefit is that the check has no
judgement call in it, and a rule with no judgement call in it cannot be talked
into the wrong answer at 2am.

`git commit --no-verify` remains, because it is git's and cannot be removed. It
is not documented as a workflow. Inventing a second, project-specific bypass
would just be the exemption trailer with extra steps.

### The hook is self-contained and duplicates the archive-date rule

`.githooks/commit-msg` does not import `scripts/sync-project-board.py`, though
both need the same normalization — strip a leading `YYYY-MM-DD-` from an
archived directory name to get the record name.

A commit hook runs in circumstances the sync never sees: mid-rebase, in a
detached worktree, with a syntax error freshly saved in `scripts/`, with no
network. Importing a 1,200-line board client to reuse one regex makes all of
those into a failure to commit. The duplication is eight characters of regex,
and both copies carry a comment naming the other.

### The name is checked offline; the number only opportunistically

Validating that `#14` really is `add-commit-issue-links` needs either the network
or a stored record-to-number map. A stored map is board state written back into
the repository, which is the one thing `docs/project-board.md` forbids — the
sync stores nothing precisely so the board cannot drift, and a cached map would
be the first thing capable of drifting.

So the hook splits the check:

```
  record name exists under openspec/    always, filesystem only, offline
  number matches that record's issue    only when `gh` is authenticated
```

A wrong number is worse than no number — it links confidently to the wrong
issue, the same failure mode that made sha resolution unique-match-or-nothing —
so the check is worth making when it is available. It is skipped in silence
when it is not, because a hook that fails on a plane is a hook that gets
disabled.

### A record's issue must exist before its first commit

The trailer requires a number, and numbers come from the sync. So the order is:
create the record, run the sync, then commit.

This is the order the workflow already follows — a change is proposed before it
is implemented, and the sync files its issue on the next run. Making it
mandatory has a second effect worth having: the board can no longer be behind
the repository, because no commit describing a record can land before that
record has been projected.

### Backfill writes comments, never history

Adding trailers retroactively means rewriting from `8f2488e`, the root, so all
30 shas move. The blast radius was measured, not estimated:

```
  13 sha citations inside openspec/
       2 in openspec/bugs/archive/2026-08-29-board-issue-links-are-relative/
       1 in openspec/bugs/archive/2026-08-29-doe-fuel-type-not-recognised/
       1 in openspec/bugs/report-template.md          (worked example)
       6 in openspec/changes/add-issue-dependencies/
       2 in openspec/changes/archive/2026-08-29-add-bug-reports/
   3 sha citations in live issue bodies  (#10, #11)
```

Three consequences make it not worth it. The board degrades *silently*: `git
show` fails on a dangling sha, `change_for_commit()` returns `""`, and
unique-match-or-nothing turns that into no cross-reference at all rather than an
error. Repairing the citations means editing two sealed reports in
`openspec/bugs/archive/`, which is the exact act `openspec-archive-bug`'s own
guardrail forbids — *rewriting the record to pass a gate falsifies the history
the report exists to keep*. And 28 of the 30 are already on `origin/main`.

A comment costs none of that. It is weaker — issue→commit only, and it is board
state the sync neither writes nor can regenerate — but it is additive, and
nothing it touches is load-bearing.

Idempotency comes from the comment itself. The script reads an issue's comments
back and skips one already carrying its marker heading, so no ledger is stored
anywhere. Re-running it is a no-op; running it after new commits land extends
nothing, because commits with a trailer are excluded by definition.

Two commits need an override, and the script carries them as a visible table
rather than inferring them:

```
  dbcb277  ->  board-issue-links-are-relative   fix committed before the bug was filed
  63f9b00  ->  add-bug-archive-workflow          retro record, filed by this change
```

### Merge commits are exempt; reverts are not

A merge commit has no content of its own, and its message is generated. The hook
skips when `MERGE_HEAD` is present. This repository's history is linear and has
never had one, so the rule costs nothing today and prevents a confusing failure
the first time it does.

A revert is not exempt. Undoing something is a decision, and the record that
explains the decision is the point of the trailer.

### `change_for_commit()` reads the trailer first

The sync's existing path inference stays, as the fallback for the 30 commits
that predate the rule. A trailer, where present, is exact and unambiguous, which
retires the heuristic for everything written from here on — including for
commits that touch no record directory at all, which is where inference has
always returned nothing.

Where a commit carries several trailers, the same rule applies as everywhere
else in this codebase: more than one candidate resolves to no answer.

## Risks / Trade-offs

- **The hook is opt-in.** `core.hooksPath` cannot be set by a repository for
  someone who clones it. A fresh clone is unprotected until one command is run.
  Accepted: the alternative is a committed hook path that git refuses to honour
  anyway. The documentation leads with the command rather than burying it.
- **The offline gap is real.** A brand-new record has no issue number until a
  sync runs, so its first commit cannot be written without network. Accepted,
  and arguably the point — see the ordering decision.
- **Two copies of the archive-date rule.** They can drift. Mitigated by a
  comment in each naming the other, and by the rule being one regex that has
  not changed since `add-bug-reports`.
- **Backfill comments are unowned board state.** They survive a sync because the
  sync manages bodies, labels, status and edges and never comments. They do not
  survive a board rebuild. Accepted as the price of not rewriting history; the
  script can simply be run again.
- **Ceremony for one-line commits.** Under no exemption, ignoring a stray file
  costs a record. Accepted deliberately, and worth revisiting if the hygiene
  records start outnumbering the real ones.
