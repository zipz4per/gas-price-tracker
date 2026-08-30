# Design

## Context

`.githooks/commit-msg` already reads the message, strips comments and the
verbose-diff scissors block, and validates `Refs:` trailers. It has never
modified the message file, though git permits it to.

Two identifiers are in play, and the one in the trailer is the less useful:

```
  session_01FkpgP1QC93rTtsG4Y6C2E9       claude.ai web session; browser only,
                                         and not what --resume accepts

  071e50cf-2803-4fd9-9830-2206f674a23b   the id `claude --resume` takes, and the
                                         name of a .jsonl on disk
```

## Goals / Non-Goals

**Goals:** no `Claude-Session:` line reaches a commit message, without the
assistant having to remember anything.

**Non-Goals:** recording the stripped value, touching history, or changing any
other trailer.

## Decisions

### Strip rather than reject

A hook that failed the commit would be correct and unusable. The trailer is
emitted by an instruction the author cannot see or disable, so rejection would
make the first commit of every session an error to be worked around — and the
available workaround is `--no-verify`, which also disables the `Refs:` check
this hook exists for. Making the useful check collateral damage of a cosmetic
one is a bad trade.

Stripping is silent and total. Nothing to remember, nothing to bypass.

### Strip after validation, not before

The `Refs:` checks run first and the message is rewritten only once they pass.
A rejected commit therefore leaves the message file exactly as the author wrote
it, so the editor reopens on their own text rather than on a version the hook
quietly edited.

### Remove the line, not the trailer block

Only lines beginning `Claude-Session:` are dropped. `Refs:` and
`Co-Authored-By:` must survive as *trailers* — git parses the trailer block as
the last paragraph, so removing a line from its middle must not leave a blank
line that splits it in two. Verified by parsing the result with
`git interpret-trailers` rather than by eye.

## Risks / Trade-offs

- **`commit-msg` now validates and rewrites.** More responsibility in one hook.
  The alternative, `prepare-commit-msg`, runs before the message is authored, so
  a stripped trailer would simply be written back in.
- **`--no-verify` skips the strip.** Accepted: it skips every check, and the
  trailer surviving is the least of what that bypass costs.
- **The eighteen historical commits keep it.** Documented rather than rewritten.
