<!-- markdownlint-disable MD041 -->
![PowerShell and GitHub Copilot: workshop notes][banner]

These notes recap a workshop on PowerShell and GitHub Copilot, held over two
half days. One question runs through all of it: which file extensions occur
most often in a folder tree, and how much space do they use? The answer starts
as a one-liner in the console, becomes a function, and ends as a tested module
that a CI/CD pipeline builds and tests on every change.

Every topic recaps the demo, explains the background, and links to the
official documentation for further reading.

> [!TIP]
> All demos live in the sample project
> [FileManagementSample](https://github.com/raandree/FileManagementSample).
> Clone it and follow along, see [Before you start](#before-you-start).

[banner]: assets/banner.png

## Workshop at a glance

![Workshop roadmap in three parts: PowerShell fundamentals, from one-liners
to tools, and engineering practices](assets/diagrams/workshop-journey.svg)

## Contents

- [Before you start](#before-you-start)
- [Kick-off and experience check](#kick-off-and-experience-check)
- [Part 1: PowerShell fundamentals](#part-1-powershell-fundamentals)
  - [Everything is an object](#everything-is-an-object)
  - [The pipeline, loops, and filters](#the-pipeline-loops-and-filters)
  - [Building a pipeline step by step](#building-a-pipeline-step-by-step)
  - [Hashtables](#hashtables)
  - [PSCustomObject](#pscustomobject)
  - [CSV, JSON, and YAML](#csv-json-and-yaml)
  - [Inspecting and extending objects](#inspecting-and-extending-objects)
  - [Strings and the format operator](#strings-and-the-format-operator)
- [Part 2: From one-liners to tools](#part-2-from-one-liners-to-tools)
  - [Your first function](#your-first-function)
  - [Pipeline input](#pipeline-input)
  - [Splatting](#splatting)
- [Part 3: Engineering practices](#part-3-engineering-practices)
  - [Debugging in VS Code](#debugging-in-vs-code)
  - [Testing with Pester](#testing-with-pester)
  - [Building with Sampler](#building-with-sampler)
  - [CI/CD with GitHub Actions](#cicd-with-github-actions)
  - [GitHub Copilot in the demo project](#github-copilot-in-the-demo-project)
- [Next steps](#next-steps)
- [Further resources](#further-resources)
- [Glossary](#glossary)

## Before you start

To follow along, you need:

- [PowerShell 7][install-powershell]. The demo project also supports Windows
  PowerShell 5.1. The examples in these notes were tested with PowerShell 7.6.
- [Visual Studio Code](https://code.visualstudio.com/) with the
  [PowerShell extension][vscode-powershell].
- [Git](https://git-scm.com/downloads), and a GitHub account to run your own
  pipelines.

Clone the demo project and run its build once. The first command downloads
the build dependencies into `output/RequiredModules`; the second one builds
the module and runs all tests:

```powershell
git clone https://github.com/raandree/FileManagementSample.git
Set-Location -Path FileManagementSample
./build.ps1 -ResolveDependency -Tasks noop
./build.ps1
```

The examples use `D:\LabSources`, the AutomatedLab sources folder used in the
workshop. Replace it with any folder that contains files, such as
`$HOME\Downloads`.

[install-powershell]: https://learn.microsoft.com/powershell/scripting/install/install-powershell
[vscode-powershell]: https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell

## Kick-off and experience check

The workshop started with a round on everyone's experience. The same
questions make a good self-check afterwards. Each one points to the part of
these notes that covers it.

| Experience with …                          | Covered in                                                                                              |
|--------------------------------------------|---------------------------------------------------------------------------------------------------------|
| PowerShell scripting: one- and two-liners  | [Part 1: PowerShell fundamentals](#part-1-powershell-fundamentals)                                      |
| PowerShell programming: complete solutions | [Part 2: From one-liners to tools](#part-2-from-one-liners-to-tools)                                    |
| GitHub as a source control system          | [Before you start](#before-you-start), [CI/CD with GitHub Actions](#cicd-with-github-actions)           |
| CI/CD                                      | [Building with Sampler](#building-with-sampler), [CI/CD with GitHub Actions](#cicd-with-github-actions) |
| GitHub Copilot                             | [GitHub Copilot in the demo project](#github-copilot-in-the-demo-project)                               |
| Pester or other testing frameworks         | [Testing with Pester](#testing-with-pester)                                                             |

## Part 1: PowerShell fundamentals

### Everything is an object

PowerShell commands return .NET objects, not text. An object carries data in
its *properties* and actions in its *methods*, and `Get-Member` lists both.
The workshop explored this with a date:

```powershell
$now = Get-Date
$now | Get-Member                     # every property and method of a DateTime
$now.DayOfWeek                        # a property
$now.AddDays(30)                      # a method that returns a new DateTime
(Get-Date -Date '2026-12-24') - $now  # subtracting two dates returns a TimeSpan
```

The same skills apply to files and folders. `Get-ChildItem` returns `FileInfo`
and `DirectoryInfo` objects, and their properties are objects, too:
`LastWriteTime` is a `DateTime`, just like the one above.

```powershell
$file = Get-ChildItem -Path $PSHOME -File | Select-Object -First 1
$file | Get-Member                    # System.IO.FileInfo
$file.Length                          # the size in bytes
$file.LastWriteTime.DayOfWeek         # LastWriteTime is a DateTime
(Get-Date) - $file.LastWriteTime      # the age of the file as a TimeSpan
```

> [!TIP]
> New command? Pipe its output to `Get-Member` first. The property names it
> shows are exactly what you can filter, sort, and group by.

📖 Learn more:

- [about_Objects](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_objects)
- [Get-Member](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/get-member)
- [Get-ChildItem](https://learn.microsoft.com/powershell/module/microsoft.powershell.management/get-childitem)
- [DateTime struct](https://learn.microsoft.com/dotnet/api/system.datetime)
- [FileInfo class](https://learn.microsoft.com/dotnet/api/system.io.fileinfo)

### The pipeline, loops, and filters

The pipeline operator `|` passes objects from one command to the next, one at
a time. In the script blocks of `ForEach-Object` and `Where-Object`, the
automatic variable `$_` holds the current object. `$PSItem` is the same
variable with a longer, more readable name.

![Where-Object receives the numbers 1 to 10 one at a time, keeps 8, 9, and 10,
and drops the rest](assets/diagrams/dollar-underscore.svg)

```powershell
$a = 1..10
$a | ForEach-Object { "Test $_" }             # runs once for every number
$a | Where-Object { $_ -gt 7 }                # keeps 8, 9, and 10
$a | ForEach-Object { if ($_ -gt 7) { $_ } }  # same result, more code
```

`ForEach-Object` with an `if` can filter, too, but `Where-Object` states the
intent. Filter as early as possible, ideally with a parameter of the first
command, such as `Get-ChildItem -Filter *.log`. PowerShell 101 calls this
*filter left*. `Get-History` lists the commands of the current session, which
makes it easy to copy a working pipeline into a script.

> [!WARNING]
> An `else` branch needs the `else` keyword. In
> `ForEach-Object { if ($_ -gt 7) { $_ } {} }`, the trailing `{}` is a script
> block that PowerShell outputs for every number: you get 8, 9, and 10 plus
> ten script blocks.

📖 Learn more:

- [about_Pipelines](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_pipelines)
- [about_Automatic_Variables](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_automatic_variables)
- [ForEach-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/foreach-object)
  and [Where-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/where-object)
- [PowerShell 101: One-liners and the pipeline](https://learn.microsoft.com/powershell/scripting/learn/ps101/04-pipelines#filter-left)

### Building a pipeline step by step

The running example: find the five file extensions that occur most often in a
folder tree. Build such a pipeline one command at a time, and look at the
output after every step.

![The pipeline in five steps: Get-ChildItem, Group-Object, Sort-Object,
Select-Object, and Measure-Object](assets/diagrams/pipeline-top-extensions.svg)

1. Get all files, including the files in subfolders:

   ```powershell
   Get-ChildItem -Path D:\LabSources -Recurse -File
   ```

2. Group them by extension. `Group-Object` returns one `GroupInfo` object per
   extension: `Name` is the extension, `Count` the number of files, and
   `Group` holds the file objects themselves.

   ```powershell
   Get-ChildItem -Path D:\LabSources -Recurse -File |
       Group-Object -Property Extension
   ```

3. Sort the groups, the most files first:

   ```powershell
   Get-ChildItem -Path D:\LabSources -Recurse -File |
       Group-Object -Property Extension |
       Sort-Object -Property Count -Descending
   ```

4. Keep the first five, and store them for the next step:

   ```powershell
   $top5 = Get-ChildItem -Path D:\LabSources -Recurse -File |
       Group-Object -Property Extension |
       Sort-Object -Property Count -Descending |
       Select-Object -First 5
   $top5
   ```

5. Measure each group. `Measure-Object` adds up the `Length` of the files in
   `Group`:

   ```powershell
   $top5 | ForEach-Object { ($_.Group | Measure-Object -Property Length -Sum).Sum }
   ```

   The sizes come back as bare numbers, without the extension they belong to.
   To return both, the workshop took a short detour through hashtables and
   custom objects. The result is the function
   [Get-FileExtensionSize](#your-first-function).

The first working version in the workshop was this one-liner:

```powershell
dir -Path D:\LabSources\ -Recurse | Group-Object -Property Extension | Sort-Object -Property Count -Descending | Select-Object -First 5
```

Two differences from the steps above are worth knowing:

- Without `-File`, folders are counted, too. A folder named `sub.dir` shows up
  as the extension `.dir`.
- `dir` is an alias of `Get-ChildItem`. Aliases save typing in the console,
  but scripts should use full command and parameter names. PSScriptAnalyzer
  reports aliases with the rule *AvoidUsingCmdletAliases*.

> [!NOTE]
> `Group-Object` ignores case, so `.TXT` and `.txt` end up in the same group.
> Add `-CaseSensitive` to keep them apart.

📖 Learn more:

- [Group-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/group-object)
- [Sort-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/sort-object)
- [Select-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/select-object)
- [Measure-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/measure-object)
- [PSScriptAnalyzer rule AvoidUsingCmdletAliases](https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/rules/avoidusingcmdletaliases)

### Hashtables

A hashtable stores key-value pairs, and every key is unique:

```powershell
$p = @{ GivenName = 'John'; LastName = 'Doe'; Age = 40; Department = 'IT' }
$p.Remove('Department')
$p.Add('Age', 50)
```

```text
MethodInvocationException: Exception calling "Add" with "2" argument(s): "Item has already been added. Key in dictionary: 'Age'  Key being added: 'Age'"
```

To change a value, assign it: `$p.Age = 50` or `$p['Age'] = 50`. An
assignment adds the key when it is missing and overwrites the value when it
exists.

Hashtables are great for lookups and settings, but awkward as records. Here
are two people as hashtables:

```powershell
$p = @{ GivenName = 'John'; LastName = 'Doe'; Age = 40; Department = 'IT' },
     @{ GivenName = 'Susan'; LastName = 'Wang'; Age = 35; Department = 'HR' }
$p
```

```text
Name                           Value
----                           -----
Age                            40
LastName                       Doe
Department                     IT
GivenName                      John
Age                            35
LastName                       Wang
Department                     HR
GivenName                      Susan
```

PowerShell lists every key-value pair, and `$p | Format-Table -Property *`
only adds a `Key` column. Note the order, too: the keys don't come back in
the order you typed them. The order of a hashtable is not defined and can
change from one session to the next. When order matters, use `[ordered]@{}`.

📖 Learn more:

- [about_Hash_Tables](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_hash_tables)
- [Everything you wanted to know about hashtables](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-hashtable)

### PSCustomObject

`[pscustomobject]` turns the same hashtable syntax into a real object. The
properties keep their order, the output is a table, and it works with every
`*-Object` command, like any other object.

```powershell
$p = [pscustomobject]@{ GivenName = 'John'; LastName = 'Doe'; Age = 40; Department = 'IT' },
     [pscustomobject]@{ GivenName = 'Susan'; LastName = 'Wang'; Age = 35; Department = 'HR' }
$p
```

```text
GivenName LastName Age Department
--------- -------- --- ----------
John      Doe       40 IT
Susan     Wang      35 HR
```

```powershell
$p | Where-Object { $_.Age -gt 38 }
```

```text
GivenName LastName Age Department
--------- -------- --- ----------
John      Doe       40 IT
```

|                | Hashtable `@{}`                         | PSCustomObject `[pscustomobject]@{}`   |
|----------------|-----------------------------------------|----------------------------------------|
| What it is     | A collection of key-value pairs         | An object with properties              |
| Order          | Not defined; use `[ordered]` to keep it | The order in which you defined it      |
| Default output | One row per key-value pair              | A table or list of the properties      |
| Add an entry   | Assign it: `$h.NewKey = 'value'`        | `Add-Member`; plain assignment fails   |
| Typical use    | Lookups, settings, splatting            | Records, function output, CSV and JSON |

📖 Learn more:

- [about_PSCustomObject](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_pscustomobject)
- [Everything you wanted to know about PSCustomObject](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-pscustomobject)

### CSV, JSON, and YAML

`Import-Csv` turns every row of a CSV file into a `PSCustomObject`, and the
header row provides the property names. Everything you know about objects
applies:

```powershell
$p = Import-Csv -Path .\People.csv -Delimiter ';'
$p | Group-Object -Property Department
```

```text
Count Name                      Group
----- ----                      -----
   50 D                         {@{Surname=Akaka; GivenName=Daniel K.; Department=D; State=HI; Description=Class…
    1 I                         {@{Surname=Sanders; GivenName=Bernard; Department=I; State=VT; Description=Class…
   49 R                         {@{Surname=Alexander; GivenName=Lamar; Department=R; State=TN; Description=Class…
```

```powershell
$p | Where-Object { $_.Name -eq 'obama' }     # no result
$p | Where-Object { $_.Surname -eq 'obama' }  # one result
```

<details>
<summary>Output of the second command</summary>

```text
Surname        : Obama
GivenName      : Barack
Department     : D
State          : IL
Description    : Class III
StreetAddress  : 713 HART SENATE OFFICE BUILDING WASHINGTON DC 20510
OfficePhone    : (202) 224-2854
EmailAddress   : Web Form: obama.senate.gov/contact/
Name           : AObama
SamAccountName : Aobama
```

</details>

Two lessons from this demo:

- **Know your properties.** The first filter returned nothing because the
  `Name` column holds account names such as `AObama`; the surname is in
  `Surname`. Look at one object before you filter:
  `$p | Select-Object -First 1`.
- **String comparisons ignore case.** `'Obama' -eq 'obama'` is `$true`. Use
  `-ceq` for a case-sensitive comparison.

> [!CAUTION]
> Every value read from a CSV file is a string. PowerShell then compares text,
> not numbers: `'100' -gt 38` is `$false`, because `38` is converted to the
> string `'38'`. Convert before you compare: `[int]$_.Age -gt 38`.

JSON works the same way, and `ConvertFrom-Json` returns custom objects:

```powershell
$p | ConvertTo-Json | Set-Content -Path .\People.json
$people = Get-Content -Path .\People.json -Raw | ConvertFrom-Json
$people | Where-Object { $_.Department -eq 'D' }
```

`ConvertTo-Json` serializes two levels deep by default and warns when it cuts
off deeper data. Add `-Depth` for nested objects.

PowerShell has no built-in YAML commands. The `powershell-yaml` module from
the PowerShell Gallery adds `ConvertTo-Yaml` and `ConvertFrom-Yaml`. Its
`ConvertFrom-Yaml` returns hashtables, so convert each entry into an object.
With `-Ordered`, the properties keep the order of the YAML file:

```powershell
Install-Module -Name powershell-yaml -Scope CurrentUser
$p | ConvertTo-Yaml | Set-Content -Path .\People.yml
$people = ConvertFrom-Yaml -Yaml (Get-Content -Path .\People.yml -Raw) -Ordered
$people | ForEach-Object { [pscustomobject]$_ } | Where-Object { $_.Department -eq 'D' }
```

`ConvertFrom-Yaml` returns a YAML list as one single object, which is why the
result goes into a variable first: piping the variable sends the entries one
by one.

📖 Learn more:

- [Import-Csv](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/import-csv)
  and [Export-Csv](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/export-csv)
- [ConvertFrom-Json](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/convertfrom-json)
  and [ConvertTo-Json](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/convertto-json)
- [powershell-yaml in the PowerShell Gallery](https://www.powershellgallery.com/packages/powershell-yaml)
- [about_Comparison_Operators](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_comparison_operators)

### Inspecting and extending objects

`Get-Member` shows what an object is made of. The properties of a
`PSCustomObject` are *NoteProperties*: static values attached to the object.

```powershell
$p = [pscustomobject]@{ GivenName = 'John'; LastName = 'Doe'; Age = 40; Department = 'IT' }
$p | Get-Member
```

<details>
<summary>Output</summary>

```text
   TypeName: System.Management.Automation.PSCustomObject

Name        MemberType   Definition
----        ----------   ----------
Equals      Method       bool Equals(System.Object obj)
GetHashCode Method       int GetHashCode()
GetType     Method       type GetType()
ToString    Method       string ToString()
Age         NoteProperty int Age=40
Department  NoteProperty string Department=IT
GivenName   NoteProperty string GivenName=John
LastName    NoteProperty string LastName=Doe
```

</details>

`Add-Member` extends an object. A *NoteProperty* adds a value; a
*ScriptProperty* adds a computed value, evaluated every time you read it.
Inside its script block, `$this` is the object itself.

```powershell
$p | Add-Member -Name Gender -MemberType NoteProperty -Value M
$p | Add-Member -Name FullName -MemberType ScriptProperty -Value {
    "$($this.GivenName) $($this.LastName)"
}
$p
```

```text
GivenName  : John
LastName   : Doe
Age        : 40
Department : IT
Gender     : M
FullName   : John Doe
```

Three details worth knowing:

- **Table or list?** For objects without a predefined view, PowerShell shows a
  table for up to four properties and a list for five or more. That is why
  the output switched to a list after adding `Gender`.
- **Always current.** A ScriptProperty is computed on every access. After
  `$p.GivenName = 'Jane'`, `$p.FullName` returns `Jane Doe`.
- **Subexpressions in strings.** Inside double quotes, `$($this.GivenName)`
  needs the subexpression `$()`. Without it, PowerShell expands only `$this`
  and appends `.GivenName` as plain text.

📖 Learn more:

- [Add-Member](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/add-member)
- [about_Automatic_Variables: $this](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_automatic_variables#this)
- [PowerShell 101: Discovering objects](https://learn.microsoft.com/powershell/scripting/learn/ps101/03-discovering-objects#properties)

### Strings and the format operator

Single-quoted strings are *verbatim*: PowerShell prints them exactly as typed.
Double-quoted strings are *expandable*: PowerShell replaces variables with
their values. The backtick `` ` `` is the escape character.

```text
PS> $a = 5
PS> '$a is $a'
$a is $a
PS> "$a is $a"
5 is 5
PS> '$a is' + "$a"
$a is5
PS> '$a is ' + "$a"
$a is 5
PS> "`$a is $a"
$a is 5
PS> "`$a is `n $a"
$a is
 5
PS> "`$a is `n `x $a"
$a is
 x 5
PS> "`$a is `n `t $a"
$a is
         5
```

| Escape sequence | Result                                      |
|-----------------|---------------------------------------------|
| `` `n ``        | New line                                    |
| `` `t ``        | Horizontal tab                              |
| `` `$ ``        | A literal `$`, no variable expansion        |
| `` `" ``        | A literal double quote inside double quotes |
| `` `x ``        | No escape sequence: the backtick is dropped |

> [!TIP]
> Use single quotes unless you need expansion or escape sequences. It makes
> the intent clear. PSScriptAnalyzer can check it with the optional rule
> *AvoidUsingDoubleQuotesForConstantString*, which is off by default.

The format operator `-f` fills numbered placeholders with the values on its
right side: `{0}` is the first value, `{1}` the second. After a colon, a
format string controls how the value is shown. The template below is in
single quotes, so `$a` stays literal text while the placeholders are filled.

```text
PS> '$a is {0}' -f $a
$a is 5
PS> '$a is {0} x {1}' -f $a, 'Test'
$a is 5 x Test
PS> '$a is {0} at {1}' -f $a, (Get-Date)
$a is 5 at 11/17/2026 9:27:29 AM
PS> '$a is {0} at {1:yyMMdd}' -f $a, (Get-Date)
$a is 5 at 261117
PS> '$a is {0:D2} at {1:yyMMdd}' -f $a, (Get-Date)
$a is 05 at 261117
PS> '$a is {0:D4} at {1:yyMMdd}' -f $a, (Get-Date)
$a is 0005 at 261117
PS> $a = 678
PS> '$a is {0:D4} at {1:yyMMdd}' -f $a, (Get-Date)
$a is 0678 at 261117
```

| Format       | Example                                          | Result                       |
|--------------|--------------------------------------------------|------------------------------|
| `D3`         | `'Server{0:D3}' -f 7`                            | `Server007`                  |
| `N2`         | `'{0:N2}' -f 1234.5678`                          | `1,234.57` with en-US        |
| `yyyy-MM-dd` | `'{0:yyyy-MM-dd HH:mm}' -f (Get-Date)`           | `2026-11-17 09:27`           |
| Timestamp    | `'Report_{0:yyyyMMdd_HHmmss}.csv' -f (Get-Date)` | `Report_20261117_092729.csv` |

> [!WARNING]
> In date formats, `MM` is the month and `mm` the minute. Also, `-f` uses .NET
> composite formatting, which formats with the current culture: on a German
> system, `'{0}' -f (Get-Date)` returns `17.11.2026 09:27:29`. Expandable
> strings use the invariant culture, so `"$(Get-Date)"` always returns
> `11/17/2026 09:27:29`.

📖 Learn more:

- [about_Quoting_Rules](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_quoting_rules)
  and its section on
  [culture settings](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_quoting_rules#culture-settings-affect-string-interpretation)
- [about_Special_Characters](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_special_characters)
- [about_Operators: format operator](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_operators#format-operator--f)
- [Everything you wanted to know about variable substitution in strings](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-string-substitutions)
- [Composite formatting](https://learn.microsoft.com/dotnet/standard/base-types/composite-formatting),
  [standard numeric format strings](https://learn.microsoft.com/dotnet/standard/base-types/standard-numeric-format-strings),
  and [custom date and time format strings](https://learn.microsoft.com/dotnet/standard/base-types/custom-date-and-time-format-strings)

## Part 2: From one-liners to tools

### Your first function

The workshop turned the pipeline into a function with mandatory, typed
parameters and a clean output object, one per extension:

```powershell
function Get-FileExtensionSize {
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [int]$Top
    )

    $fileGroups = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
        Group-Object -Property Extension |
        Sort-Object -Property Count -Descending |
        Select-Object -First $Top

    $fileGroups | ForEach-Object {
        $_ | Add-Member -Name Size -MemberType NoteProperty -Value ($_.Group | Measure-Object -Property Length -Sum).Sum
    }

    $fileGroups | ForEach-Object {
        [PSCustomObject]@{
            Extension     = $_.Name
            FileCount     = $_.Count
            TotalFileSize = $_.Size / 1GB
        }
    }
}
```

| Element                         | Why it is there                                                                        |
|---------------------------------|----------------------------------------------------------------------------------------|
| `Get-` verb                     | Approved verbs make commands predictable and discoverable; `Get-Verb` lists them       |
| `[Parameter(Mandatory)]`        | PowerShell prompts for a missing value instead of running with an empty one            |
| `[string]`, `[int]`             | PowerShell converts the input or fails early: `-Top 'many'` stops before the code runs |
| `-ErrorAction SilentlyContinue` | Folders without access don't flood the console with errors                             |
| `Add-Member`                    | Attaches the total size to each group                                                  |
| `[PSCustomObject]@{}`           | One clean object per extension, ready for `Sort-Object`, `Export-Csv`, and friends     |

```powershell
Get-FileExtensionSize -Path D:\LabSources -Top 5
Get-FileExtensionSize -Path $HOME -Top 10 | Sort-Object -Property TotalFileSize -Descending
```

In the demo project, the function also got comment-based help,
`[CmdletBinding()]`, and `[OutputType()]`. See
[Get-FileExtensionSize.ps1][fms-get-fileextensionsize] for the full version:

```powershell
function Get-FileExtensionSize
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $Top
    )
    # ... same body as above
}
```

- `[CmdletBinding()]` makes it an *advanced function* that works like a
  compiled cmdlet, including the common parameters such as `-Verbose` and
  `-ErrorAction`.
- `[OutputType()]` declares what the function returns. Help, `Get-Command`,
  and tab completion use it, but PowerShell doesn't compare it with the
  actual output.
- The comment-based help makes `Get-Help Get-FileExtensionSize -Full` work.
- `[Parameter(Mandatory)]` is the short form of
  `[Parameter(Mandatory = $true)]`, the style the demo project uses.

> [!TIP]
> Try it yourself: round `TotalFileSize` to two decimals with
> `[math]::Round()`, rank the extensions by size instead of by count, or
> reject unreasonable values with `[ValidateRange(1, 100)]` on `-Top`.

📖 Learn more:

- [about_Functions](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions)
  and [about_Functions_Advanced](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_advanced)
- [about_Functions_CmdletBindingAttribute](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute)
- [about_Functions_OutputTypeAttribute](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_outputtypeattribute)
- [about_Comment_Based_Help](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_comment_based_help)
- [Approved verbs for PowerShell commands](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)

[fms-get-fileextensionsize]: https://github.com/raandree/FileManagementSample/blob/main/source/Public/Get-FileExtensionSize.ps1

### Pipeline input

A function that accepts pipeline input fits naturally into a pipeline. The
demo project shows `ValueFromPipeline`; its sibling
`ValueFromPipelineByPropertyName` is just as useful. Here is how PowerShell
decides which parameter receives an object from the pipeline:

![How PowerShell binds pipeline input: first by value, then by property name,
otherwise an error](assets/diagrams/parameter-binding.svg)

The diagram simplifies the rules a little: PowerShell first tries both kinds
of binding without type conversion, and only then with type conversion.

- **By value** (`ValueFromPipeline`): the whole object becomes the parameter
  value, as long as its type fits. Strings bind to `-Path`:
  `'C:\Logs', 'D:\Backups' | Get-LargestFile -Top 3`.
- **By property name** (`ValueFromPipelineByPropertyName`): PowerShell takes
  the property of the input object whose name matches the parameter name or
  one of its aliases. Folder objects from `Get-ChildItem` have a `PSPath`
  property, which binds to `-LiteralPath` through the alias `PSPath`.

This is the parameter block of [Get-LargestFile][fms-get-largestfile]:

```powershell
param
(
    [Parameter(ParameterSetName = 'Path', Mandatory = $true, Position = 0,
               ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [SupportsWildcards()]
    [System.String[]]
    $Path,

    [Parameter(ParameterSetName = 'LiteralPath', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('PSPath')]
    [System.String[]]
    $LiteralPath,

    [Parameter(Mandatory = $true, Position = 1)]
    [System.Int32]
    $Top
)
```

`ValueFromPipelineByPropertyName` connects functions to data. The function
below accepts the people from the CSV file and the custom objects from
[Part 1](#pscustomobject) alike, because the property names match:

```powershell
function Get-Greeting {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$GivenName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('LastName')]
        [string]$Surname
    )

    process {
        "Hello $GivenName $Surname"
    }
}

Import-Csv -Path .\People.csv -Delimiter ';' | Get-Greeting    # uses Surname
[pscustomobject]@{ GivenName = 'John'; LastName = 'Doe' } | Get-Greeting  # alias LastName
```

> [!IMPORTANT]
> Pipeline input needs a `process` block. Without one, the code runs once at
> the end, and only the last object is processed: `1, 2, 3 | Test-NoProcess`
> returns `Got 3` only.
>
> ```powershell
> function Test-NoProcess { param ([Parameter(ValueFromPipeline)][int]$Number) "Got $Number" }
> function Test-Process { param ([Parameter(ValueFromPipeline)][int]$Number) process { "Got $Number" } }
> ```

To watch the binding happen, trace it:
`Trace-Command -Name ParameterBinding -PSHost -Expression { ... }`.

📖 Learn more:

- [about_Functions_Advanced_Parameters](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)
- [about_Parameter_Binding](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_parameter_binding)
- [about_Functions: input processing methods](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions#input-processing-methods)
- [Trace-Command](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/trace-command)

[fms-get-largestfile]: https://github.com/raandree/FileManagementSample/blob/main/source/Public/Get-LargestFile.ps1

### Splatting

Splatting passes parameters as a hashtable: build the hashtable, then call
the command with `@` instead of `$`.

```powershell
$params = @{
    Path        = 'D:\LabSources'
    Recurse     = $true
    File        = $true
    ErrorAction = 'SilentlyContinue'
}
Get-ChildItem @params
```

- **Readable:** one parameter per line, no long lines, and no backtick line
  continuations.
- **Dynamic:** add a parameter only when you need it:
  `if ($Filter) { $params.Filter = $Filter }`.
- **Reusable:** pass the same set of parameters to several commands.

`Get-LargestFile` in the demo project goes one step further and computes the
parameter name itself. It splats either `-Path` or `-LiteralPath`, depending
on how the folder arrived:

```powershell
$getChildItemParameters = @{
    $pathParameterName = $searchPath
    Recurse            = $true
    File               = $true
    ErrorAction        = 'SilentlyContinue'
}

Get-ChildItem @getChildItemParameters
```

📖 Learn more:

- [about_Splatting](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_splatting)

## Part 3: Engineering practices

### Debugging in VS Code

The debugger finds bugs, but it is just as valuable for understanding code
you didn't write: stop at a line, look at the variables, and step through.

| Concept              | What it does                                               | Where to find it                     |
|----------------------|------------------------------------------------------------|--------------------------------------|
| Launch configuration | Defines what starts when you press F5                      | `.vscode/launch.json`                |
| Breakpoint           | Pauses at a line; optionally only when a condition is true | Click left of the line number, or F9 |
| Call stack           | Shows how execution got to the current line                | Run and Debug view                   |
| Variables            | Shows the values in the current scope                      | Run and Debug view                   |
| Watch                | Evaluates expressions of your choice at every stop         | Run and Debug view                   |
| Debug console        | Runs commands in the paused session                        | Debug Console panel                  |

The demo project ships two launch configurations: one debugs the current
file, the other an interactive session.

```json
{
    "name": "PowerShell Interactive Session",
    "type": "PowerShell",
    "request": "launch",
    "cwd": "${cwd}"
},
{
    "name": "PowerShell: Launch Current File",
    "type": "PowerShell",
    "request": "launch",
    "script": "${file}",
    "args": []
}
```

| Key       | Action            |
|-----------|-------------------|
| F5        | Start or continue |
| F9        | Toggle breakpoint |
| F10       | Step over         |
| F11       | Step into         |
| Shift+F11 | Step out          |
| Shift+F5  | Stop              |

📖 Learn more:

- [Using Visual Studio Code for PowerShell development](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/vscode/using-vscode)
- [Debugging in VS Code](https://code.visualstudio.com/docs/debugtest/debugging)
- [about_Debuggers](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_debuggers)

### Testing with Pester

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

The tests create their sample files in `$TestDrive`, a temporary folder that
Pester cleans up automatically. Besides these unit tests, the demo project
runs quality tests from `tests/QA/module.tests.ps1`. They fail the build when
a public function has no unit test, fails PSScriptAnalyzer, or lacks help: a
synopsis, a description, an example, and a description for every parameter.
They also check that the changelog follows the *Keep a Changelog* format.

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

📖 Learn more:

- [Pester quick start](https://pester.dev/docs/quick-start)
- [TestDrive](https://pester.dev/docs/usage/testdrive)
- [Pester on GitHub](https://github.com/pester/Pester)

### Building with Sampler

Sampler is a template and build framework for PowerShell modules. Its
`build.yaml` defines *workflows*: named lists of tasks, much like the stages
and jobs of Azure DevOps or GitHub Actions. The difference is that
`build.ps1` runs the same way on your machine, so you can debug every step of
the build locally.

![Your machine and the CI runner both call build.ps1, which reads build.yaml
and runs the build and test workflows](assets/diagrams/sampler-build.svg)

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

The build enforces the tests:

- `Pester_Tests_Stop_On_Fail` stops the build as soon as one test fails.
- `Pester_if_Code_Coverage_Under_Threshold` fails the build when the code
  coverage is below `CoveragePercentTarget` in `build.yaml`. The demo project
  sets it to `0`, which turns the check off.

Tasks are Invoke-Build tasks, so adding your own step is easy. `Task1` in the
`build` workflow is a custom task from `.build/Task1.ps1`:

```powershell
task Task1 {
    Get-Date
}
```

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

📖 Learn more:

- [Sampler](https://github.com/gaelcolas/Sampler)
- [Invoke-Build](https://github.com/nightroman/Invoke-Build)
- [ModuleBuilder](https://github.com/PoshCode/ModuleBuilder)

### CI/CD with GitHub Actions

The workflow `.github/workflows/ci.yml` of the demo project runs the same
`build.ps1` in GitHub Actions for every push and pull request:

![The CI pipeline: package the module, test it on four platforms, summarize
the results, and deploy](assets/diagrams/ci-pipeline.svg)

1. **Package Module:** GitVersion calculates the version from the Git
   history, `build.ps1` builds and packages the module, and the `output`
   folder becomes a build artifact.
2. **Test:** a matrix runs the tests against this artifact on Ubuntu, on
   Windows with PowerShell 7 and with Windows PowerShell 5.1, and on macOS.
3. **Test Results:** collects the results of all platforms and writes a
   summary to the summary page of the run.
4. **Deploy Module:** runs for pushes to `main` and for version tags. The
   publish tasks skip themselves, because no API key is configured yet.

This is the [run of 17 November 2026][fms-ci-run]:

![The GitHub Actions run: Package Module, four test jobs, Test Results, and
Deploy Module all succeeded](assets/screenshots/ci-run-graph.png)

| Platform       | Shell                  | Passed | Failed |
|----------------|------------------------|-------:|-------:|
| ubuntu-latest  | PowerShell 7           |     52 |      0 |
| windows-latest | PowerShell 7           |     52 |      0 |
| windows-latest | Windows PowerShell 5.1 |     52 |      0 |
| macos-latest   | PowerShell 7           |     52 |      0 |

To publish for real, add two repository secrets under **Settings** >
**Secrets and variables** > **Actions**:

| Secret            | Used for                                                                 |
|-------------------|--------------------------------------------------------------------------|
| `GalleryApiToken` | The PowerShell Gallery API key that publishes the module                 |
| `GitHubToken`     | A personal access token that creates the GitHub release and changelog PR |

> [!NOTE]
> Every job calls `build.ps1`. When the pipeline fails, run the same command
> on your machine and debug it there.

📖 Learn more:

- [GitHub Actions documentation](https://docs.github.com/actions)
- [Running variations of jobs in a workflow (matrix)](https://docs.github.com/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations)
- [Using secrets in GitHub Actions](https://docs.github.com/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)
- [Adding a job summary](https://docs.github.com/actions/reference/workflows-and-actions/workflow-commands#adding-a-job-summary)
- [Managing API keys for the PowerShell Gallery](https://learn.microsoft.com/powershell/gallery/how-to/managing-profile/creating-apikeys)
- [GitVersion](https://gitversion.net/)

[fms-ci-run]: https://github.com/raandree/FileManagementSample/actions/runs/44084182216

### GitHub Copilot in the demo project

The demo project is prepared for GitHub Copilot. These files give Copilot the
conventions of the project, so its suggestions follow them:

| File or folder                           | What it tells Copilot                                                                                                     |
|------------------------------------------|---------------------------------------------------------------------------------------------------------------------------|
| `.github/copilot-instructions.md`        | Rules for the whole repository: run every build and test through `./build.ps1`, and leave all Git operations to the user  |
| `.github/instructions/*.instructions.md` | Rules for specific files, selected by `applyTo`. For example, `source/Public/**/*.ps1` requires help and `[OutputType()]` |
| `.github/skills/*/SKILL.md`              | Skills: procedures Copilot loads when a task needs them, such as `validate-changes`, which picks the right test scope     |
| `.memory-bank/`                          | Project knowledge in Markdown that outlasts a chat session; `index.md` routes each task to the files it needs             |

📖 Learn more:

- [GitHub Copilot documentation](https://docs.github.com/copilot)
- [Adding repository custom instructions for GitHub Copilot](https://docs.github.com/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)
- [Agent skills in VS Code](https://code.visualstudio.com/docs/agent-customization/agent-skills)

## Next steps

Open from the workshop:

- [ ] Ask the trainer for the `ZfFileManagementModule`, so that its module
  files can be added to the repository.

Suggested practice:

- [ ] Clone FileManagementSample, run `./build.ps1`, and step through
  `Get-FileExtensionSize` in the debugger.
- [ ] Break a test on purpose, run `./build.ps1 -Tasks test`, and read the
  failure.
- [ ] Add `ValueFromPipelineByPropertyName` to a function of your own.
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

| Term               | Meaning                                                                                  |
|--------------------|------------------------------------------------------------------------------------------|
| Advanced function  | A function with `[CmdletBinding()]` that behaves like a compiled cmdlet                  |
| Artifact           | A file or folder that a pipeline job stores for later jobs, such as the built module     |
| CI/CD              | Continuous integration and delivery: build, test, and release automatically on change    |
| Hashtable          | A collection of unique keys and their values                                             |
| Method             | An action an object can perform, such as `AddDays()` on a `DateTime`                     |
| Object             | Data plus behavior; every PowerShell command returns objects                             |
| Pester             | The test and mock framework for PowerShell                                               |
| Pipeline           | Commands joined with `\|`; objects flow from left to right, one at a time                |
| Property           | A named value of an object, such as `Length` of a file                                   |
| PSCustomObject     | An object you create on the fly from a hashtable literal                                 |
| Runner             | The machine that executes a GitHub Actions job                                           |
| Sampler            | A template and build framework for PowerShell modules                                    |
| Splatting          | Passing parameters as a hashtable with `@` instead of `$`                                |
| `$_` and `$PSItem` | The current object in the pipeline                                                       |
| Workflow           | In Sampler, a named list of build tasks; in GitHub Actions, an automated process in YAML |
