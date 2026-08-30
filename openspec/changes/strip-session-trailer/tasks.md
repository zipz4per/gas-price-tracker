# Tasks

## 1. The strip

- [x] 1.1 Remove any line beginning `Claude-Session:` from the message in
      `.githooks/commit-msg`, after the `Refs:` checks pass.
- [x] 1.2 Write the file back only when something was actually removed, so an
      unaffected message is untouched on disk.
- [x] 1.3 Verify `Refs:` and `Co-Authored-By:` still parse as trailers
      afterwards, using `git interpret-trailers` rather than by eye.
- [x] 1.4 Verify a message with no `Claude-Session:` is byte-identical after
      the hook runs.
- [x] 1.5 Verify a rejected message is left exactly as written, with no strip
      applied.
- [x] 1.6 Re-run the existing 16-case hook suite unchanged.

## 2. End to end

- [ ] 2.1 Make a real commit whose message contains the trailer, and verify the
      commit on `main` does not.
- [ ] 2.2 Verify that commit shows exactly two trailers.

## 3. Documentation and close-out

- [x] 3.1 Document all three trailers in `docs/commit-conventions.md`: the two
      that stay, the one that is stripped, and why.
- [x] 3.2 Note that eighteen historical commits carry it and history was not
      rewritten.
- [x] 3.3 `openspec validate --strict` passes.
