<!-- markdownlint-disable MD041 -->
![PowerShell and GitHub Copilot: workshop notes][banner]

These notes recap a workshop on PowerShell and GitHub Copilot, held over two
half days. One question runs through all of it: which file extensions occur
most often in a folder tree, and how much space do they use? The answer starts
as a one-liner in the console, becomes a function, and ends as a tested module
that a CI/CD pipeline builds and tests on every change.

Each of the 17 topics has its own page with the demo from the workshop, the
background behind it, common pitfalls, exercises with solutions, and links to
the official documentation.

> [!TIP]
> New to PowerShell? Start with
> [Everything is an object](docs/01-everything-is-an-object.md) and follow the
> *Next* link at the bottom of every page.

[banner]: assets/banner.png

## Workshop at a glance

![Workshop roadmap in three parts with 17 topics: PowerShell fundamentals,
from one-liners to tools, and engineering practices](assets/diagrams/workshop-journey.svg)

## Topics

### Part 1: PowerShell fundamentals

| #   | Topic                                                                           | What you learn                                                    |
|-----|---------------------------------------------------------------------------------|-------------------------------------------------------------------|
| 1   | [Everything is an object](docs/01-everything-is-an-object.md)                   | Properties, methods, and `Get-Member`; dates and files as objects |
| 2   | [The pipeline, loops, and filters](docs/02-pipeline-loops-and-filters.md)       | `$_`, `ForEach-Object`, `Where-Object`, and filtering early       |
| 3   | [Building a pipeline step by step](docs/03-building-a-pipeline-step-by-step.md) | Grouping, sorting, and measuring files, one command at a time     |
| 4   | [Hashtables](docs/04-hashtables.md)                                             | Key-value pairs, lookup tables, and ordered dictionaries          |
| 5   | [PSCustomObject](docs/05-pscustomobject.md)                                     | Your own objects for records and function output                  |
| 6   | [CSV, JSON, and YAML](docs/06-csv-json-and-yaml.md)                             | Reading and writing data files, and the traps of text data        |
| 7   | [Inspecting and extending objects](docs/07-inspecting-and-extending-objects.md) | `Get-Member`, `Add-Member`, and computed properties               |
| 8   | [Strings and the format operator](docs/08-strings-and-the-format-operator.md)   | Quotes, escape sequences, and `-f` with number and date formats   |

### Part 2: From one-liners to tools

| #   | Topic                                                 | What you learn                                                        |
|-----|-------------------------------------------------------|-----------------------------------------------------------------------|
| 9   | [Your first function](docs/09-your-first-function.md) | Typed parameters, output objects, and help for a reusable command     |
| 10  | [Pipeline input](docs/10-pipeline-input.md)           | `ValueFromPipeline`, `ValueFromPipelineByPropertyName`, and `process` |
| 11  | [Splatting](docs/11-splatting.md)                     | Passing parameters as a hashtable, and passing them on                |

### Part 3: Engineering practices

| #   | Topic                                                                               | What you learn                                                  |
|-----|-------------------------------------------------------------------------------------|-----------------------------------------------------------------|
| 12  | [Debugging in VS Code](docs/12-debugging-in-vs-code.md)                             | Breakpoints, variables, and the call stack, to fix and to learn |
| 13  | [Scaffolding a module with Sampler](docs/13-scaffolding-a-module-with-sampler.md)   | From a function to a module project with build and tests        |
| 14  | [Testing with Pester](docs/14-testing-with-pester.md)                               | `Describe`, `It`, `Should`, test data, and mocks                |
| 15  | [Building with Sampler](docs/15-building-with-sampler.md)                           | Workflows and tasks that run the same locally and in CI         |
| 16  | [CI/CD with GitHub Actions](docs/16-cicd-with-github-actions.md)                    | A pipeline that builds and tests on four platforms              |
| 17  | [GitHub Copilot in the demo project](docs/17-github-copilot-in-the-demo-project.md) | Instructions, skills, and a Memory Bank for Copilot             |

## How each page works

Every topic page follows the same structure, so you always know where to
look:

1. **Concepts:** the demo from the workshop with its real output, then the
   background and more examples.
2. **Common pitfalls:** the mistakes that cost time in practice, and how to
   avoid them.
3. **Exercises:** tasks for the sample data. Try them first, then click
   **Solution** to compare.
4. **Key takeaways:** the essentials in a few bullets.
5. **Learn more:** links to the official documentation.

## Before you start

To follow along, you need:

- [PowerShell 7][install-powershell]. The examples were tested with
  PowerShell 7.6. The sample data and the demo project also work in Windows
  PowerShell 5.1.
- [Visual Studio Code](https://code.visualstudio.com/) with the
  [PowerShell extension][vscode-powershell].
- [Git](https://git-scm.com/downloads), and a GitHub account to run your own
  pipelines.

[install-powershell]: https://learn.microsoft.com/powershell/scripting/install/install-powershell
[vscode-powershell]: https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell

### Sample data

The exercises use the sample data in [`samples`](samples/README.md), so they
run on any machine. Run these commands from the root of this repository:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
$people = Import-Csv -Path ./samples/People.csv -Delimiter ';'
```

The script creates a folder with 22 sample files and returns it; every run
creates the same files. `People.csv` contains 24 fictional people.

The demos from the workshop use `D:\LabSources`, the AutomatedLab sources
folder of the workshop. Replace it with any folder that contains files, or
use the sample folder.

### Demo project

The demo project [FileManagementSample][fms] turns the workshop function into
a tested module. Clone it and run its build once: the first command downloads
the build dependencies into `output/RequiredModules`, the second one builds
the module and runs all tests.

```powershell
git clone https://github.com/raandree/FileManagementSample.git
Set-Location -Path FileManagementSample
./build.ps1 -ResolveDependency -Tasks noop
./build.ps1
```

[fms]: https://github.com/raandree/FileManagementSample

## Kick-off and experience check

The workshop started with a round on everyone's experience. The same
questions make a good self-check afterwards. Each one points to the topics
that cover it.

| Experience with …                          | Covered in                                                                                                                                    |
|--------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| PowerShell scripting: one- and two-liners  | [Part 1: PowerShell fundamentals](#part-1-powershell-fundamentals), topics 1 to 8                                                             |
| PowerShell programming: complete solutions | [Part 2: From one-liners to tools](#part-2-from-one-liners-to-tools) and [Scaffolding a module](docs/13-scaffolding-a-module-with-sampler.md) |
| GitHub as a source control system          | [CI/CD with GitHub Actions](docs/16-cicd-with-github-actions.md), [Demo project](#demo-project)                                               |
| CI/CD                                      | [Building with Sampler](docs/15-building-with-sampler.md), [CI/CD with GitHub Actions](docs/16-cicd-with-github-actions.md)                   |
| GitHub Copilot                             | [GitHub Copilot in the demo project](docs/17-github-copilot-in-the-demo-project.md)                                                           |
| Pester or other testing frameworks         | [Testing with Pester](docs/14-testing-with-pester.md)                                                                                         |

## Next steps

Open from the workshop:

- [ ] Ask the trainer for the `ZfFileManagementModule`, so that its module
  files can be added to the repository.

Suggested practice:

- [ ] Work through the exercises of one topic per day, and keep your
  solutions in a script file.
- [ ] Clone FileManagementSample, run `./build.ps1`, and step through
  `Get-FileExtensionSize` in the debugger.
- [ ] Scaffold your own module with Sampler and move one of your scripts into
  it.
- [ ] Ask GitHub Copilot to write a Pester test for one of your functions,
  then review it like a colleague's code.

## Further resources

Recommended during the workshop:

| Resource                           | What it is                                                                                                               |
|------------------------------------|--------------------------------------------------------------------------------------------------------------------------|
| [AutomatedLab][automatedlab]       | Framework that deploys lab environments on Hyper-V and Azure with PowerShell scripts                                     |
| [Agentic Operating Model][aom]     | Presentation and workshop on agentic knowledge work: a governed, reviewable way of working with AI agents                |
| [Copilot Atelier][copilot-atelier] | Portable GitHub Copilot customizations: agents, instructions, skills, prompts, and hooks                                 |
| [PowerShell Universal][psu]        | Turns PowerShell scripts into automation, REST APIs, and dashboards; free Developer Edition                              |
| [ILSpy][ilspy]                     | Open-source .NET decompiler. `(Get-Command -Name Get-ChildItem).DLL` shows the DLL behind a cmdlet to open in ILSpy      |
| [PS1ToEXE][ps1toexe]               | PowerShell Gallery module that creates an EXE from a PowerShell project; last published in 2017                          |
| [LGTM (Looks Good to Me)][lgtm]    | Music video by Degenerative Pixels on YouTube, named after the code review shorthand                                     |
| [PSConfEU][psconfeu]               | PowerShell Conference Europe, recommended for learning, networking, and community. Next edition: Kraków, 21–24 June 2027 |

Starting points for further learning:

- [PowerShell 101](https://learn.microsoft.com/powershell/scripting/learn/ps101/00-introduction):
  the free introductory book on Microsoft Learn
- [Deep dives](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/overview):
  in-depth articles on hashtables, PSCustomObject, strings, and more
- [PowerShell documentation](https://learn.microsoft.com/powershell/)

[automatedlab]: https://github.com/AutomatedLab/AutomatedLab
[aom]: https://github.com/raandree/AgenticOperatingModel
[copilot-atelier]: https://github.com/raandree/CopilotAtelier
[psu]: https://devolutions.net/powershell-universal/
[ilspy]: https://github.com/icsharpcode/ILSpy
[ps1toexe]: https://www.powershellgallery.com/packages/PS1ToEXE/1.0.0.1
[lgtm]: https://www.youtube.com/watch?v=3TNpOD6bov8
[psconfeu]: https://psconf.eu/

## Glossary

| Term                | Meaning                                                                                     |
|---------------------|---------------------------------------------------------------------------------------------|
| Advanced function   | A function with `[CmdletBinding()]` that behaves like a compiled cmdlet                     |
| Alias               | A short alternative name for a command or parameter, such as `dir` for `Get-ChildItem`      |
| Artifact            | A file or folder that a pipeline job stores for later jobs, such as the built module        |
| Calculated property | A property that `Select-Object` computes from a hashtable with a name and an expression     |
| CI/CD               | Continuous integration and delivery: build, test, and release automatically on every change |
| Custom instructions | Markdown files that tell GitHub Copilot the conventions of a repository                     |
| Dot-sourcing        | Running a script with `.` so that its functions and variables stay in the current session   |
| Hashtable           | A collection of unique keys and their values                                                |
| Here-string         | A string over several lines, enclosed in `@'` and `'@` or in `@"` and `"@`                  |
| Method              | An action an object can perform, such as `AddDays()` on a `DateTime`                        |
| Mock                | A replacement for a command during a Pester test, so that the test controls its result      |
| Module              | A package of functions with a manifest, which PowerShell can import, version, and share     |
| NoteProperty        | A property with a fixed value that is attached to an object                                 |
| Object              | Data plus behavior; every PowerShell command returns objects                                |
| Parameter binding   | How PowerShell assigns arguments and pipeline input to the parameters of a command          |
| Pester              | The test and mock framework for PowerShell                                                  |
| Pipeline            | Commands joined with `\|`; objects flow from left to right, one at a time                   |
| Property            | A named value of an object, such as `Length` of a file                                      |
| PSCustomObject      | An object you create on the fly from a hashtable literal                                    |
| Runner              | The machine that executes a GitHub Actions job                                              |
| Sampler             | A template and build framework for PowerShell modules                                       |
| Script block        | A piece of code in braces, such as the filter in `Where-Object { $_.Length -gt 1MB }`       |
| ScriptProperty      | A property whose value a script block computes every time you read it                       |
| Splatting           | Passing parameters as a hashtable with `@` instead of `$`                                   |
| TestDrive           | A temporary folder that Pester creates for a test and deletes afterwards                    |
| `$_` and `$PSItem`  | The current object in the pipeline                                                          |
| Workflow            | In Sampler, a named list of build tasks; in GitHub Actions, an automated process in YAML    |
