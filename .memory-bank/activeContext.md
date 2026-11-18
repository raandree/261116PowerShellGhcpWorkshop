---
status: current
last-verified: 2026-11-18
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

The README's next steps point to FileManagementSample. The module the
trainer offered to provide during the workshop is published there, so the
open item to request it is closed.

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

## Next step

Await the review by the trainer. FileManagementSample has no license file
(checked on 2026-11-18), so the README points readers to the repository but
does not invite them to copy its files.
