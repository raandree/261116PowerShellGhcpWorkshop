---
status: current
last-verified: 2026-11-18
owner: active-agent
source: repository evidence
---

# System patterns

## Architecture

- `README.md` is the handout: one document with the topics in three parts.
- `assets/` holds the generated images next to their sources.

## Decisions

### Decision 1: Use the canonical Memory Bank base

- Choice: Keep durable project context in `.memory-bank`.
- Rationale: Preserve evidence-backed context across sessions.

### Decision 2: Pre-render the diagrams to SVG

- Choice: Write the diagrams in Mermaid, commit the rendered SVG files, and
  embed the SVG files in the README.
- Rationale: The diagrams render the same on GitHub, Azure DevOps, in VS Code,
  and in print, with one consistent theme.

### Decision 3: Keep the handout neutral

- Choice: No personal names and no company references; screenshots are
  captured signed out and cropped to the content.
- Rationale: The handout goes to the customer as it is.

### Decision 4: One page per topic with a fixed template

- Choice: Every page in `docs/` has a breadcrumb, concepts, common pitfalls,
  exercises with collapsible solutions, key takeaways, links, and a
  navigation footer. Content beyond the workshop is integrated without
  markers.
- Rationale: The user chose this structure; a fixed template keeps 17 pages
  consistent and easy to navigate.

### Decision 5: Deterministic sample data

- Choice: Exercises use `samples/People.csv` and the folder that
  `samples/New-WorkshopFolder.ps1` creates; the script writes identical
  bytes on every platform and deletes only folders that carry its marker.
- Rationale: Exercise solutions can show real, reproducible output.

### Decision 6: Version only the shared Memory Bank files

- Choice: `promptHistory.md` and `session/` stay local. `.git/info/exclude`
  lists both, and commits stage explicit paths instead of `git add -A`.
- Rationale: The prompt history is local by design, and the compaction
  checkpoints contain local paths; Decision 3 keeps the repository neutral.
