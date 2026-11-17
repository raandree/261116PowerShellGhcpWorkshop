---
status: current
last-verified: 2026-11-17
owner: devops-training-writer
source: repository evidence
---

# Module registry

One row per topic page in `docs/`. IDs use the prefix `WS-`. A module depends
on the module before it unless the row names other dependencies.

| ID    | Module                             | Part | Focus                                                | Sample data          | Status   |
|-------|------------------------------------|------|------------------------------------------------------|----------------------|----------|
| WS-01 | Everything is an object            | 1    | Properties, methods, `Get-Member`, dates, files      | Folder               | Reviewed |
| WS-02 | The pipeline, loops, and filters   | 1    | `$_`, streaming, `Where-Object`, filter left         | Folder               | Reviewed |
| WS-03 | Building a pipeline step by step   | 1    | Group, sort, select, measure; calculated properties  | Folder               | Reviewed |
| WS-04 | Hashtables                         | 1    | Keys, lookups, ordered dictionaries                  | Folder, People.csv   | Reviewed |
| WS-05 | PSCustomObject                     | 1    | Records, property order, lists of objects            | Folder, People.csv   | Reviewed |
| WS-06 | CSV, JSON, and YAML                | 1    | Import, export, types, exact sums, YAML              | Folder, People.csv   | Reviewed |
| WS-07 | Inspecting and extending objects   | 1    | `Add-Member`, `PSObject`, `Update-TypeData`          | Folder, People.csv   | Reviewed |
| WS-08 | Strings and the format operator    | 1    | Quotes, here-strings, `-f`, culture, parsing logs    | Folder, People.csv   | Reviewed |
| WS-09 | Your first function                | 2    | Parameters, validation, help, output objects         | Folder               | Reviewed |
| WS-10 | Pipeline input                     | 2    | Binding by value and property name, `process`        | Folder, People.csv   | Reviewed |
| WS-11 | Splatting                          | 2    | Hashtable and array splatting, `$PSBoundParameters`  | Folder               | Reviewed |
| WS-12 | Debugging in VS Code               | 3    | Breakpoints, watch, call stack, console debugger     | Folder               | Reviewed |
| WS-13 | Scaffolding a module with Sampler  | 3    | `New-SampleModule`, `Add-Sample`, first build        | Folder               | Reviewed |
| WS-14 | Testing with Pester                | 3    | `Describe`, `It`, `Should`, `-ForEach`, `Mock`       | Folder, sample tests | Reviewed |
| WS-15 | Building with Sampler              | 3    | `build.yaml` workflows, tasks, versioning            | Demo project         | Reviewed |
| WS-16 | CI/CD with GitHub Actions          | 3    | `ci.yml` anatomy, matrix, secrets, artifacts         | Demo project         | Reviewed |
| WS-17 | GitHub Copilot in the demo project | 3    | Instructions, `applyTo`, skills, Memory Bank, review | Demo project         | Reviewed |

## Notes

- WS-13 was added at the user's request; it has no source in the original
  workshop notes. WS-14 and WS-15 build on the project it creates.
- Topic diagrams: `13-function-to-module` for WS-13, `17-copilot-context` for
  WS-17; the shared diagrams are listed in `assets/README.md`.
