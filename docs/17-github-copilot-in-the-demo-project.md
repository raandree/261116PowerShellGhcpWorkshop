# GitHub Copilot in the demo project

[Overview](../README.md) › Part 3: Engineering practices › Topic 17 of 17

GitHub Copilot follows the rules of a project only when it knows them. The
demo project writes its rules into Markdown files that Copilot reads with
every request, or when a task needs them. This topic explains each kind of
file, and how you check what Copilot produces before you accept it.

In this topic, you learn to:

- give Copilot repository-wide and path-specific instructions
- package a repeated procedure as a skill
- keep project knowledge in a Memory Bank
- review generated code with tests, PSScriptAnalyzer, and the build
- keep commits, pushes, and releases in your own hands

## How the demo project prepares Copilot

The demo project is prepared for GitHub Copilot. These files give Copilot the
conventions of the project, so its suggestions follow them:

| File or folder                           | What it tells Copilot                                                                                                     |
|------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| `.github/copilot-instructions.md`        | Rules for the whole repository: run every build and test through `./build.ps1`, and leave all Git operations to the user  |
| `.github/instructions/*.instructions.md` | Rules for specific files, selected by `applyTo`. For example, `source/Public/**/*.ps1` requires help and `[OutputType()]` |
| `.github/skills/*/SKILL.md`              | Skills: procedures Copilot loads when a task needs them, such as `validate-changes`, which picks the right test scope     |
| `.memory-bank/`                          | Project knowledge in Markdown that outlasts a chat session; `index.md` routes each task to the files it needs             |

The files differ in when they reach Copilot. Instructions arrive with a
request automatically, skills when the task calls for them, and the Memory
Bank only when you or an instruction ask Copilot to read it. Whatever
Copilot proposes, you review it before it becomes part of the project:

![Your request and the instruction, skill, and Memory Bank files reach Copilot;
you review its proposal before you commit](../assets/diagrams/17-copilot-context.svg)

## Repository-wide instructions

`.github/copilot-instructions.md` holds *repository-wide custom
instructions*: Markdown that applies to all requests made in the context of
the repository. It needs no *front matter*, the block of YAML between two
`---` lines at the start of a file. Because Copilot receives these
instructions with every chat message, GitHub recommends short,
self-contained statements that apply to most requests. The file of the demo
project starts with how to build and test:

```text
## Build and test

- Use `./build.ps1` as the only entry point for all build, test, and environment setup operations.
- Never invoke `Build-Module`, `Invoke-Pester`, or `Invoke-Build` directly.
- Never manually prepend anything to `PSModulePath`.
- Standard commands:
  - Bootstrap dependencies: `./build.ps1 -ResolveDependency -Tasks noop`
  - Build: `./build.ps1 -Tasks build`
  - Focused test: `./build.ps1 -Tasks test -PesterPath 'tests/Unit/Public/MyFunction.Tests.ps1' -CodeCoverageThreshold 0`
  - Full test suite: `./build.ps1 -Tasks test`
  - Quality gate: `./build.ps1 -Tasks hqrmtest`
```

These rules name exact commands instead of saying "run the tests", so
Copilot uses the same entry point as you and the pipeline, see
[CI/CD with GitHub Actions](16-cicd-with-github-actions.md). The rest of the
file covers Git, the repository structure, the instruction files of each
area, the changelog, the PowerShell style, and long-running commands, in
fewer than 70 lines. To see whether Copilot used the file, expand the
**References** of a response in the Chat view:
`.github/copilot-instructions.md` is listed there when it was included.

## Path-specific instructions

*Path-specific custom instructions* apply only to requests made in the
context of files that match a path. They live in files named
`NAME.instructions.md` in or below the folder `.github/instructions`. The
`applyTo` key of the front matter holds one or more *glob patterns*,
separated by commas and relative to the root of the repository: `*` stands
for any characters within a name, and `**` as a path segment of its own for
any number of folders. The demo project's rules for public functions start
like this:

```text
---
description: 'Public function authoring instructions'
applyTo: 'source/Public/**/*.ps1'
---

# Public Function Development Guidelines

Public functions are user-facing and are the most critical API surface of FileManagementSample.

## Baseline structure (same as private functions)

- Use comment-based help with at least:
  - `.SYNOPSIS`
  - `.DESCRIPTION`
  - one `.EXAMPLE`
  - `.PARAMETER` help for every parameter.
- Use `[CmdletBinding()]` and include `[OutputType(...)]`.
```

When Copilot works on `source/Public/Get-LargestFile.ps1`, it receives these
rules and the repository-wide instructions: if both apply, both are used.
Thanks to `**`, the pattern also covers files in subfolders of
`source/Public`. The demo project has eight such files, one per area, for
example:

| File                                | `applyTo`                                                                              |
|-------------------------------------|----------------------------------------------------------------------------------------|
| `public-functions.instructions.md`  | `source/Public/**/*.ps1`                                                               |
| `private-functions.instructions.md` | `source/Private/**/*.ps1`                                                              |
| `build-tasks.instructions.md`       | `{build.ps1,build.yaml,.build/*.ps1,.github/workflows/*.yml,.github/workflows/*.yaml}` |

> [!IMPORTANT]
> Where path-specific instructions apply depends on the Copilot feature. The
> GitHub Docs say: "Currently, on GitHub.com, path-specific custom
> instructions are only supported for Copilot cloud agent and Copilot code
> review." Copilot Chat in VS Code supports them, too.

## Skills

A *skill* is a folder with a `SKILL.md` file and, if needed, scripts and
other resources: a procedure that Copilot loads when a task needs it. Agent
Skills are an open standard, and Copilot looks for project skills in
`.github/skills`. The YAML front matter of `SKILL.md` needs two keys:

- **`name`**: lowercase letters, numbers, and hyphens, at most 64
  characters. It must match the name of the folder; a name with invalid
  characters makes the skill silently fail to load.
- **`description`**: what the skill does *and when to use it*, at most
  1,024 characters. Copilot decides from this text whether a skill fits.

This is the front matter of the demo project's `validate-changes` skill:

```yaml
---
name: validate-changes
description: Run targeted test scopes to validate changes quickly and safely, then run the full test suite when needed for confidence before PRs.
argument-hint: What files or areas did you change, and how much validation do you want?
---
```

The optional `argument-hint` appears in the chat input when you start the
skill as a slash command, `/validate-changes`. The body of the file is the
procedure itself:

```text
## Use this skill when

- You changed PowerShell functions under `source/Public` or `source/Private`.
- You changed PowerShell classes and enums under `source/Classes` or `source/Enum`.
- You changed build logic under `.build/tasks` or `build.yaml`.
- You need a confidence check before opening or updating a PR.
```

Its decision flow runs the smallest useful test scope first, a single test
file, and the full suite with `./build.ps1 -Tasks test` before a pull
request. Copilot loads a skill in three levels: it reads only `name` and
`description` of every skill, loads the body when your request matches the
description or when you type the slash command, and opens other files of the
folder only when the body refers to them. That's the difference from
instructions: instructions are always applied, or by file pattern; a skill
is loaded on demand, so you can have many without filling the context.

## The Memory Bank

The Memory Bank keeps project knowledge in Markdown that outlasts a chat
session: files under `.memory-bank` for the project brief, the product and
technical context, the system patterns and decisions, the current focus, and
the progress. The demo project recorded this as its first decision, with the
rationale "Preserve evidence-backed context across sessions."

`index.md` is the entry point. It starts with "Read this file first. It
routes tasks to the smallest relevant set of Memory Bank files." Its first
five routes map tasks to files:

```text
| Route | Task signals | Read |
|---|---|---|
| `general` | General Q&A with no project decision | Index only |
| `continuation` | Resume, current focus, next step | `activeContext.md`, `progress.md` |
| `scope` | Purpose, scope, requirements, Acceptance criteria | `projectbrief.md` |
| `product` | Users, problem, workflow, experience goal | `productContext.md` |
| `implementation` | Code, configuration, build, test, dependency, deployment | `techContext.md`, `activeContext.md` |
```

The index also sets an authority order, which ends with "Historical logs
never override current source." When the code and a Memory Bank file
disagree, the code wins.

> [!NOTE]
> The Memory Bank is a convention, not a Copilot feature. Copilot discovers
> instructions in `.github/copilot-instructions.md`, `AGENTS.md`, and
> `.github/instructions`, not in `.memory-bank`. Ask Copilot to read
> `.memory-bank/index.md` first, and check in the response that it did.

## Review generated code before you accept it

GitHub puts it plainly: Copilot can make mistakes, "and you should always
validate the code it suggests". The VS Code documentation adds that
instructions "don't guarantee compliance or replace tests, code review, or
security controls." Working code is not enough. Save this function as
`Get-LogErrors.ps1` in the root of this repository and try it on the sample
folder:

```powershell
function Get-LogErrors {
    param ($Path)
    gci $Path -Recurse -Filter *.log | % { sls -Path $_.FullName -Pattern 'ERROR' }
}
```

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
. ./Get-LogErrors.ps1
(Get-LogErrors -Path $root).Count
Invoke-ScriptAnalyzer -Path ./Get-LogErrors.ps1 | Select-Object -Property RuleName, Line, Severity
```

```text
144

RuleName                  Line Severity
--------                  ---- --------
PSAvoidUsingCmdletAliases    3  Warning
PSAvoidUsingCmdletAliases    3  Warning
PSAvoidUsingCmdletAliases    3  Warning
PSUseSingularNouns           1  Warning
```

The function finds all 144 error lines of the sample logs, and it still
triggers four warnings from two rules: three aliases, `gci`, `%`, and `sls`,
and a plural noun. It has no help, no parameter type, and no
`[CmdletBinding()]` either, all of which the demo project's instructions
require. In the demo project, you don't have to remember these checks: its
quality tests fail the build when a public function fails PSScriptAnalyzer
or lacks help, see [Testing with Pester](14-testing-with-pester.md). Before
you accept a change, go through it like a colleague's pull request:

1. **Read it.** Ask Copilot to explain any line you don't understand.
2. **Run the focused tests,** then the whole build with `./build.ps1`, which
   builds the module before it runs all tests.
3. **Check the diff.** Did Copilot change only the files you expected?

## Leave Git operations to the user

The repository-wide instructions of the demo project end their Git section
with two rules:

```text
## Git workflow

- Never commit, push, tag, or publish on behalf of the user.
- Leave all Git operations to the user.
```

There are good reasons for them:

- **The review comes before the commit.** A commit records the change under
  your name. The checks above belong before that moment, not after it.
- **Git operations start the pipeline.** In the demo project, a push to
  `main` or a version tag such as `v1.0.0` runs the deploy job. With the
  tokens configured, it publishes the module to the PowerShell Gallery, for
  everyone.
- **You stay in control of shared state.** Copilot can propose a commit
  message or a command. You decide whether and when to run it.

## Common pitfalls

- **Vague or contradicting instructions.** "Write good tests" tells Copilot
  nothing; "Wrap pipeline results in `@()` before you use `.Count`" does.
  In VS Code, Copilot combines user and repository instructions without a
  general precedence order, so a personal rule that contradicts a repository
  rule makes the result unpredictable. Remove the conflict instead of adding
  a third rule.
- **Very long instruction files.** GitHub's guide for Copilot code review
  warns that "very long instruction files may result in some instructions
  being overlooked" and suggests about 1,000 lines per file at most. Keep the
  repository-wide file short, and move area rules into path-specific files,
  as the demo project does.
- **Accepting code without running the tests.** Copilot may generate code
  that "appears valid but is not semantically or syntactically correct".
  Run the tests and the build before you accept a change, and make sure a
  test would notice the mistake, as in Exercise 3.
- **Secrets in prompts.** Copilot sends your prompt, together with context
  such as open files and the chat history, to a language model. Never paste
  a password or an API key into a prompt, close files that contain secrets,
  and write placeholders such as `$env:GalleryApiToken` instead.

## Exercises

The exercises run in VS Code with GitHub Copilot Chat and use the `samples`
folder of this repository; the solutions are model answers, so Copilot's
answers to you will differ.

### Exercise 1: Rules for test files

1. Create `.github/instructions/pester-tests.instructions.md` for all
   `*.Tests.ps1` files, at any depth.
2. Add four to six rules that Copilot can follow without asking.
3. Open a test file, ask Copilot Chat for a new test, and check the
   **References** of the response.

<details>
<summary>Solution</summary>

```text
---
description: 'Pester test conventions'
applyTo: '**/*.Tests.ps1'
---

# Pester tests

- Use Pester 5 syntax: `BeforeAll`, `Describe`, `Context`, `It`, and `Should`.
- Start every `It` name with `Should`, for example `It 'Should return the largest file'`.
- Create test data in `$TestDrive`; never use fixed paths such as `C:\Temp`.
- Wrap pipeline results in `@()` before you use `.Count`, so the tests also pass in Windows PowerShell 5.1.
- Use `Should -BeExactly` when the case of a string matters; `Should -Be` ignores case.
- After a change, run `Invoke-Pester -Path <test file> -Output Detailed`.
```

`**/*.Tests.ps1` matches test files in all folders, because `**` is a path
segment of its own. Inside a name, as in `tests/**.Tests.ps1`, it acts like
`*` and matches only files directly in `tests`. A YAML error in the front
matter can keep the file from being applied, so check that it parses:

```powershell
$text = Get-Content -Path ./.github/instructions/pester-tests.instructions.md -Raw
($text -split '(?m)^---\s*$')[1] | ConvertFrom-Yaml -Ordered
```

```text
Name                           Value
----                           -----
description                    Pester test conventions
applyTo                        **/*.Tests.ps1
```

When Copilot works on a test file, check that this file appears in the
**References** of the response.

</details>

### Exercise 2: Sketch a skill

1. Pick a task you repeat, such as adding a public function to the demo
   project.
2. Create the folder of the skill under `.github/skills` and write its
   `SKILL.md`: the front matter, when to use it, and the steps.
3. Check that `name` matches the folder.

<details>
<summary>Solution</summary>

Create the folder `.github/skills/add-public-function` with this `SKILL.md`:

```text
---
name: add-public-function
description: Add a public function to the FileManagementSample module, with help, a unit test, and a changelog entry. Use when asked to create a new public command.
---

# Add a public function

1. Read `.github/instructions/public-functions.instructions.md`.
2. Create `source/Public/<Verb>-<Noun>.ps1` with comment-based help, `[CmdletBinding()]`, and `[OutputType()]`.
3. Create `tests/Unit/Public/<Verb>-<Noun>.Tests.ps1`; test the happy path and invalid input.
4. Add an entry under `## [Unreleased]` in `CHANGELOG.md`.
5. Build and run the new test: `./build.ps1 -Tasks build, test -PesterPath 'tests/Unit/Public/<Verb>-<Noun>.Tests.ps1' -CodeCoverageThreshold 0`.
6. Run the whole build with `./build.ps1`.
7. Report what passed and what failed. Leave all Git operations to the user.
```

```powershell
$folder = Get-Item -Path ./.github/skills/add-public-function
$text = Get-Content -Path (Join-Path -Path $folder.FullName -ChildPath 'SKILL.md') -Raw
$frontMatter = ($text -split '(?m)^---\s*$')[1] | ConvertFrom-Yaml
$frontMatter.name -ceq $folder.Name
$frontMatter.description.Length
```

```text
True
151
```

The description says what the skill does and when to use it, well below the
limit of 1,024 characters. The steps reuse the rules of the demo project
instead of repeating them, and the last step keeps Git with you.

</details>

### Exercise 3: Review a generated test

1. Save the function `Get-FileExtensionSize` from
   [Your first function](09-your-first-function.md) as
   `Get-FileExtensionSize.ps1` in the root of this repository.
2. Ask Copilot Chat for a test:

   ```text
   Write a Pester 5 test for Get-FileExtensionSize in Get-FileExtensionSize.ps1.
   Create the test data with ./samples/New-WorkshopFolder.ps1 in $TestDrive.
   ```

3. Review the test with a checklist, run it, and then break the function on
   purpose: remove `-Descending` from `Sort-Object`.

<details>
<summary>Solution</summary>

A review checklist for a generated test:

- Does the test run, and does it fail when the function is wrong?
- Do the expected values come from the data, such as the file counts in
  `samples/README.md`, and not from the code under test?
- Does it use only `$TestDrive` and the sample folder, with no fixed paths?
- Does each `It` check one behavior, and does one of them try invalid input?

A test that passes the checklist:

```powershell
BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    $folderPath = Join-Path -Path $TestDrive -ChildPath 'WorkshopFiles'
    $root = & "$PSScriptRoot/samples/New-WorkshopFolder.ps1" -Path $folderPath
}

Describe 'Get-FileExtensionSize' {
    It 'Should rank the extensions by number of files' {
        $result = Get-FileExtensionSize -Path $root -Top 4

        $result.Extension | Should -Be @('.log', '.txt', '.json', '.ps1')
        $result.FileCount | Should -Be @(6, 5, 4, 3)
    }

    It 'Should return the total size in gigabytes' {
        $result = Get-FileExtensionSize -Path $root -Top 1

        $result.TotalFileSize | Should -Be (181290 / 1GB)
    }

    It 'Should return only the requested number of extensions' {
        @(Get-FileExtensionSize -Path $root -Top 2).Count | Should -Be 2
    }

    It 'Should throw when Top is not a number' {
        { Get-FileExtensionSize -Path $root -Top 'many' } | Should -Throw
    }
}
```

```powershell
$result = Invoke-Pester -Path ./Get-FileExtensionSize.Tests.ps1 -Output None -PassThru
$result | Select-Object -Property Result, PassedCount, FailedCount
```

```text
Result PassedCount FailedCount
------ ----------- -----------
Passed           4           0
```

Without `-Descending`, the same command reports the broken function:

```text
Result PassedCount FailedCount
------ ----------- -----------
Failed           2           2
```

Both tests that depend on the sort order fail, so the test protects it. One
detail is worth a second look: the function names the text group `.TXT`,
after the first file it finds, `notes.TXT`. The test passes anyway, because
`Should -Be` ignores case. If the case matters to you, use
`Should -BeExactly`.

</details>

## Key takeaways

- `.github/copilot-instructions.md` reaches every request in the repository;
  keep it short, concrete, and focused on commands and conventions.
- Path-specific `*.instructions.md` files use `applyTo` globs to add rules
  for an area, such as public functions or tests.
- A skill is a folder with a `SKILL.md` whose `name` and `description`
  decide when Copilot loads the procedure.
- The Memory Bank keeps project knowledge across sessions, but Copilot reads
  it only when asked, and the source code always wins.
- Review generated code like a colleague's: read it, run the tests,
  PSScriptAnalyzer, and the build, and then commit it yourself.

## Learn more

- [GitHub Copilot documentation](https://docs.github.com/copilot)
- [Adding repository custom instructions for GitHub Copilot](https://docs.github.com/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)
- [Adding repository custom instructions in your IDE](https://docs.github.com/copilot/how-tos/copilot-in-your-ide/customize-copilot/configure-custom-instructions/add-repository-instructions-in-your-ide)
- [Support for different types of custom instructions](https://docs.github.com/copilot/reference/custom-instructions-support)
- [Use custom instructions in VS Code](https://code.visualstudio.com/docs/agent-customization/custom-instructions)
- [Agent skills in VS Code](https://code.visualstudio.com/docs/agent-customization/agent-skills)
- [Best practices for using GitHub Copilot](https://docs.github.com/copilot/get-started/best-practices)
- [Using custom instructions for Copilot code review](https://docs.github.com/copilot/tutorials/customize-code-review)
- [Application card: GitHub Copilot Chat](https://docs.github.com/copilot/responsible-use/chat)
- [PSScriptAnalyzer](https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/overview)

---

[← Previous: CI/CD with GitHub Actions](16-cicd-with-github-actions.md)
· [Overview](../README.md)
