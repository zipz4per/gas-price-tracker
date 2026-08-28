# Artifact links on board issues resolve to nothing

## What's broken

Every link the board sync writes into an issue body — `[proposal]`, `[design]`, `[spec: …]`, and now `[report]` — is a repository-relative path. GitHub resolves a relative href in an issue body against the issue's own URL rather than the repository root, so clicking one lands on `/issues/openspec/…` and returns a 404. Every artifact link on every issue the board has ever created is dead.

## Impact

All ten issues, since the board's first run. The links are the only route from a card to the document that produced it, and this repository is public and serves as a portfolio, so the reader most likely to click one is the reader least able to guess the right URL.

It is invisible from the sync's side. The script writes markdown it never renders, `--dry-run` prints no links at all, and a broken link is indistinguishable from a working one in the issue body's source. Nothing fails, so nothing reports.

## Reproduction

```
  from                            href written                          resolves to                                    HTTP
  ──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
  issue #10 body                  openspec/bugs/…/report.md             …/gas-price-tracker/issues/openspec/bugs/…      404
  issue #9 body                   openspec/changes/…/proposal.md        …/gas-price-tracker/issues/openspec/changes/…   404
  what it should be               —                                     …/gas-price-tracker/blob/main/openspec/…        200
```

```bash
gh api repos/zipz4per/gas-price-tracker/issues/10 \
  -H "Accept: application/vnd.github.html+json" --jq '.body_html' \
  | grep -oE '<a [^>]*href="[^"]*report[^"]*"'
#  <a href="openspec/bugs/doe-fuel-type-not-recognised/report.md"
```

## Root cause

`build_change_body()` and `build_bug_body()` in `scripts/sync-project-board.py` pass `_where()` — which returns a path relative to the repository root — straight into markdown link syntax:

```
  lines += ["", f"- [proposal]({rel}/proposal.md)"]
  lines += ["", f"- [report]({rel}/report.md)"]
```

A repo-relative path is the correct form inside a file committed to the repository, where GitHub resolves it against the file's own location in the tree. An issue body is not in the tree. The same string is right in one context and wrong in the other, which is why it was never questioned: it is exactly what a link in `README.md` looks like.

The sync never renders what it writes, so nothing in the script could have caught it.

## Caused by

`ab88d1c  Add GitHub Project board sync for OpenSpec changes`  (never worked)

## Fixed by

`dbcb277  Write board issue links as absolute blob URLs`

## What the fix changed

Artifact links are absolute `https://github.com/<repo>/blob/main/<path>` URLs. All 24 links a sync would now write were checked live: 22 return 200, and the two that do not are the bug reports themselves, which are not yet on the default branch. Archived changes resolve too — their files still exist on `main`.

The check that was missing is `artifact_links()`, one function shared by both body builders and by the dry run. A dry run now prints every URL it would write, which is the only inspection available to a script that emits markdown it never renders. It would have caught this on the board's first run.

## Does this need a change?

**No.** The board is tooling: it declares `skip_specs: true` and touches no capability, so nothing in `openspec/specs/` promises anything about it. `docs/project-board.md` says the body carries "links to the artifacts present in the change directory", which stays true — the links exist, they just do not work.

This is the case where a fix is a commit rather than a proposal. What it does need is a check that would have caught it, since neither a dry run nor the issue body's source distinguishes a working link from a dead one.

## Fix tasks

- [x] 1.1 Write artifact links as absolute `blob/<branch>` URLs in both body builders, and verify a rendered issue link returns HTTP 200
- [x] 1.2 Verify every existing issue's links are repaired by a re-sync, including archived changes whose files still exist on the default branch
- [x] 1.3 Verify the sync reports the links it writes, so a dry run shows what a reader would click
