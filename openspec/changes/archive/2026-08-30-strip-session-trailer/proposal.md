# Keep the session trailer out of commit messages

## Why

Eighteen of thirty-six commits on `main` end with a trailer nobody here chose:

```
Refs: add-commit-issue-links #14
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01FkpgP1QC93rTtsG4Y6C2E9
```

`Refs:` is this project's convention. `Co-Authored-By:` is a general one GitHub
renders as attribution. `Claude-Session:` is neither — it is emitted by the
assistant's harness instructions, and it names a claude.ai web session that
resolves only for the repository owner. On a public portfolio repository it is
an opaque link in an otherwise deliberate commit format.

It is also the wrong identifier. `claude --resume` takes the local transcript
UUID (`071e50cf-…`), not the web session id in the trailer, so the eighteen
commits carry a value that cannot be used to resume anything.

The decision to stop writing it has already been made. This change is about
whether that decision survives, because right now nothing enforces it: the
instruction that emits the trailer renews every session and is invisible to this
repository, so compliance depends on a habit being re-formed each time, with a
public commit as the cost of one lapse.

## What Changes

- **`.githooks/commit-msg` removes any `Claude-Session:` line** from the message
  after the `Refs:` checks pass. The message that lands carries `Refs:` and
  `Co-Authored-By:` only.
- **`docs/commit-conventions.md` documents all three trailers** — the two that
  stay, the one that is removed, and why.

## Explicitly out of scope

- **Rewriting the eighteen commits that already carry it.** Same argument as
  before, now stronger: `docs/commit-conventions.md` cites specific shas and
  `openspec/` cites thirteen more.
- **Recording the stripped value anywhere.** This was `add-local-session-log`,
  scrapped deliberately — `claude --resume` already indexes sessions per
  directory, so a ledger would duplicate what the CLI does better.
- **Removing `Co-Authored-By:`.** It is a real convention and renders as
  attribution. A portfolio repository has no reason to hide how it was built.
- **Rejecting the trailer instead of stripping it.** A hook that fails the
  commit would make every session's first commit an error to be worked around,
  which teaches `--no-verify`.

## Capabilities

None. `skip_specs: true` — see `.openspec.yaml`.

## Impact

- Modified: `.githooks/commit-msg`, `docs/commit-conventions.md`
