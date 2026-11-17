---
status: current
last-verified: 2026-11-17
owner: shared
source: repository evidence
---

# Product context

## Problem

The raw notes from the workshop were a chronological list of console
transcripts, commands, and links. The participants need a readable reference
to revisit the topics after the workshop.

## Users

- Workshop participants with mixed experience, from PowerShell one-liners to
  complete solutions, CI/CD, Pester, and GitHub Copilot.

## Core workflows

1. Start at `README.md`, pick a topic, and follow the navigation links from
   one topic page in `docs/` to the next.
2. Create the sample data with `samples/New-WorkshopFolder.ps1` and
   `samples/People.csv`, then solve the exercises and compare with the
   collapsible solutions.
3. Clone the demo project FileManagementSample and repeat the demos.

## Experience goals

- Ready for the customer: banner, diagrams, callouts, and tables.
- Neutral content: no personal names and no company references.
- Every example is verified by running it or against its source.
