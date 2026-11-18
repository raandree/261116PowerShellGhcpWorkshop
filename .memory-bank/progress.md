---
status: current
last-verified: 2026-11-18
owner: active-agent
source: repository evidence
---

# Progress

## Current status

The workshop notes are public on GitHub as 17 verified topic pages and await
review; the rewritten history of `main` awaits a force push.

## Recent milestones

- 2026-11-18: `promptHistory.md` removed from every commit of `main` with
  `git filter-branch`, at the trainer's request; force push pending.
- 2026-11-18: `origin/main` is public and matches `main`; the history was
  pushed without the planned squash.
- 2026-11-18: README next steps point to FileManagementSample, where the
  module offered during the workshop is published; the open item is closed.
- 2026-11-18: `promptHistory.md` and the compaction checkpoints in
  `session/` are no longer tracked; earlier commits had included them.
- 2026-11-17: README split into 17 topic pages in `docs/`, each extended
  with examples, pitfalls, exercises, and takeaways; new chapter on
  scaffolding a module with Sampler; sample data in `samples/`.
- 2026-11-17: Workshop notes README with six diagrams, a banner, a CI
  screenshot, and verified references.
- 2026-11-17: Canonical Memory Bank base initialized.

## Stable capabilities

- Image regeneration is documented in `assets/README.md`.
- `samples/New-WorkshopFolder.ps1` creates the same 22 sample files on every
  run and platform; its Pester tests cover it.

## Open work

- Review of the topic pages by the trainer.
- Force-push the rewritten `main`; until then `origin/main` still contains
  `promptHistory.md`.
- Decide whether to remove the old module name and the compaction
  checkpoints from the early commits too, before the force push.
- FileManagementSample has no license file; it needs one before the README
  can invite readers to reuse its files.
