# Testing with Pester

[Overview](../README.md) › Part 3: Engineering practices › Topic 14 of 17

A test is code that checks your code, so you find out in seconds, not in
production, when a change breaks something. Pester is the tool for this in
PowerShell. This topic explains how to read and write Pester tests, from the
demo project to tests of your own.

In this topic, you learn to:

- read and write tests with `Describe`, `Context`, `It`, and `Should`
- prepare and clean up with `BeforeAll`, `BeforeEach`, `AfterEach`, and
  `AfterAll`
- generate tests from data with `-ForEach`
- replace a command with `Mock` to make a test predictable
- run tests with `Invoke-Pester` and a configuration object

## The Pester language

Pester is the test and mock framework for PowerShell. Its domain-specific
language reads like a specification: `Describe` names what is tested,
`Context` sets the scene, `It` states one expected behavior, and `Should`
checks it. An excerpt from the tests of the demo project:

```powershell
Describe 'Get-FileExtensionSize' {
    Context 'When the folder tree contains files' {
        It 'Should rank the extensions by number of files, including files in subfolders' {
            $result = FileManagementSample\Get-FileExtensionSize -Path $script:rootPath -Top 4

            @($result).Count | Should -Be 4
            $result.Extension | Should -Be @('.txt', '.log', '.bin', '')
            $result.FileCount | Should -Be @(4, 3, 2, 1)
        }
    }

    Context 'When the parameters are not valid' {
        It 'Should throw when Top is not a number' {
            { FileManagementSample\Get-FileExtensionSize -Path $script:rootPath -Top 'many' } |
                Should -Throw -ErrorId 'ParameterArgumentTransformationError,Get-FileExtensionSize'
        }
    }
}
```

Read the names from the outside in, and you get a sentence:
"Get-FileExtensionSize, when the parameters are not valid, should throw when
Top is not a number." `Should -Be` compares whole arrays, item by item and in
order. `Should -Throw` needs a script block, because Pester has to run the
code itself to catch the error; `-ErrorId` checks that it's the right error.

## A complete test file to read and run

[`samples/New-WorkshopFolder.Tests.ps1`](../samples/New-WorkshopFolder.Tests.ps1)
tests the script that creates the sample folder, and it shows most of what
this topic explains: a `BeforeAll` block that defines a helper function, one
`Context` for each situation, a data-driven test with `-ForEach`, and
`Should -Throw -ExpectedMessage` for the error cases. Run it from the root of
this repository:

```powershell
Invoke-Pester -Path ./samples -Output Detailed
```

```text
Pester v6.2.0

Running tests from 1 files.

Running tests from 'D:\Git\261116PowerShellGhcpWorkshop\samples\New-WorkshopFolder.Tests.ps1'
Describing New-WorkshopFolder.ps1
 Context When the folder does not exist
   [+] Should return the root folder 17ms
   [+] Should create 22 visible files 3ms
   [+] Should create 6 files with the extension ".log" 5ms
   [+] Should create 5 files with the extension ".txt" 3ms
   [+] Should create 4 files with the extension ".json" 3ms
   [+] Should create 3 files with the extension ".ps1" 15ms
   [+] Should create 2 files with the extension ".csv" 2ms
   [+] Should create 1 files with the extension ".bak" 2ms
   [+] Should create 1 files with the extension "" 2ms
   [+] Should create the folder archive.old, whose name contains a dot 4ms
   [+] Should hide its marker file from Get-ChildItem 4ms
   [+] Should set the last write time of the files 6ms
 Context When the script runs twice
   [+] Should write the same content every time 376ms
 Context When the folder already exists
   [+] Should throw without -Force 30ms
   [+] Should re-create the folder with -Force 125ms
   [+] Should not remove a folder that it did not create 29ms
 Context When the WhatIf parameter is used
   [+] Should not create anything 23ms
Tests completed in 1.03s
Tests Passed: 17, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0
```

`[+]` marks a passed test, `[-]` a failed one. The outputs on this page come
from Pester 6.2.0; Pester 5 prints the same tests with slightly different
messages.

## Test files in TestDrive

The tests create their sample files in `$TestDrive`, a temporary folder that
Pester cleans up automatically. Pester creates it in your temporary folder for
each test file and removes the files that a `Describe` or `Context` block
created when the block ends. Reach it as the drive `TestDrive:`, or through the
variable `$TestDrive`, which holds the real path for `Join-Path` and .NET
methods. Tests that work in it don't depend on the files of your machine, and
they don't leave files behind.

## Setup and teardown

Four blocks prepare and clean up: `BeforeAll` runs once before the tests of
its block, `BeforeEach` before every test, `AfterEach` after every test, and
`AfterAll` once at the end. `AfterEach` and `AfterAll` run even when a test
fails, so they are the place for cleanup. Save this file as
`People.Tests.ps1` in the root of this repository:

```powershell
BeforeAll {
    Write-Host '-> BeforeAll: import People.csv once'
    $script:people = Import-Csv -Path (Join-Path -Path $PSScriptRoot -ChildPath 'samples/People.csv') -Delimiter ';'
}

Describe 'People.csv' {
    BeforeEach {
        Write-Host '-> BeforeEach'
    }

    It 'Should contain 24 people' {
        $script:people.Count | Should -Be 24
    }

    It 'Should contain the department IT' {
        $script:people.Department | Should -Contain 'IT'
    }

    AfterEach {
        Write-Host '-> AfterEach'
    }

    AfterAll {
        Write-Host '-> AfterAll'
    }
}
```

With `-Output None`, Pester prints nothing itself, and only the messages of
the blocks remain:

```powershell
Invoke-Pester -Path ./People.Tests.ps1 -Output None
```

```text
-> BeforeAll: import People.csv once
-> BeforeEach
-> AfterEach
-> BeforeEach
-> AfterEach
-> AfterAll
```

Each test runs in its own scope. A test can read the variables from
`BeforeAll`, but when it changes one, the next test still sees the original
value. That keeps the tests independent of each other and of their order.

## Data-driven tests with -ForEach

When the same check applies to several inputs, write the test once and pass
the data with `-ForEach`. Pester creates one test per hashtable, turns each
key into a variable, and fills `<Key>` placeholders in the test name. Save
this file as `Departments.Tests.ps1` next to `People.Tests.ps1`:

```powershell
BeforeAll {
    $script:people = Import-Csv -Path (Join-Path -Path $PSScriptRoot -ChildPath 'samples/People.csv') -Delimiter ';'
}

Describe 'Departments in People.csv' {
    It 'Should have <Count> people in <Department>' -ForEach @(
        @{ Department = 'IT'; Count = 9 }
        @{ Department = 'Sales'; Count = 7 }
        @{ Department = 'HR'; Count = 5 }
        @{ Department = 'Finance'; Count = 3 }
    ) {
        @($script:people | Where-Object -Property Department -EQ -Value $Department).Count |
            Should -Be $Count
    }
}
```

With `-PassThru`, `Invoke-Pester` returns a result object. Its property
`Tests` lists every test with its expanded name:

```powershell
$result = Invoke-Pester -Path ./Departments.Tests.ps1 -Output None -PassThru
$result.Tests | Select-Object -Property ExpandedName, Result
```

```text
ExpandedName                    Result
------------                    ------
Should have 9 people in IT      Passed
Should have 7 people in Sales   Passed
Should have 5 people in HR      Passed
Should have 3 people in Finance Passed
```

`-ForEach` also works on `Describe` and `Context`, to repeat a whole group of
tests for each item.

## The most useful Should operators

Every operator can be negated with `-Not`, for example
`$people.Department | Should -Not -Contain 'Legal'`. The examples use
`$people` from `People.csv` and `$root` from the sample folder:

| Classic operator | Pester 6 assertion               | Passes when                        | Example                                                                                                  |
|------------------|----------------------------------|------------------------------------|----------------------------------------------------------------------------------------------------------|
| `-Be`            | `Should-Be`                      | Equal; strings ignore case         | `$people.Count \| Should -Be 24`                                                                         |
| `-BeExactly`     | `Should-BeString -CaseSensitive` | Equal, including case              | `$people[0].Department \| Should -BeExactly 'IT'`                                                        |
| `-BeGreaterThan` | `Should-BeGreaterThan`           | Greater                            | `[int]$people[0].Age \| Should -BeGreaterThan 18`                                                        |
| `-BeLike`        | `Should-BeLikeString`            | Matches a wildcard pattern         | `$people[0].EmailAddress \| Should -BeLike '*@example.com'`                                              |
| `-Match`         | `Should-MatchString`             | Matches a regular expression       | `$people[0].HireDate \| Should -Match '^\d{4}-\d{2}-\d{2}$'`                                             |
| `-Contain`       | `Should-ContainCollection`       | The collection contains the item   | `$people.City \| Should -Contain 'Vienna'`                                                               |
| `-HaveCount`     | `Should-BeCollection -Count`     | The collection has that many items | `$people \| Should -HaveCount 24`                                                                        |
| `-BeNullOrEmpty` | `Should-BeNull`                  | Nothing came back                  | `$people \| Where-Object -Property Department -EQ -Value 'Legal' \| Should -BeNullOrEmpty`               |
| `-BeOfType`      | `Should-HaveType`                | The object has that type           | `$root \| Should -BeOfType ([System.IO.DirectoryInfo])`                                                  |
| `-Exist`         |                                  | The path exists                    | `Join-Path -Path $root -ChildPath 'backup/database.bak' \| Should -Exist`                                |
| `-Throw`         | `Should-Throw`                   | The script block throws            | `{ Get-Item -Path (Join-Path -Path $root -ChildPath 'missing.txt') -ErrorAction Stop } \| Should -Throw` |

The Pester 6 assertions are written with a hyphen and no space, and they are
type-aware: their failure messages show the types, too. Where
`25 | Should -Be 24` reports `Expected 24, but got 25.`, `25 | Should-Be 24`
reports `Expected [int] 24, but got [int] 25.` You can mix both styles in one
file.

## Mocking with Mock

Some commands make a test unpredictable: `Get-Date` returns a different value
every day. `Mock` replaces such a command, for the duration of the block, with
a script block of your choice. `Should -Invoke` then checks how often the mock
was called. Save this file as `Christmas.Tests.ps1`:

```powershell
BeforeAll {
    function Get-DaysUntilChristmas {
        $today = (Get-Date).Date
        $christmas = [datetime]::new($today.Year, 12, 24)
        ($christmas - $today).Days
    }
}

Describe 'Get-DaysUntilChristmas' {
    It 'Should count 37 days from 17 November' {
        Mock -CommandName Get-Date -MockWith { [datetime]'2026-11-17 10:30' }

        Get-DaysUntilChristmas | Should -Be 37
        Should -Invoke -CommandName Get-Date -Times 1 -Exactly
    }

    It 'Should count 0 days on 24 December' {
        Mock -CommandName Get-Date -MockWith { [datetime]'2026-12-24 18:00' }

        Get-DaysUntilChristmas | Should -Be 0
    }
}
```

```powershell
$result = Invoke-Pester -Path ./Christmas.Tests.ps1 -Output None -PassThru
$result.Tests | Select-Object -Property ExpandedName, Result
```

```text
ExpandedName                          Result
------------                          ------
Should count 37 days from 17 November Passed
Should count 0 days on 24 December    Passed
```

Both tests pass on any day of the year. A mock defined in an `It` applies only
to that test; a mock in `BeforeAll` applies to all tests of the block.

## Discovery and run

Pester runs a test file in two phases. In the *discovery* phase, it runs the
file from top to bottom to find the tests: it runs the script blocks of
`Describe` and `Context`, but not those of `It` and the setup blocks. In the
*run* phase, it runs the setup blocks and the tests. This file,
`Phases.Tests.ps1`, makes the phases visible:

```powershell
Write-Host 'Discovery: the file runs from top to bottom'

Describe 'Phases' {
    Write-Host 'Discovery: Describe runs its script block to find the tests'

    BeforeAll {
        Write-Host 'Run: BeforeAll'
    }

    It 'Runs in the run phase' {
        Write-Host 'Run: It'
    }
}
```

```powershell
Invoke-Pester -Path ./Phases.Tests.ps1 -Output None
```

```text
Discovery: the file runs from top to bottom
Discovery: Describe runs its script block to find the tests
Run: BeforeAll
Run: It
```

The rule that follows: put all test code into `It`, `BeforeAll`, `BeforeEach`,
`AfterEach`, or `AfterAll`. Code that computes the data for `-ForEach`, for
example from files, belongs into `BeforeDiscovery`, because Pester evaluates
`-ForEach` during discovery. Pester 6 discovers and runs each file before it
starts the next one; Pester 5 discovered all files first.

## Run tests with a configuration

`Invoke-Pester -Path` covers everyday runs. For everything else, create a
configuration object with `New-PesterConfiguration`, set its options, and
pass it with `-Configuration`. Tab completion shows the sections, such as
`Run`, `Filter`, `Output`, `TestResult`, and `CodeCoverage`. This
configuration runs only the tests whose full name contains `WhatIf`:

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './samples'
$config.Filter.FullName = '*WhatIf*'
$config.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $config
```

```text
Pester v6.2.0

Running tests from 1 files.
Filter 'FullName' set to ('*WhatIf*').
Filters selected 1 tests to run.

Running tests from 'D:\Git\261116PowerShellGhcpWorkshop\samples\New-WorkshopFolder.Tests.ps1'
Describing New-WorkshopFolder.ps1
 Context When the WhatIf parameter is used
   [+] Should not create anything 22ms
Tests completed in 95ms
Tests Passed: 1, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 16
```

In a Sampler project, you don't call `Invoke-Pester` yourself: the build reads
the same options from the section `Pester` in `build.yaml`, see
[Building with Sampler](15-building-with-sampler.md).

## Quality tests and the CI run

Besides its unit tests, the demo project runs quality tests from
`tests/QA/module.tests.ps1`. They fail the build when a public function has
no unit test, fails PSScriptAnalyzer, or lacks help: a synopsis, a
description, an example, and a description for every parameter. They also
check that the changelog follows the *Keep a Changelog* format. Sampler adds
such a file to a new project, see
[Scaffolding a module with Sampler](13-scaffolding-a-module-with-sampler.md).

The tests run through the build, locally and on the CI runner alike. This is
the result of the CI run on Ubuntu:

```text
Test Script File                   Duration Result Passed Failed Skipped Total
----------------                   -------- ------ ------ ------ ------- -----
module.tests.ps1                  3 seconds Passed     16      0       0    16
Write-TestResultSummary.Tests.ps1 0 seconds Passed      9      0       0     9
Get-FileExtensionSize.Tests.ps1   0 seconds Passed      8      0       0     8
Get-LargestFile.Tests.ps1         0 seconds Passed     19      0       0    19
```

> [!NOTE]
> The CI run used Pester 6.2.0. Pester 6 adds new assertions such as
> `Should-Be`, and the classic `Should -Be` syntax of the demo tests still
> works.

## Common pitfalls

- **Test code directly in `Describe`.** It runs during discovery, and its
  variables are gone when the tests run. This test fails with
  `Expected 24, but got 0.`:

  ```powershell
  Describe 'People.csv' {
      $people = Import-Csv -Path (Join-Path -Path $PSScriptRoot -ChildPath 'samples/People.csv') -Delimiter ';'

      It 'Should contain 24 people' {
          $people.Count | Should -Be 24
      }
  }
  ```

  Assign such variables in `BeforeAll`, as the demo tests do with
  `$script:rootPath`.

- **`Mock` without `-ModuleName` for a module function.** A function in a
  module calls the commands it finds in the module's scope, not in the scope
  of the test. Take a module `ReportTools` whose function `Get-ReportDate`
  formats `Get-Date`. Without `-ModuleName`, the module keeps calling the real
  `Get-Date`, and a test that expects `2026-12-24` fails with
  `Expected strings to be the same, but they were different.` and shows the
  real date. `-ModuleName` places the mock inside the module, and the test
  passes:

  ```powershell
  Mock -CommandName Get-Date -MockWith { [datetime]'2026-12-24' } -ModuleName ReportTools
  ```

  The demo tests set this default for all mocks with
  `$PSDefaultParameterValues['Mock:ModuleName']`.

- **Case-insensitive comparisons.** `Should -Be` compares strings like `-eq`,
  so `'.TXT' | Should -Be '.txt'` passes. Use `-BeExactly` when case matters.

## Exercises

The exercises use the sample data. Save the files in the root of this
repository, next to the folder `samples`, and save the workshop function from
[Your first function](09-your-first-function.md) there as
`Get-FileExtensionSize.ps1`.

### Exercise 1: Test the workshop function in TestDrive

1. Write `Get-FileExtensionSize.Tests.ps1`. In `BeforeAll`, load the function
   and create the sample folder in `$TestDrive` with
   `samples/New-WorkshopFolder.ps1 -Path`.
2. With one `It` and `-ForEach`, test the number of files for all seven
   extensions of the sample folder, including the file without an extension.
3. Test that an empty folder returns nothing.

<details>
<summary>Solution</summary>

```powershell
BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')

    $newFolder = Join-Path -Path $PSScriptRoot -ChildPath 'samples/New-WorkshopFolder.ps1'
    $script:root = & $newFolder -Path (Join-Path -Path $TestDrive -ChildPath 'WorkshopFiles')
}

Describe 'Get-FileExtensionSize' {
    Context 'When the folder contains the sample files' {
        BeforeAll {
            $script:result = Get-FileExtensionSize -Path $script:root -Top 10
        }

        It 'Should count <Count> files with the extension "<Extension>"' -ForEach @(
            @{ Extension = '.log'; Count = 6 }
            @{ Extension = '.txt'; Count = 5 }
            @{ Extension = '.json'; Count = 4 }
            @{ Extension = '.ps1'; Count = 3 }
            @{ Extension = '.csv'; Count = 2 }
            @{ Extension = '.bak'; Count = 1 }
            @{ Extension = ''; Count = 1 }
        ) {
            $row = $script:result | Where-Object -Property Extension -EQ -Value $Extension
            $row.FileCount | Should -Be $Count
        }
    }

    Context 'When the folder is empty' {
        It 'Should return nothing' {
            $emptyPath = Join-Path -Path $TestDrive -ChildPath 'Empty'
            $null = New-Item -Path $emptyPath -ItemType Directory

            Get-FileExtensionSize -Path $emptyPath -Top 3 | Should -BeNullOrEmpty
        }
    }
}
```

```powershell
$result = Invoke-Pester -Path ./Get-FileExtensionSize.Tests.ps1 -Output None -PassThru
$result.Tests | Select-Object -Property ExpandedName, Result
```

```text
ExpandedName                                    Result
------------                                    ------
Should count 6 files with the extension ".log"  Passed
Should count 5 files with the extension ".txt"  Passed
Should count 4 files with the extension ".json" Passed
Should count 3 files with the extension ".ps1"  Passed
Should count 2 files with the extension ".csv"  Passed
Should count 1 files with the extension ".bak"  Passed
Should count 1 files with the extension ""      Passed
Should return nothing                           Passed
```

`. $PSCommandPath.Replace('.Tests.ps1', '.ps1')` dot-sources the file with the
same base name as the test file. `-Top 10` returns all seven groups. The
function names the text group `.TXT`, because `notes.TXT` comes first; the
test passes anyway, because `Where-Object -EQ` ignores case.

</details>

### Exercise 2: Mock Get-Date

1. Write a function `Get-StaleFile` with the parameters `Path` and `Days`
   that returns the files whose `LastWriteTime` is more than `Days` days
   before `Get-Date`.
2. Test it against the sample folder with `Get-Date` mocked to 17 November
   2026: 70 days return `LICENSE`, `notes.TXT`, and `readme.txt`; 365 days
   return nothing.
3. Check that `Get-StaleFile` calls `Get-Date` exactly once.

<details>
<summary>Solution</summary>

```powershell
BeforeAll {
    function Get-StaleFile {
        param ([string]$Path, [int]$Days)

        $limit = (Get-Date).AddDays(-$Days)
        Get-ChildItem -Path $Path -Recurse -File |
            Where-Object -Property LastWriteTime -LT -Value $limit
    }

    $newFolder = Join-Path -Path $PSScriptRoot -ChildPath 'samples/New-WorkshopFolder.ps1'
    $script:root = & $newFolder -Path (Join-Path -Path $TestDrive -ChildPath 'WorkshopFiles')
}

Describe 'Get-StaleFile' {
    BeforeAll {
        Mock -CommandName Get-Date -MockWith { [datetime]'2026-11-17' }
    }

    It 'Should find the files older than 70 days' {
        $files = Get-StaleFile -Path $script:root -Days 70

        $files.Name | Sort-Object | Should -Be @('LICENSE', 'notes.TXT', 'readme.txt')
        Should -Invoke -CommandName Get-Date -Times 1 -Exactly
    }

    It 'Should find nothing older than 365 days' {
        Get-StaleFile -Path $script:root -Days 365 | Should -BeNullOrEmpty
    }
}
```

```powershell
$result = Invoke-Pester -Path ./Get-StaleFile.Tests.ps1 -Output None -PassThru
$result.Tests | Select-Object -Property ExpandedName, Result
```

```text
ExpandedName                             Result
------------                             ------
Should find the files older than 70 days Passed
Should find nothing older than 365 days  Passed
```

The mock in `BeforeAll` applies to both tests, so the result doesn't change
with the real date. In an `It`, `Should -Invoke` counts only the calls of
that test.

</details>

## Key takeaways

- `Describe`, `Context`, and `It` structure the tests; `Should` checks one
  expectation, and its operators can be negated with `-Not`.
- Put all test code into `It` and the setup blocks: code directly in
  `Describe` runs during discovery.
- `$TestDrive` gives every test file a clean temporary folder.
- `-ForEach` turns one test into many, and `Mock` replaces commands such as
  `Get-Date`; use `-ModuleName` for commands called inside a module.
- In a Sampler project, run the tests through the build, which also runs the
  quality tests.

## Learn more

- [Pester quick start](https://pester.dev/docs/quick-start)
- [TestDrive](https://pester.dev/docs/usage/testdrive)
- [Pester on GitHub](https://github.com/pester/Pester)
- [Setup and teardown](https://pester.dev/docs/usage/setup-and-teardown)
- [Data driven tests](https://pester.dev/docs/usage/data-driven-tests)
- [Mocking with Pester](https://pester.dev/docs/usage/mocking)
  and [Unit testing within modules](https://pester.dev/docs/usage/modules)
- [Discovery and run](https://pester.dev/docs/usage/discovery-and-run)
- [Configuration](https://pester.dev/docs/usage/configuration)
- [Should-\* assertions (v6)](https://pester.dev/docs/assertions/should-command)
  and [classic assertions](https://pester.dev/docs/assertions/)

---

[← Previous: Scaffolding a module with Sampler](13-scaffolding-a-module-with-sampler.md)
· [Overview](../README.md) ·
[Next: Building with Sampler →](15-building-with-sampler.md)
