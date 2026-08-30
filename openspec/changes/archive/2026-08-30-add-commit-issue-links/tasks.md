# Tasks

## 1. Prove the mechanism before building on it

- [x] 1.1 Confirm a `#N` in a commit message produces a *referenced this issue*
      timeline event on #N, and that it appears only after the commit reaches
      the default branch. Use the pending `add-issue-dependencies` work as the
      subject: commit it with `Refs: add-issue-dependencies #13`, check #13's
      timeline before pushing and after.
- [x] 1.2 Confirm the event links back to the commit, so the issue→commit
      direction works without anything else being written.
- [x] 1.3 Confirm a repeated trailer produces an event on each issue named, not
      just the first. Verified by `2521898`, which names #14 and #15; both
      timelines carry the event.
- [x] 1.4 Confirm a bare sha inside an issue *comment* autolinks to the commit,
      since the backfill depends on it.
- [x] 1.5 Confirm a `#N` naming a closed issue still produces the event —
      most records are archived, so most trailers will name closed issues.
      Verified by `2521898`: #15 was already closed and got the event anyway.
- [x] 1.6 Record every result in `design.md` under Context, including any
      assumption that turned out wrong.

## 2. The trailer

- [x] 2.1 Fix the grammar: `Refs: <record-name> #<number>`, one record per
      trailer line, repeatable, anywhere in the message body.
- [x] 2.2 Write the resolver: a record name is valid when a directory of that
      name exists under `openspec/changes/`, `openspec/bugs/`, or either
      archive, with a leading `YYYY-MM-DD-` stripped from archived names.
- [x] 2.3 Confirm an archive commit validates. At `commit-msg` time the record
      already sits at its archive path, so this is the case the date-stripping
      exists for.
- [x] 2.4 Confirm a record still on disk but not yet committed validates — the
      resolver reads the filesystem, not the index, because a record is created
      before its first commit.

## 3. The hook

- [x] 3.1 Write `.githooks/commit-msg`, self-contained, no import from
      `scripts/`. Carry a comment naming the duplicated archive-date rule and
      its counterpart in `sync-project-board.py`.
- [x] 3.2 Reject a message with no `Refs:` trailer. The failure message shows
      the expected form and lists the record names currently available.
- [x] 3.3 Reject a trailer naming a record that does not exist, and say which
      name failed rather than only that one did.
- [x] 3.4 Skip silently when `MERGE_HEAD` is present.
- [x] 3.5 Skip a message that is entirely comments or empty — git aborts those
      itself, and failing first would replace git's clear message with ours.
- [x] 3.6 Verify the issue number when `gh` is authenticated: the issue's title
      must be the record's issue title. Report a mismatch as a failure.
- [x] 3.7 Skip the number check in silence when `gh` is missing, unauthenticated,
      or the call fails. Verify by running the hook with `PATH` emptied.
- [x] 3.8 Exit 0 on a valid message with no output. A hook that prints on
      success trains people to ignore it.
- [x] 3.9 `chmod +x`, and verify the hook actually runs by making a commit that
      should fail.

## 4. Wiring it up

- [x] 4.1 Run `git config core.hooksPath .githooks` in this clone and confirm
      `.git/hooks/` is now bypassed.
- [x] 4.2 Confirm `--no-verify` bypasses it, so the escape hatch is known to
      work before it is needed.
- [x] 4.3 Confirm the hook does not fire on `git rebase` continuation of a
      commit that already passed, or record the behaviour if it does.

## 5. The retro record for `63f9b00`

- [x] 5.1 Create `openspec/changes/add-bug-archive-workflow/` describing the
      bug-archive workflow that shipped in `63f9b00`: proposal, design, tasks
      all complete, `layer: tooling`, `skip_specs: true`.
- [x] 5.2 State in the proposal that it was written after the fact, and name the
      commit. A retro record that reads as though it preceded the work is worse
      than no record.
- [x] 5.3 Reconstruct the design decisions from the commit message rather than
      re-deriving them, so the record says what was actually decided.
- [x] 5.4 `openspec validate --strict` passes.
- [x] 5.5 Archive it immediately to `openspec/changes/archive/2026-08-30-add-bug-archive-workflow/`.
- [x] 5.6 Sync and confirm the board files it as Done with `layer: tooling` and
      no capability label.

## 6. Backfill

- [x] 6.1 Write `scripts/backfill-commit-links.py`. It walks history, selects
      commits with no `Refs:` trailer, maps each to its record by path, and
      groups them by issue.
- [x] 6.2 Carry the two overrides as a literal table with a comment on each:
      `dbcb277 -> board-issue-links-are-relative`,
      `63f9b00 -> add-bug-archive-workflow`.
- [x] 6.3 Post one comment per issue listing its commits, sha and subject, under
      a fixed marker heading.
- [x] 6.4 Make it idempotent by reading comments back and skipping an issue that
      already carries the marker. Store nothing on disk.
- [x] 6.5 Report the commits that map to no record instead of failing on them,
      and confirm the report is exactly the four hygiene commits.
- [x] 6.6 Give it `--dry-run`, printing every comment it would post in full.
- [x] 6.7 Dry run, read the output, then run it live.
- [x] 6.8 Run it a second time and confirm zero comments posted.
- [x] 6.9 Spot-check three issues in the browser: comment renders, shas autolink,
      and the commits listed are the right ones.
- [x] 6.10 Fix the record-path regex, which under `re.M` let `[^/]+` match a
      newline: a file directly under `openspec/bugs/` made the captured name run
      into the next path and shadow the real record. Same latent bug fixed in
      `sync-project-board.py`.

## 7. The sync reads the trailer

- [x] 7.1 Teach `change_for_commit()` to read `Refs:` trailers first, falling
      back to path inference when there are none.
- [x] 7.2 Resolve to nothing when a commit carries several trailers naming
      different changes, matching the existing unique-match-or-nothing rule.
- [x] 7.3 Ignore a trailer naming a bug — the helper answers which *change* a
      commit belongs to, and a bug is not one.
- [x] 7.4 Confirm the 30 existing commits resolve exactly as before, since none
      carries a trailer. They do — and re-measuring showed the figures recorded
      in `add-issue-dependencies` were wrong (20 resolve, not 9; `d67611d`
      touches four changes, not three). Corrected in that record and here.
- [x] 7.5 Confirm a trailered commit resolves through the trailer even when it
      touches no change directory — the case inference has always missed.
- [x] 7.6 Full sync, then a second run reporting `0 update(s) applied`.

## 8. Documentation and close-out

- [x] 8.1 Write `docs/commit-conventions.md`: the trailer, the setup command
      first, what the hook checks, why there is no exemption, and the ordering
      constraint that a record's issue must exist before its first commit.
- [x] 8.2 Name the four hygiene commits there as the historical exception, so
      the gap is documented rather than discovered.
- [x] 8.3 Cross-link from `docs/project-board.md` — the trailer points at board
      issues, and someone reading about the board will want to know.
- [x] 8.4 Note in `docs/project-board.md` that backfill comments exist, are not
      managed by the sync, and are lost on a board rebuild.
- [x] 8.5 `openspec validate --strict` passes for this change.
- [x] 8.6 Confirm every commit made while implementing this change carries its
      own trailer.
