---
status: current
last-verified: 2026-11-17
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

The workshop notes are split into 17 topic pages in `docs/`, each with
concepts, common pitfalls, exercises with solutions, key takeaways, and
links. `README.md` is the landing page; `samples/` holds the sample data.

## Evidence

- Final check on 20 Markdown files: markdownlint 0 issues, 274 PowerShell
  blocks parse, 163 URLs return HTTP 200, 109 local links resolve.
- `samples/New-WorkshopFolder.Tests.ps1`: 17 of 17 tests pass;
  PSScriptAnalyzer reports 0 findings for `samples/`.
- Five writers produced pages 02 to 17 from briefs; the controller reviewed
  every page and spot-checked claims by running them.

## Next step

Await the review by the trainer. Open item from the workshop: add the module
files of the ZfFileManagementModule once the trainer provides them.
