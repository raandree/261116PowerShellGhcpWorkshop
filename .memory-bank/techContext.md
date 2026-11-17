---
status: current
last-verified: 2026-11-17
owner: active-agent
source: repository evidence
---

# Tech context

## Stack

- GitHub Flavored Markdown with GitHub alerts and `<details>` blocks.
- Mermaid diagrams in `assets/diagrams/*.mmd`, pre-rendered to SVG with
  Mermaid CLI 11.16 and `assets/diagrams/mermaid-config.json`.
- Banner master `assets/banner.html`, rendered to `assets/banner.png` by
  Microsoft Edge headless at a scale factor of 1.5.

## Environment

- The examples were verified with PowerShell 7.6 on Windows, culture en-US.
- The demo project FileManagementSample ran CI run 44084182216 on
  2026-11-17 with Pester 6.2.0: 52 tests passed on four platforms.

## Constraints

- No personal names and no company references in the handout.
- Diagrams keep a white background, so they stay readable in dark mode.
- `useMaxWidth: false` gives every SVG its natural size.
- Screenshots are captured signed out and cropped to the content.

## Validation

- `npx markdownlint-cli2 README.md assets/README.md`
- Regenerate the images with the commands in `assets/README.md`.
