---
status: current
last-verified: 2026-11-18
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

The summary is published: `origin/main` is a public GitHub repository and
matches the local `main` (checked on 2026-11-18). A short email that
introduces the summary to the customer was drafted in chat and is not stored
in the repository.

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
- `git log origin/main` on 2026-11-18: the history was pushed without the
  planned squash. Commits `b21304f` and `13acb5a` still contain the old
  module name, `promptHistory.md`, and the compaction checkpoints with local
  paths; the current tree contains none of them.

## Next step

Await the review by the trainer. Decide whether to rewrite the public
history: removing the old module name and the checkpoints from `b21304f` and
`13acb5a` needs a squash and a force push to `origin/main`, which only the
trainer can authorize. `promptHistory.md` and `session/` are local only
(Decision 6).

FileManagementSample has no license file (checked on 2026-11-18), so the
README points readers to the repository but does not invite them to copy its
files.
