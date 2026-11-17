# Scaffolding a module with Sampler

[Overview](../README.md) › Part 3: Engineering practices › Topic 13 of 17

A function in a script file is a good start, but a module is how PowerShell
shares, versions, and loads code. Sampler creates a complete module project
with one command: source folders, tests, a build script, and a CI pipeline.
This topic turns the workshop function into the module `WorkshopTools`, which
the next two topics test and build.

In this topic, you learn to:

- explain what a module project adds to a script file
- choose a module type and scaffold a project with `New-SampleModule`
- find your way around the files that Sampler creates
- add a function and its test to the project
- build the module and import it from `output/module`

## From a function to a module

A *module* is a self-contained, reusable unit of functions and other
resources. `Import-Module` loads it, and PowerShell loads an installed module
automatically the first time you use one of its commands. The *module
manifest*, a `.psd1` file, describes the module: its version, its author, and
the commands it exports.

In a Sampler project, you never edit the module that you ship. You write one
file per function in `source/`, and `build.ps1` merges them into one `.psm1`
file in `output/module`, writes the public functions into the manifest, and
tests the result:

![Add-Sample puts a function into source/Public; build.ps1 turns source/ into
output/module/WorkshopTools/0.0.1 for Import-Module](../assets/diagrams/13-function-to-module.svg)

Sampler is a template and build framework for PowerShell modules. It creates
its files with *Plaster*, a template-based file and project generator, and it
builds with Invoke-Build and ModuleBuilder, which
[Building with Sampler](15-building-with-sampler.md) explains.

## Install Sampler

Install Sampler from the PowerShell Gallery for the current user. Plaster
comes with it as a dependency:

```powershell
Install-Module -Name Sampler -Scope CurrentUser
```

The examples on this page use Sampler 0.120.1. You need the installed module
only to create projects and add code to them. Each project downloads its own
copy of Sampler and the other build tools into `output/RequiredModules`.

## Choose a module type

`New-SampleModule` creates a project from one of five module types. The
parameter `-ModuleType` selects one; without it, you get `SimpleModule`.

| Module type            | What you get                                                                                       |
|------------------------|----------------------------------------------------------------------------------------------------|
| `SimpleModule`         | A module with a minimal structure and the build automation: build, test, and publish (default)     |
| `SimpleModule_NoBuild` | A simple module without the build automation                                                       |
| `CompleteSample`       | A module with the complete structure and example files                                             |
| `dsccommunity`         | A DSC module that follows the DSC Community baseline, with a pipeline for build, test, and release |
| `CustomModule`         | Asks which features you want; with the parameter `-Features`, it asks nothing                      |

For a first module, choose `SimpleModule`. It brings the complete build
pipeline but only one sample public function, one sample private function, and
their tests. You can read all of it in a few minutes.

## Scaffold the project

Change to the folder where you keep your projects and run
`New-SampleModule`. [Splatting](11-splatting.md) keeps the parameters
readable:

```powershell
$moduleParameters = @{
    DestinationPath   = '.'
    ModuleType        = 'SimpleModule'
    ModuleName        = 'WorkshopTools'
    ModuleAuthor      = 'Workshop Participant'
    ModuleDescription = 'Tools from the PowerShell workshop'
    GitHubOwner       = 'my-github-account'
}
New-SampleModule @moduleParameters
```

`New-SampleModule` creates the project in a new subfolder named after the
module, `WorkshopTools`. `GitHubOwner` names the GitHub account or
organization that will publish the module; with the parameter, Sampler
doesn't ask for it.

`SimpleModule` then asks up to six yes-or-no questions. Each answer decides
whether you get an optional file:

| Question about     | Answer here | A yes adds                                                                          |
|--------------------|-------------|-------------------------------------------------------------------------------------|
| Git                | Yes         | `.gitignore` and `.gitattributes`; the next three questions appear only after a yes |
| GitVersion         | Yes         | `GitVersion.yml`, the rules for automatic version numbers                           |
| Codecov.io         | No          | `codecov.yml`, for the code coverage service Codecov.io                             |
| GitHub.com         | Yes         | The release task `Publish_Release_To_GitHub` and the module `Sampler.GitHubTasks`   |
| Azure Pipelines    | Yes         | `azure-pipelines.yml`, a CI pipeline for Azure DevOps                               |
| Visual Studio Code | Yes         | `.vscode/tasks.json` with the tasks `build` and `test`                              |

> [!TIP]
> To scaffold without questions, for example in a script, use the module type
> `CustomModule` and list the features you want. This command creates the
> build files, the quality tests, and the Git, GitVersion, and VS Code files,
> but no sample functions:
>
> ```powershell
> $moduleParameters = @{
>     DestinationPath   = '.'
>     ModuleType        = 'CustomModule'
>     ModuleName        = 'WorkshopTools'
>     ModuleAuthor      = 'Workshop Participant'
>     ModuleDescription = 'Tools from the PowerShell workshop'
>     Features          = 'Build', 'UnitTests', 'ModuleQuality', 'git', 'gitversion', 'vscode'
> }
> New-SampleModule @moduleParameters
> ```

## What Sampler created

With the answers from the table, the project looks like this:

```text
WorkshopTools/
├── .vscode/
│   └── tasks.json
├── output/
│   └── RequiredModules/
├── source/
│   ├── en-US/
│   │   └── about_WorkshopTools.help.txt
│   ├── Private/
│   │   └── Get-PrivateFunction.ps1
│   ├── Public/
│   │   └── Get-Something.ps1
│   ├── WorkshopTools.psd1
│   └── WorkshopTools.psm1
├── tests/
│   ├── QA/
│   │   └── module.tests.ps1
│   └── Unit/
│       ├── Private/
│       │   └── Get-PrivateFunction.tests.ps1
│       └── Public/
│           └── Get-Something.tests.ps1
├── .gitattributes
├── .gitignore
├── azure-pipelines.yml
├── build.ps1
├── build.yaml
├── CHANGELOG.md
├── GitVersion.yml
├── README.md
├── RequiredModules.psd1
├── Resolve-Dependency.ps1
└── Resolve-Dependency.psd1
```

| File or folder                    | What it is for                                                                   |
|-----------------------------------|----------------------------------------------------------------------------------|
| `build.ps1`                       | The entry point for every build and test run, on your machine and in CI          |
| `build.yaml`                      | The build configuration: workflows, Pester settings, and ModuleBuilder settings  |
| `RequiredModules.psd1`            | The modules that the build needs, such as InvokeBuild, Pester, and ModuleBuilder |
| `Resolve-Dependency.ps1`, `.psd1` | Download those modules; the `.psd1` file selects the method and the repository   |
| `GitVersion.yml`                  | The rules that GitVersion uses to calculate the version from the Git history     |
| `source/WorkshopTools.psd1`       | The module manifest with version, author, and description                        |
| `source/WorkshopTools.psm1`       | A placeholder; the build creates the real file                                   |
| `source/Public`, `source/Private` | One file per function: exported to users, or internal to the module              |
| `source/en-US`                    | Help files, such as the conceptual help topic `about_WorkshopTools`              |
| `tests/QA`, `tests/Unit`          | Quality tests for the whole module, and unit tests for each function             |
| `azure-pipelines.yml`             | The CI pipeline: build once, test on Windows, Linux, and macOS, then deploy      |
| `CHANGELOG.md`                    | The change log; the build turns it into release notes                            |
| `output/`                         | Everything that the build creates; `.gitignore` keeps it out of Git              |

The demo project FileManagementSample uses the same layout. It adds a custom
build task in `.build/` and runs its pipeline in GitHub Actions instead of
Azure Pipelines, see [CI/CD with GitHub Actions](16-cicd-with-github-actions.md).

## Add the workshop function

`Add-Sample` adds code from Sampler's templates to a project, such as a public
or private function with its test, a class, an enum, a DSC resource, or GitHub
Copilot instruction files. Run it in the project folder:

```powershell
Set-Location -Path ./WorkshopTools
Add-Sample -Sample PublicFunction -PublicFunctionName Get-FileExtensionSize -SourceDirectory source
```

It creates two files, `source/Public/Get-FileExtensionSize.ps1` and
`tests/Unit/Public/Get-FileExtensionSize.tests.ps1`. Without
`-SourceDirectory`, it asks for the name of the source folder.

Both files contain sample code, so replace them:

1. Replace the function with the workshop function from
   [Your first function](09-your-first-function.md), including its
   comment-based help. The complete file is
   [Get-FileExtensionSize.ps1][fms-get-fileextensionsize] in the demo
   project. The help matters: the quality tests fail the build when a public
   function has no synopsis, no description longer than 40 characters, no
   example, or a parameter without a description.
2. Replace the test. In Sampler 0.120.1, the generated test still tests the
   sample function `Get-Something`, and it contains the placeholder
   `<% $PLASTER_PARAM_ModuleName %>` instead of the module name. This test
   follows the pattern of the demo project:

```powershell
BeforeAll {
    $script:moduleName = 'WorkshopTools'

    # If the module is not found, run the build task 'noop'.
    if (-not (Get-Module -Name $script:moduleName -ListAvailable))
    {
        # Redirect all streams to $null, except the error stream (stream 2)
        & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
    }

    # Re-import the module using force to get any code changes between runs.
    Import-Module -Name $script:moduleName -Force -ErrorAction 'Stop'
}

AfterAll {
    Remove-Module -Name $script:moduleName
}

Describe 'Get-FileExtensionSize' {
    BeforeAll {
        $script:rootPath = Join-Path -Path $TestDrive -ChildPath 'Files'
        $subPath = Join-Path -Path $script:rootPath -ChildPath 'sub'
        $null = New-Item -Path $subPath -ItemType 'Directory' -Force

        Set-Content -Path (Join-Path -Path $script:rootPath -ChildPath 'a.txt') -Value 'a'
        Set-Content -Path (Join-Path -Path $script:rootPath -ChildPath 'b.txt') -Value 'b'
        Set-Content -Path (Join-Path -Path $subPath -ChildPath 'c.log') -Value 'c'
    }

    It 'Should rank the extensions by number of files, including subfolders' {
        $result = WorkshopTools\Get-FileExtensionSize -Path $script:rootPath -Top 2

        $result.Extension | Should -Be @('.txt', '.log')
        $result.FileCount | Should -Be @(2, 1)
    }

    It 'Should throw when Top is not a number' {
        { WorkshopTools\Get-FileExtensionSize -Path $script:rootPath -Top 'many' } |
            Should -Throw -ErrorId 'ParameterArgumentTransformationError,Get-FileExtensionSize'
    }
}
```

- `BeforeAll` imports the module. When PowerShell can't find it, the test
  first runs the empty build task `noop`, which puts `output/module` on the
  module path of the session.
- `WorkshopTools\Get-FileExtensionSize` is a *module-qualified name*: it calls
  the function from this module, even if another command has the same name.
- `$TestDrive` is a temporary folder for the test files.
  [Testing with Pester](14-testing-with-pester.md) explains it and the other
  parts of a test.

## Build the module for the first time

Two commands build the module. The first one downloads the build dependencies
and runs the empty task `noop`; the second one runs the default workflow,
which builds the module and runs all tests:

```powershell
./build.ps1 -ResolveDependency -Tasks noop
./build.ps1
```

The dependencies land in `output/RequiredModules`, separate from your other
modules: InvokeBuild, Pester, ModuleBuilder, PSScriptAnalyzer, and Sampler
itself, among others. Near the end of its output, the build summarizes the
tests per file:

```text
Test Script File                 Duration Result Passed Failed Skipped Total
----------------                 -------- ------ ------ ------ ------- -----
module.tests.ps1                2 seconds Passed     22      0       1    23
Get-PrivateFunction.tests.ps1   0 seconds Passed      2      0       0     2
Get-FileExtensionSize.tests.ps1 0 seconds Passed      2      0       0     2
Get-Something.tests.ps1         0 seconds Passed     10      0       0    10
```

The last line reads
`Build succeeded. 16 tasks, 0 errors, 0 warnings 00:00:13.0337682`. The
quality tests skip one test, *Changelog has been updated*, because the
project isn't a Git repository yet.

## Use the built module

The build writes the module into a folder named after its version.
`Import-Module` accepts the parent folder and finds the version inside:

```powershell
Import-Module -Name ./output/module/WorkshopTools -Force
Get-Command -Module WorkshopTools
```

```text
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Function        Get-FileExtensionSize                              0.0.1      WorkshopTools
Function        Get-Something                                      0.0.1      WorkshopTools
```

The version is `0.0.1`: when GitVersion isn't available, Sampler takes the
version from the manifest in `source/`.
[Building with Sampler](15-building-with-sampler.md) shows how GitVersion
calculates it from the Git history instead.

## Common pitfalls

- **Editing the built module.** Changes in `output/module` don't survive the
  next build: its first task, `Clean`, deletes everything in `output/` except
  the folders `RequiredModules` and `agentic`. Always edit `source/`.
- **Forgetting `-ResolveDependency` on a fresh clone.** Without the
  dependencies, `./build.ps1 -Tasks test` warns
  "Some required Modules are missing, make sure you first run with the
  '-ResolveDependency' parameter." and stops with "The term 'Invoke-Build' is
  not recognized as a name of a cmdlet, function, script file, or executable
  program." Only `./build.ps1` without `-Tasks`, or with the task `build`,
  resolves the dependencies for you.
- **Changing `PSModulePath` by hand.** `build.ps1` puts `output/RequiredModules`
  and `output/module` at the front of `$env:PSModulePath`, but only for the
  current session; PowerShell builds the variable anew in every session. If
  you add these folders permanently, every session finds the build tools and
  your half-finished module in a project folder. The demo project's
  instructions for GitHub Copilot say it plainly: "Never manually prepend
  anything to `PSModulePath`."
- **Keeping the generated test.** The test that `Add-Sample` creates doesn't
  test your function. Replace it before you rely on a green build.

## Exercises

Exercise 3 uses the sample folder. Create it from the root of this repository
with `$root = ./samples/New-WorkshopFolder.ps1 -Force` before you change to
the project folder; `$root` keeps pointing to it.

### Exercise 1: Scaffold WorkshopTools

1. Install Sampler and scaffold `WorkshopTools` as a `SimpleModule`, with the
   answers from the table above.
2. Which version does the module manifest in `source/` declare, and which
   functions does it export?
3. Which file defines what `./build.ps1` does without parameters?

<details>
<summary>Solution</summary>

```powershell
Set-Location -Path ./WorkshopTools
$manifest = Import-PowerShellDataFile -Path ./source/WorkshopTools.psd1
[pscustomobject]$manifest | Select-Object -Property ModuleVersion, Author, FunctionsToExport
```

```text
ModuleVersion Author               FunctionsToExport
------------- ------               -----------------
0.0.1         Workshop Participant {}
```

The source manifest exports nothing yet: the build writes the public functions
into the manifest of the built module. What `./build.ps1` does without
parameters is defined in `build.yaml`, under `BuildWorkflow`: the workflow
`'.'` runs the workflows `build` and `test`.

</details>

### Exercise 2: Add Get-FileExtensionSize

1. Add the function `Get-FileExtensionSize` with `Add-Sample`.
2. Replace the function and the test, as shown in
   [Add the workshop function](#add-the-workshop-function).
3. Build the module. How many tests ran for the new function?

<details>
<summary>Solution</summary>

```powershell
Add-Sample -Sample PublicFunction -PublicFunctionName Get-FileExtensionSize -SourceDirectory source
./build.ps1 -ResolveDependency -Tasks noop
./build.ps1
```

```text
Test Script File                 Duration Result Passed Failed Skipped Total
----------------                 -------- ------ ------ ------ ------- -----
module.tests.ps1                2 seconds Passed     22      0       1    23
Get-PrivateFunction.tests.ps1   0 seconds Passed      2      0       0     2
Get-FileExtensionSize.tests.ps1 0 seconds Passed      2      0       0     2
Get-Something.tests.ps1         0 seconds Passed     10      0       0    10
```

Two unit tests ran for `Get-FileExtensionSize`. The quality tests in
`module.tests.ps1` check it, too: each function adds a test for its unit test
file, for PSScriptAnalyzer, and four tests for its help.

</details>

### Exercise 3: Build and import WorkshopTools

1. Import the built module from `output/module` and run
   `Get-FileExtensionSize` against the sample folder for the top three
   extensions. Show the total size in bytes.
2. The project contains the function `Get-PrivateFunction`. Why can't you call
   it after the import?

<details>
<summary>Solution</summary>

```powershell
Import-Module -Name ./output/module/WorkshopTools -Force
Get-FileExtensionSize -Path $root -Top 3 |
    Select-Object -Property Extension, FileCount, @{ Name = 'Bytes'; Expression = { [int64]($_.TotalFileSize * 1GB) } }
```

```text
Extension FileCount  Bytes
--------- ---------  -----
.log              6 181290
.TXT              5    259
.json             4    548
```

`Get-PrivateFunction` lives in `source/Private`. The build merges it into
`WorkshopTools.psm1`, but the manifest exports only the functions from
`source/Public`:

```powershell
(Import-PowerShellDataFile -Path ./output/module/WorkshopTools/0.0.1/WorkshopTools.psd1).FunctionsToExport
```

```text
Get-FileExtensionSize
Get-Something
```

Only functions inside the module, such as `Get-Something`, can call it.

</details>

## Key takeaways

- A module packages functions with a manifest that declares the version, the
  author, and the exported commands.
- `New-SampleModule` scaffolds a complete project; `SimpleModule` is the best
  start, and `CustomModule` with `-Features` runs without questions.
- You edit `source/` and `tests/`; the build creates everything in `output/`.
- `Add-Sample` adds a function and its test, but its sample code has to be
  replaced.
- `./build.ps1 -ResolveDependency -Tasks noop` prepares a fresh clone, and
  `./build.ps1` builds and tests the module.

## Learn more

- [Sampler on GitHub](https://github.com/gaelcolas/Sampler)
- [Sampler wiki](https://github.com/gaelcolas/Sampler/wiki)
- [Sampler in the PowerShell Gallery](https://www.powershellgallery.com/packages/Sampler)
- [Plaster](https://github.com/PowerShellOrg/Plaster)
- [about_Modules](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_modules)
- [How to write a PowerShell module manifest](https://learn.microsoft.com/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)
- [about_PSModulePath](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_psmodulepath)
- [about_Command_Precedence](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_command_precedence)

[fms-get-fileextensionsize]: https://github.com/raandree/FileManagementSample/blob/main/source/Public/Get-FileExtensionSize.ps1

---

[← Previous: Debugging in VS Code](12-debugging-in-vs-code.md)
· [Overview](../README.md) ·
[Next: Testing with Pester →](14-testing-with-pester.md)
