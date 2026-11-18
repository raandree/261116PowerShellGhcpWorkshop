---
status: current
last-verified: 2026-11-18
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

The public history is being cleaned up. On 2026-11-18 the trainer asked to
remove `promptHistory.md` from the repository and its history, and
`git filter-branch` rewrote all five commits of `main` locally. The rewritten
`main` replaces `origin/main` only after the trainer force-pushes it. A short
email that introduces the summary to the customer was drafted in chat and is
not stored in the repository.

The workshop notes are split into 17 topic pages in `docs/`, each with
concepts, common pitfalls, exercises with solutions, key takeaways, and
links. `README.md` is the landing page; `samples/` holds the sample data.

## Evidence

- `README.md` after the change: markdownlint 0 issues, 16 URLs return HTTP
  200, 20 local links and 3 anchors resolve; pandoc renders both
  FileManagementSample links.
- Final check of all pages on 2026-11-17: markdownlint 0 issues, 274
  PowerShell blocks parse, 163 URLs return HTTP 200, 109 local links
  resolve.
- `samples/New-WorkshopFolder.Tests.ps1`: 17 of 17 tests pass;
  PSScriptAnalyzer reports 0 findings for `samples/`.
- History rewrite on 2026-11-18: each rewritten commit differs from its
  original only by the removed `promptHistory.md`; the tip tree, messages,
  authors, and dates are unchanged. Still in the history: the old module
  name in the first two commits and the compaction checkpoints, with local
  paths, in the second and third; the current tree contains neither.
- Local VS Code checkpoint refs under `refs/agents/` still hold snapshots of
  `promptHistory.md`; they were never pushed and stay local.

## Next step

The trainer force-pushes the rewritten `main` to `origin`. To remove the old
module name and the compaction checkpoints as well, rewrite them before that
push, so that one force push replaces the history. Then await the review by
the trainer. `promptHistory.md` and `session/` are local only (Decision 6).

FileManagementSample has no license file (checked on 2026-11-18), so the
README points readers to the repository but does not invite them to copy its
files.
