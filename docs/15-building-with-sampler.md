# Building with Sampler

[Overview](../README.md) › Part 3: Engineering practices › Topic 15 of 17

A build turns the source files into the module that you ship, and it tests the
module before anyone else sees it. Sampler runs the whole build from one
script, the same way on your machine and on a CI runner. This topic explains
how to read and change the build of the demo project and of the module
`WorkshopTools`.

In this topic, you learn to:

- read the workflows in `build.yaml` and run them with `build.ps1`
- explain how the build enforces tests and code coverage
- add a custom task with Invoke-Build syntax
- find the results of a build in `output/`
- run a single test file through the build

## Workflows in build.yaml

Sampler is a template and build framework for PowerShell modules. Its
`build.yaml` defines *workflows*: named lists of tasks, much like the stages
and jobs of Azure DevOps or GitHub Actions. The difference is that
`build.ps1` runs the same way on your machine, so you can debug every step of
the build locally.

![Your machine and the CI runner both call build.ps1, which reads build.yaml
and runs the build and test workflows](../assets/diagrams/sampler-build.svg)

An excerpt from the `build.yaml` of the demo project:

```yaml
BuildWorkflow:
  '.': # "." is the default Invoke-Build workflow. It is called when no -Tasks is specified to the build.ps1
    - build
    - test

  build:
    - Clean
    - Task1
    - Build_Module_ModuleBuilder
    - Build_NestedModules_ModuleBuilder
    - Create_changelog_release_output

  test:
    - Pester_Tests_Stop_On_Fail
    - Pester_if_Code_Coverage_Under_Threshold

  publish:
    - Publish_Release_To_GitHub # Runs first, if token is expired it will fail early
    - Publish_GitHub_Wiki_Content
    - publish_module_to_gallery
```

An entry in a workflow is either a task or another workflow: the default
workflow `.` runs the workflows `build` and `test`, in this order.
`./build.ps1` without `-Tasks` runs `.`, and `./build.ps1 -Tasks build` runs
only the workflow `build`. When the build starts, `build.ps1` turns every
workflow into an Invoke-Build task, so `-Tasks` accepts workflows and single
tasks alike.

## Where the tasks come from

The tasks in the workflows come from three places:

1. **Modules listed under `ModuleBuildTasks`.** `build.ps1` imports each
   module and loads the task files that the module exports under a name that
   matches the pattern. A module that provides tasks must also be listed in
   `RequiredModules.psd1`. This is the section in a new Sampler project:

   ```yaml
   ModuleBuildTasks:
     Sampler:
       - '*.build.Sampler.ib.tasks'
     Sampler.GitHubTasks:
       - '*.ib.tasks'
   ```

2. **Files in the folder `.build`.** `build.ps1` loads every `.ps1` file in
   `.build` and its subfolders. A task there replaces an imported task with
   the same name.
3. **`build.ps1` itself.** It defines `noop`, an empty task that is useful to
   test the bootstrap: `./build.ps1 -ResolveDependency -Tasks noop` downloads
   the dependencies and builds nothing.

## Tests and code coverage in the build

The build enforces the tests:

- `Pester_Tests_Stop_On_Fail` stops the build as soon as one test fails.
- `Pester_if_Code_Coverage_Under_Threshold` fails the build when the code
  coverage is below `CoveragePercentTarget` in `build.yaml`. The demo project
  sets it to `0`, which turns the check off.

The section `Pester` in `build.yaml` configures the test run. Its keys follow
the Pester configuration object from
[Testing with Pester](14-testing-with-pester.md):

| Key under `Pester.Configuration`     | What it controls                                                           |
|--------------------------------------|----------------------------------------------------------------------------|
| `Run.Path`                           | The test files or folders; when it's empty, all tests under `tests` run    |
| `Output.Verbosity`                   | How much Pester prints; `Detailed` prints one line per test                |
| `Filter.Tag`, `Filter.ExcludeTag`    | Runs or skips tests by tag, such as the quality tests tagged `helpQuality` |
| `CodeCoverage.CoveragePercentTarget` | The minimum code coverage in percent; `0` turns the check off              |
| `TestResult.OutputFormat`            | The format of the result file in `output/testResults`, such as `NUnitXML`  |

The parameter `-CodeCoverageThreshold` of `build.ps1` overrides
`CoveragePercentTarget` for one run. With a threshold, the build measures the
coverage of the built module and prints the result. For `WorkshopTools`:

```powershell
./build.ps1 -Tasks test -CodeCoverageThreshold 90
```

Among the output of the last task is this line:
`Code Coverage SUCCESS with value of 100 % (threshold 90 %)`. Below the
threshold, the task fails the build.

## Custom tasks

Tasks are Invoke-Build tasks, so adding your own step is easy. `Task1` in the
`build` workflow is a custom task from `.build/Task1.ps1`:

```powershell
task Task1 {
    Get-Date
}
```

A task is the command `task`, a name, and a script block. Three more things
make a custom task useful:

- A comment `# Synopsis:` in the line above `task` describes the task.
  `./build.ps1 -Tasks ?` lists every task with its synopsis and its jobs,
  without running anything.
- Instead of a script block, a task can list other tasks as its *jobs*. Sampler
  defines `CleanAll` this way:

  ```powershell
  task CleanAll Clean, CleanModule
  ```

- Inside a task, `. Set-SamplerTaskVariable` sets the variables that Sampler's
  own tasks use, such as `$ProjectName`, `$ModuleVersion`, and
  `$OutputDirectory`, and `Write-Build` prints colored text. Invoke-Build sets
  `$BuildRoot` to the root of the project.

A task runs only when a workflow lists it, or when you name it with `-Tasks`.
Add it to a workflow in `build.yaml` to make it part of every build.

## Dependencies: RequiredModules.psd1

`RequiredModules.psd1` lists the modules that the build needs. In a new
project, it asks for the latest version of each:

```powershell
@{
    InvokeBuild                 = 'latest'
    PSScriptAnalyzer            = 'latest'
    Pester                      = 'latest'
    ModuleBuilder               = 'latest'
    ChangelogManagement         = 'latest'
    Sampler                     = 'latest'
    'Sampler.GitHubTasks'       = 'latest'
}
```

`./build.ps1 -ResolveDependency` runs `Resolve-Dependency.ps1`, which saves
these modules and their dependencies into `output/RequiredModules`. Its
settings live in `Resolve-Dependency.psd1`: in a new project, it downloads
from `PSGallery` with PSResourceGet (`UsePSResourceGet = $true`). The comments
in that file also show how to use an internal feed.

`latest` means: the newest version at the time you resolve. In the build of
`WorkshopTools`, that was Pester 6.2.0. To keep every machine on the same
version, replace `'latest'` with a version, such as `'6.2.0'`. For each run,
`build.ps1` puts `output/RequiredModules` at the front of `$env:PSModulePath`
of the current session, so the build always uses these copies.

## The output folder

After `./build.ps1`, the folder `output` of `WorkshopTools` contains:

```text
output/
├── module/
│   └── WorkshopTools/
│       └── 0.0.1/
│           ├── en-US/
│           │   └── about_WorkshopTools.help.txt
│           ├── WorkshopTools.psd1
│           └── WorkshopTools.psm1
├── RequiredModules/
├── testResults/
│   ├── NUnitXml_WorkshopTools_v0.0.1.Windows.PSv.7.6.10.xml
│   └── PesterObject_WorkshopTools_v0.0.1.Windows.PSv.7.6.10.xml
├── CHANGELOG.md
└── ReleaseNotes.md
```

- `module/` holds the built module. ModuleBuilder merges all files from
  `source/Private` and `source/Public` into `WorkshopTools.psm1`, and writes
  the public functions into `FunctionsToExport` of the manifest. `en-US`
  comes from `CopyPaths` in `build.yaml`.
- `RequiredModules/` holds the build dependencies.
- `testResults/` holds the test results. The CI pipelines collect the NUnit
  XML files to report the test results of a run.
- `ReleaseNotes.md` and `CHANGELOG.md` come from the task
  `Create_changelog_release_output`. It turns the section `Unreleased` of the
  change log into release notes for the version, here `## [0.0.1]` with the
  date of the build.

The merged `.psm1` file marks where each function comes from:

```powershell
Select-String -Path ./output/module/WorkshopTools/0.0.1/WorkshopTools.psm1 -Pattern '^#Region' |
    ForEach-Object { $_.Line }
```

```text
#Region '.\Private\Get-PrivateFunction.ps1' -1
#Region '.\Public\Get-FileExtensionSize.ps1' -1
#Region '.\Public\Get-Something.ps1' -1
```

## Versioning with GitVersion

Sampler takes the version of a new build from the first source that has one:
the variable or environment variable `ModuleVersion`, the key `SemVer` in
`build.yaml`, GitVersion, and finally the manifest in `source/`. Tasks that
run after the build read the version from the built manifest instead.

GitVersion calculates a semantic version from the Git history. The rules are
in `GitVersion.yml`; these lines decide which part of the version grows:

```yaml
next-version: 0.0.1
major-version-bump-message: '(breaking\schange|breaking|major)\b'
minor-version-bump-message: '(adds?|features?|minor)\b'
patch-version-bump-message: '\s?(fix|patch)'
no-bump-message: '\+semver:\s?(none|skip)'
```

`next-version` is the base version. A commit message that contains
*breaking change* raises the major version, *adds* or *feature* the minor
version, and *fix* the patch version. A tag such as `v1.0.0` on a commit sets
the version of that commit. Builds from `main` get the pre-release label
`preview` until you tag a release.

On the CI runner, the pipeline runs GitVersion first and passes the result to
`build.ps1` in the environment variable `ModuleVersion`, see
[CI/CD with GitHub Actions](16-cicd-with-github-actions.md).

## Run one test file through the build

The full test run takes a while in a large project. The instructions for
GitHub Copilot in the demo project show how to run a single test file through
the build:

```powershell
./build.ps1 -Tasks test -PesterPath 'tests/Unit/Public/Get-FileExtensionSize.tests.ps1' -CodeCoverageThreshold 0
```

`-PesterPath` replaces `Run.Path` from `build.yaml` for this run.
`-CodeCoverageThreshold 0` turns off the coverage check, because one test file
can't cover the whole module. For `WorkshopTools`, the summary shows only the
selected file:

```text
Test Script File                 Duration Result Passed Failed Skipped Total
----------------                 -------- ------ ------ ------ ------- -----
Get-FileExtensionSize.tests.ps1 0 seconds Passed      2      0       0     2
```

## Build commands

These are the commands for the demo project. In a new project, `pack` builds
and packages the module without generating help.

| Command                                      | What it does                                                    |
|----------------------------------------------|-----------------------------------------------------------------|
| `./build.ps1 -ResolveDependency -Tasks noop` | Downloads the build dependencies into `output/RequiredModules`  |
| `./build.ps1`                                | Runs the default workflow: build the module, then run all tests |
| `./build.ps1 -Tasks build`                   | Builds the module without running tests                         |
| `./build.ps1 -Tasks test`                    | Runs the tests against the last build                           |
| `./build.ps1 -Tasks pack`                    | Builds the module, generates the help, and creates the package  |

> [!TIP]
> To debug the build, set a breakpoint in a test or in a function, start the
> *PowerShell Interactive Session* launch configuration, and run
> `./build.ps1 -Tasks test` in the PowerShell Extension Terminal. This launch
> configuration debugs every command you run in that terminal.

## Common pitfalls

- **Files in `output/`.** The task `Clean` at the start of every build deletes
  everything in `output/` except the folders `RequiredModules` and `agentic`.
  Write logs and notes to `output/agentic`, as the instructions of the demo
  project do, or outside the project.
- **Calling `Invoke-Pester` directly.** Without the build, the tests run with
  whatever Pester comes first in your module path, and nothing is built or
  on the module path. On a machine with Pester 5.7.1 installed, a direct
  `Invoke-Pester -Path ./tests` in `WorkshopTools` ran Pester 5.7.1 instead of
  6.2.0, the quality tests failed during discovery with "The term
  'Get-SamplerProjectName' is not recognized as a name of a cmdlet, function,
  script file, or executable program.", and a unit test failed with "The
  specified module 'WorkshopTools' was not loaded because no valid module
  file was found in any module directory." Always test through `build.ps1`.
- **Testing an old build.** `./build.ps1 -Tasks test` tests the module in
  `output/module`, not your source files. After a change in `source/`, run
  `./build.ps1`, which builds first.

## Exercises

The exercises use the project `WorkshopTools` from
[Scaffolding a module with Sampler](13-scaffolding-a-module-with-sampler.md),
with the function `Get-FileExtensionSize` and its test.

### Exercise 1: A custom task that prints the module version

1. Write a task `Show_ModuleVersion` in `.build/Show_ModuleVersion.build.ps1`
   that prints the name and the version of the built module, with a synopsis.
2. Add it to the end of the workflow `build` and run `./build.ps1 -Tasks build`.

<details>
<summary>Solution</summary>

```powershell
# Synopsis: Prints the name and the version of the built module.
task Show_ModuleVersion {
    # Get the values for task variables, see https://github.com/gaelcolas/Sampler?tab=readme-ov-file#build-task-variables.
    . Set-SamplerTaskVariable

    Write-Build -Color Green -Text "Built $ProjectName $ModuleVersion"
}
```

```yaml
  build:
    - Clean
    - Build_Module_ModuleBuilder
    - Build_NestedModules_ModuleBuilder
    - Create_changelog_release_output
    - Show_ModuleVersion
```

Among the task variables, the task prints `Built WorkshopTools 0.0.1`. The
build then reports `Done /build/Show_ModuleVersion` and finally
`Build succeeded. 8 tasks, 0 errors, 0 warnings` with the duration. Without
`-AsNewBuild`, `Set-SamplerTaskVariable` reads the version from the built
manifest, so the task belongs after `Build_Module_ModuleBuilder`. Once the
module is built, `./build.ps1 -Tasks Show_ModuleVersion` runs the task alone.

</details>

### Exercise 2: A focused test run

Run only the tests of `Get-FileExtensionSize` through the build, without the
quality tests and without the coverage check.

<details>
<summary>Solution</summary>

```powershell
./build.ps1 -Tasks test -PesterPath 'tests/Unit/Public/Get-FileExtensionSize.tests.ps1' -CodeCoverageThreshold 0
```

```text
Test Script File                 Duration Result Passed Failed Skipped Total
----------------                 -------- ------ ------ ------ ------- -----
Get-FileExtensionSize.tests.ps1 0 seconds Passed      2      0       0     2
```

The run uses the last build. If you changed the function since, run
`./build.ps1 -Tasks build` first.

</details>

### Exercise 3: Read the default workflow

Which tasks does `./build.ps1` run, and in which order? Answer from
`build.yaml`, then check the answer with `./build.ps1 -Tasks ?`.

<details>
<summary>Solution</summary>

`?` returns one object per task. `6>$null` hides the messages of `build.ps1`,
and the rest of the pipeline picks the three workflows:

```powershell
./build.ps1 -Tasks ? 6>$null |
    Where-Object -Property Name -In '.', 'build', 'test' |
    Sort-Object -Property Name |
    ForEach-Object { '{0,-5} {1}' -f $_.Name, ($_.Jobs -join ', ') }
```

```text
.     build, test
build Clean, Build_Module_ModuleBuilder, Build_NestedModules_ModuleBuilder, Create_changelog_release_output
test  Pester_Tests_Stop_On_Fail, Pester_if_Code_Coverage_Under_Threshold
```

`./build.ps1` runs `.`, which runs `build` and then `test`. Before you added
`Show_ModuleVersion`, that is `Clean`, `Build_Module_ModuleBuilder`,
`Build_NestedModules_ModuleBuilder`, `Create_changelog_release_output`,
`Pester_Tests_Stop_On_Fail`, and `Pester_if_Code_Coverage_Under_Threshold`.

</details>

## Key takeaways

- `build.yaml` defines workflows; `./build.ps1 -Tasks <name>` runs a workflow
  or a single task, and `?` lists them all.
- The build stops on a failed test and, with a threshold, on too little code
  coverage.
- Custom tasks are Invoke-Build tasks in `.build/`; add them to a workflow to
  run them in every build.
- The build tools live in `output/RequiredModules`, the built module in
  `output/module`, and the `Clean` task empties `output/` on every build.
- Run tests through `build.ps1`, also for a single test file.

## Learn more

- [Sampler](https://github.com/gaelcolas/Sampler)
- [Invoke-Build](https://github.com/nightroman/Invoke-Build)
- [ModuleBuilder](https://github.com/PoshCode/ModuleBuilder)
- [GitVersion](https://gitversion.net/)
- [GitVersion: version incrementing](https://gitversion.net/docs/reference/version-increments)

---

[← Previous: Testing with Pester](14-testing-with-pester.md)
· [Overview](../README.md) ·
[Next: CI/CD with GitHub Actions →](16-cicd-with-github-actions.md)
