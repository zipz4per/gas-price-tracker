# Commit conventions

Every commit names the record that explains it.

```
Refs: add-commit-issue-links #14
```

## Setup

```bash
git config core.hooksPath .githooks
```

**Run this once per clone.** A repository cannot set `core.hooksPath` on your
behalf, so until you run it the hook is inert and nothing checks anything. There
is no way around that; the honest thing is to put it first.

## The trailer

`Refs: <record-name> #<issue-number>`, in the trailer block at the end of the
message, alongside `Co-Authored-By:` and the rest.

The record name is a directory under `openspec/changes/` or `openspec/bugs/`,
archived or not — the leading `YYYY-MM-DD-` on an archived record is not part of
its name. The number is its board issue.

Both halves earn their place. GitHub turns `#14` into a *referenced this issue*
event pointing back at the commit, which is the link you actually click. The
name is what still resolves if the board is ever rebuilt and every number shifts,
and it is what makes `git log` readable offline, where a bare `#14` says nothing.

One thing the trailer does not own: GitHub creates a reference from **any**
`#N` anywhere in the message, prose included. `2521898` appears on #1 and #13
as well as on the two its trailers name, because its body discusses them. So an
issue's list of referenced commits is broader than "the commits that implemented
this" — it is "the commits that mentioned this". The trailer is what makes the
first set complete; nothing makes the second set narrow. Write `#N` in prose
when you mean it.

A commit spanning several records repeats the line:

```
Refs: add-doe-price-retrieval #1
Refs: add-locality-registry #4
```

Both issues get the event.

## The whole trailer block

Two trailers reach history, and a third is removed before they do.

```
Refs: add-station-registry #9                              this project's convention
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>      GitHub renders it
```

```
Claude-Session: https://claude.ai/code/session_…           stripped by the hook
```

`Claude-Session:` is emitted by the assistant's harness, not chosen here. It
names a claude.ai web session that resolves only for the repository owner, and
it is not even the identifier that resumes anything — `claude --resume` takes the
local transcript UUID, which the trailer never carried. On a public repository it
was an opaque link in an otherwise deliberate format.

The hook removes it rather than rejecting it. The instruction that emits it
renews every session and the author cannot see or disable it, so rejecting would
make the first commit of every session an error whose obvious workaround is
`--no-verify` — which also disables the `Refs:` check the hook exists for.

**Eighteen commits already carry it**, from before this rule. History was not
rewritten: `8f2488e` is the root, so annotating anything moves all thirty-six
shas, and this repository cites its own shas in thirteen places plus this file.

To find a session again, none of this is needed — `claude --resume` indexes them
per directory:

```bash
claude --continue                    # most recent in this directory
claude --resume                      # picker
claude --resume <transcript-uuid>    # a specific one
```

## Order of operations

A record's issue must exist before its first commit, because the trailer needs
the number:

```
  1. create the record        openspec new change <name>   (or openspec/bugs/<name>/)
  2. file its issue           python3 scripts/sync-project-board.py
  3. commit                   Refs: <name> #<number>
```

This is the order the workflow already follows. Making it mandatory has a second
effect worth having: the board can never be behind the repository, because no
commit describing a record can land before that record has been projected.

## There is no exemption

No `Refs: none`. Repository hygiene — a `.gitignore` line, an editor artefact —
gets a record like everything else.

That is deliberate, and it is the one rule here that costs something. The
alternative was an escape hatch you had to justify in the message. The history
argued against it: the commits that would *legitimately* have used it are the
four below, while the commit that would have *reached* for it is `63f9b00`,
which shipped a skill, a command, four gates and two edits to generated files
and felt like tooling housekeeping at the time. Any rule whose test is "does
this feel like a chore" waves through the exact commit this convention exists
because of.

`git commit --no-verify` bypasses the hook. It is git's, not this project's, and
it cannot be removed. It is not a workflow.

## What the hook checks

```
  a Refs: trailer is present                    always
  the record name exists under openspec/        always, filesystem only
  the number is that record's issue             only when gh is authenticated
```

The name check reads the filesystem rather than the index, because a record is
created before its first commit and is usually not staged yet.

The number check is skipped in silence when `gh` is missing, unauthenticated,
offline or slow — a hook that fails on a plane is a hook that gets uninstalled.
It is *not* skipped when `gh` reaches GitHub and is told the number resolves to
nothing; that is an answer, not an outage, and it fails.

The hook does not fire on merge commits, on empty or comments-only messages, or
when git replays a commit during a rebase. It does fire on `--amend` and on a
rebase `reword`, which are the cases where a message is being written.

## Historical exception

The rule binds from `1380610` (2026-08-30) forward. The thirty commits before it
carry no trailer, and history was not rewritten to add one — `8f2488e` is the
root, so annotating it would move all thirty shas, and this repository cites its
own shas in thirteen places, two of them inside sealed records under
`openspec/bugs/archive/`.

Those commits are linked the other way instead, by
`scripts/backfill-commit-links.py`, which posts each issue's commits as a
comment. Twenty-four of the thirty map to a record. These four do not, and never
will:

```
  8f2488e  Add .gitignore as the repository's first commit
  0d0be1e  Harden .gitignore against latent credential paths
  4fb82e3  Stop committing .env.example
  6902259  Ignore session context-usage dumps
```

They are named here so the gap is documented rather than discovered. Under the
current rule each would need a record.

## See also

- `docs/project-board.md` — what the issues these trailers point at are, and
  where they come from
- `.githooks/commit-msg` — the check itself
- `scripts/backfill-commit-links.py` — the one-time backfill
