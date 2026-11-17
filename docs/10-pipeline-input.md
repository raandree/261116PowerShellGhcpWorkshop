# Pipeline input

[Overview](../README.md) › Part 2: From one-liners to tools › Topic 10 of 17

A function that accepts pipeline input works like a built-in cmdlet: you can
pipe files, folders, or rows of a CSV file straight into it. This topic shows
how PowerShell decides which parameter receives an object, why such a
function needs a `process` block, and how to watch the binding happen.

In this topic, you learn to:

- accept pipeline input by value and by property name
- process each object in a `process` block, with `begin` and `end` around it
- accept arrays both as a parameter and from the pipeline
- connect functions to data with parameter aliases
- trace parameter binding with `Trace-Command`

## How PowerShell binds pipeline input

A function that accepts pipeline input fits naturally into a pipeline. The
demo project shows `ValueFromPipeline`; its sibling
`ValueFromPipelineByPropertyName` is just as useful. Here is how PowerShell
decides which parameter receives an object from the pipeline:

![How PowerShell binds pipeline input: first by value, then by property name,
otherwise an error](../assets/diagrams/parameter-binding.svg)

The diagram simplifies the rules a little: PowerShell first tries both kinds
of binding without type conversion, and only then with type conversion.

- **By value** (`ValueFromPipeline`): the whole object becomes the parameter
  value, as long as its type fits. Strings bind to `-Path`:
  `'C:\Logs', 'D:\Backups' | Get-LargestFile -Top 3`.
- **By property name** (`ValueFromPipelineByPropertyName`): PowerShell takes
  the property of the input object whose name matches the parameter name or
  one of its aliases. Folder objects from `Get-ChildItem` have a `PSPath`
  property, which binds to `-LiteralPath` through the alias `PSPath`.

*Binding* means assigning a value to a parameter. PowerShell binds the
named and positional arguments of the command line first. Then, for every
object that arrives through the pipeline, it tries four steps in this order:
by value without conversion, by property name without conversion, by value
with conversion, and by property name with conversion.

## The parameter block of Get-LargestFile

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

- `-Path` and `-LiteralPath` belong to different *parameter sets*, so a call
  uses one of them, never both. The function asks
  `$PSCmdlet.ParameterSetName` which one it received.
- `-Path` accepts wildcards, as `[SupportsWildcards()]` documents.
  `-LiteralPath` takes the path exactly as it is, so a folder named
  `Logs [2025]` works.
- `Position = 0` and `Position = 1` allow calls without parameter names:
  `Get-LargestFile C:\Logs 3`.
- `[System.String[]]` accepts several paths at once.

## Bind by property name

`ValueFromPipelineByPropertyName` connects functions to data. The function
below accepts the people from the CSV file and the custom objects from
[PSCustomObject](05-pscustomobject.md) alike, because the property names
match:

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

With the sample data from this repository, the first five greetings are:

```powershell
Import-Csv -Path ./samples/People.csv -Delimiter ';' | Get-Greeting | Select-Object -First 5
```

```text
Hello John Doe
Hello Sofia Rossi
Hello Liam Novak
Hello Noah Kim
Hello Zoe Tanaka
```

`People.csv` has nine columns, and `Get-Greeting` uses two of them. The
other properties don't matter: binding by property name only looks for the
names it needs.

## The process block

> [!IMPORTANT]
> Pipeline input needs a `process` block. Without one, the code runs once at
> the end, and only the last object is processed: `1, 2, 3 | Test-NoProcess`
> returns `Got 3` only.
>
> ```powershell
> function Test-NoProcess { param ([Parameter(ValueFromPipeline)][int]$Number) "Got $Number" }
> function Test-Process { param ([Parameter(ValueFromPipeline)][int]$Number) process { "Got $Number" } }
> ```

Try both functions:

```powershell
1, 2, 3 | Test-NoProcess
```

```text
Got 3
```

```powershell
1, 2, 3 | Test-Process
```

```text
Got 1
Got 2
Got 3
```

## Begin, process, and end

A function can have three blocks, and each runs at a different time:

- `begin` runs once, before the first object arrives. Prepare counters or
  connections here.
- `process` runs once for every object from the pipeline. Without pipeline
  input, it runs exactly once.
- `end` runs once, after the last object. Return totals or clean up here.

```powershell
function Show-Block {
    param ([Parameter(ValueFromPipeline)][int]$Number)
    begin { 'begin' }
    process { "process $Number" }
    end { 'end' }
}
1..3 | Show-Block
```

```text
begin
process 1
process 2
process 3
end
```

```powershell
Show-Block -Number 5
```

```text
begin
process 5
end
```

The blocks shine when a function aggregates its input. The following
function counts the files that it receives and adds up their sizes. Create
the sample folder first, if you haven't yet:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force

function Measure-SampleFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.IO.FileInfo]$File
    )

    begin {
        $count = 0
        $totalBytes = 0
    }

    process {
        $count++
        $totalBytes += $File.Length
    }

    end {
        [PSCustomObject]@{
            Files      = $count
            TotalBytes = $totalBytes
        }
    }
}

Get-ChildItem -Path $root -Recurse -File | Measure-SampleFile
```

```text
Files TotalBytes
----- ----------
   22    2302856
```

The variables from `begin` live on through all `process` runs until `end`.
Since PowerShell 7.3, a fourth block, `clean`, runs at the very end, even
when the pipeline stops with an error.

## Arrays as a parameter and from the pipeline

`[string[]]` lets a parameter take several values. The values arrive in two
different ways, though. On the command line, `process` runs once, and the
parameter holds all values. From the pipeline, `process` runs once per value,
and the parameter holds one. A `foreach` loop inside `process` handles both
cases:

```powershell
function Get-FolderFileCount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Path
    )

    process {
        foreach ($folder in $Path) {
            [PSCustomObject]@{
                Folder = Split-Path -Path $folder -Leaf
                Files  = @(Get-ChildItem -Path $folder -Recurse -File).Count
            }
        }
    }
}

$logs = Join-Path -Path $root -ChildPath 'logs'
$data = Join-Path -Path $root -ChildPath 'data'
Get-FolderFileCount -Path $logs, $data
```

```text
Folder Files
------ -----
logs       6
data       4
```

```powershell
$logs, $data | Get-FolderFileCount
```

```text
Folder Files
------ -----
logs       6
data       4
```

Both calls return the same objects. Without the `foreach` loop, the first
call would return a single object for both folders together, with 10 files.

## Aliases connect different names

An *alias* is a second name for a parameter. It works on the command line,
`Get-Greeting -GivenName John -LastName Doe`, and it counts for binding by
property name. That is how `Get-Greeting` accepts objects with a `LastName`
property. To find out which property names a command accepts, read the
aliases of its parameters:

```powershell
(Get-Command -Name Get-Greeting).Parameters['Surname'].Aliases
(Get-Command -Name Get-ChildItem).Parameters['LiteralPath'].Aliases
```

```text
LastName
PSPath
LP
```

Built-in cmdlets use the same trick: every item from `Get-ChildItem` carries
a `PSPath` property, and the alias `PSPath` binds it to `-LiteralPath` of the
next command. That is why `Get-ChildItem | Remove-Item` deletes exactly the
items it received, even when their names contain wildcard characters.

## Watch the binding with Trace-Command

To watch the binding happen, trace it:
`Trace-Command -Name ParameterBinding -PSHost -Expression { ... }`.
`-PSHost` sends the trace to the host, that is, to your console. Trace the
greeting for the first person of the CSV file:

```powershell
$person = (Import-Csv -Path ./samples/People.csv -Delimiter ';')[0]
Trace-Command -Name ParameterBinding -PSHost -Expression { $person | Get-Greeting }
```

The trace is long. This excerpt shows how the pipeline object binds:

```text
DEBUG: 2026-11-17 21:14:09.2882 ParameterBinding Information: 0 : BIND PIPELINE object to parameters: [Get-Greeting]
DEBUG: 2026-11-17 21:14:09.2883 ParameterBinding Information: 0 :     PIPELINE object TYPE = [System.Management.Automation.PSCustomObject]
DEBUG: 2026-11-17 21:14:09.2884 ParameterBinding Information: 0 :     RESTORING pipeline parameter's original values
DEBUG: 2026-11-17 21:14:09.2885 ParameterBinding Information: 0 :     Parameter [Surname] PIPELINE INPUT ValueFromPipelineByPropertyName NO COERCION
DEBUG: 2026-11-17 21:14:09.2886 ParameterBinding Information: 0 :     BIND arg [Doe] to parameter [Surname]
DEBUG: 2026-11-17 21:14:09.2886 ParameterBinding Information: 0 :         Executing DATA GENERATION metadata: [System.Management.Automation.ArgumentTypeConverterAttribute]
DEBUG: 2026-11-17 21:14:09.2886 ParameterBinding Information: 0 :             result returned from DATA GENERATION: Doe
DEBUG: 2026-11-17 21:14:09.2887 ParameterBinding Information: 0 :         BIND arg [Doe] to param [Surname] SUCCESSFUL
DEBUG: 2026-11-17 21:14:09.2887 ParameterBinding Information: 0 :     Parameter [GivenName] PIPELINE INPUT ValueFromPipelineByPropertyName NO COERCION
DEBUG: 2026-11-17 21:14:09.2887 ParameterBinding Information: 0 :     BIND arg [John] to parameter [GivenName]
DEBUG: 2026-11-17 21:14:09.2888 ParameterBinding Information: 0 :         Executing DATA GENERATION metadata: [System.Management.Automation.ArgumentTypeConverterAttribute]
DEBUG: 2026-11-17 21:14:09.2888 ParameterBinding Information: 0 :             result returned from DATA GENERATION: John
DEBUG: 2026-11-17 21:14:09.2888 ParameterBinding Information: 0 :         BIND arg [John] to param [GivenName] SUCCESSFUL
```

Read it from the top: the object is a `PSCustomObject`, both parameters bind
`ValueFromPipelineByPropertyName` with `NO COERCION`, that is, without type
conversion, and both bindings are `SUCCESSFUL`. When a binding fails, the
trace shows the step at which PowerShell gave up.

## Common pitfalls

- **No `process` block.** A pipeline-aware function without `process` works
  in a test with one object and silently drops all but the last object in
  production. Give every function with `ValueFromPipeline` or
  `ValueFromPipelineByPropertyName` a `process` block.

- **Pipeline parameters in `begin`.** Pipeline input isn't bound yet when
  `begin` runs. An `[int]` parameter reads `0` there:

  ```powershell
  function Test-Begin {
      param ([Parameter(ValueFromPipeline)][int]$Number)
      begin { "begin sees [$Number]" }
      process { "process sees [$Number]" }
  }
  1, 2 | Test-Begin
  ```

  ```text
  begin sees [0]
  process sees [1]
  process sees [2]
  ```

- **Property names that don't match.** When no property matches a parameter
  name or alias, PowerShell can't bind the object, and every object fails:

  ```powershell
  function Get-FirstName {
      param ([Parameter(ValueFromPipelineByPropertyName)][string]$FirstName)
      process { "First name: $FirstName" }
  }
  Import-Csv -Path ./samples/People.csv -Delimiter ';' | Select-Object -First 1 | Get-FirstName
  ```

  ```text
  Get-FirstName:
  Line |
     5 |  … es/People.csv -Delimiter ';' | Select-Object -First 1 | Get-FirstName
       |                                                            ~~~~~~~~~~~~~
       | The input object cannot be bound to any parameters for the command either because the command does not take pipeline input or the input and its properties do not match any of the parameters that take pipeline input.
  ```

  Add `[Alias('GivenName')]` to the parameter, or rename the property on the
  way with a calculated property:

  ```powershell
  Import-Csv -Path ./samples/People.csv -Delimiter ';' | Select-Object -First 1 |
      Select-Object -Property @{ Name = 'FirstName'; Expression = { $_.GivenName } } |
      Get-FirstName
  ```

  ```text
  First name: John
  ```

- **Parameter sets that PowerShell can't resolve.** An object with both a
  `Name` and an `Id` property fits two parameter sets at once:

  ```powershell
  function Get-Thing {
      [CmdletBinding()]
      param (
          [Parameter(ParameterSetName = 'ByName', ValueFromPipelineByPropertyName)]
          [string]$Name,

          [Parameter(ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
          [int]$Id
      )
      process { "$($PSCmdlet.ParameterSetName): $Name$Id" }
  }
  [pscustomobject]@{ Name = 'Report'; Id = 7 } | Get-Thing
  ```

  ```text
  Get-Thing:
  Line |
    12 |  [pscustomobject]@{ Name = 'Report'; Id = 7 } | Get-Thing
       |                                                 ~~~~~~~~~
       | Parameter set cannot be resolved using the specified named parameters. One or more parameters issued cannot be used together or an insufficient number of parameters were provided.
  ```

  `[CmdletBinding(DefaultParameterSetName = 'ByName')]` tells PowerShell
  which set to use when it can't decide, just like `Get-LargestFile` does.

## Exercises

The exercises use the sample folder and the functions from above. If you
start a new session, create the folder again with
`$root = ./samples/New-WorkshopFolder.ps1 -Force`.

### Exercise 1: Folder sizes from the pipeline

1. Write a function `Get-FolderSize` with a parameter `-Path` that accepts
   folder paths as strings and the folder objects of
   `Get-ChildItem -Directory`.
2. Return one object per folder, with the folder name in `Folder` and the
   total size of its files, including subfolders, in `SizeKB`, rounded to
   two decimals.
3. Run it for the subfolders of the sample folder.

<details>
<summary>Solution</summary>

```powershell
function Get-FolderSize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path
    )

    process {
        foreach ($folder in $Path) {
            $bytes = (Get-ChildItem -Path $folder -Recurse -File | Measure-Object -Property Length -Sum).Sum
            [PSCustomObject]@{
                Folder = Split-Path -Path $folder -Leaf
                SizeKB = [math]::Round($bytes / 1KB, 2)
            }
        }
    }
}

Get-ChildItem -Path $root -Directory | Get-FolderSize
```

```text
Folder   SizeKB
------   ------
backup  2048.03
config     0.18
data      23.14
logs     177.04
scripts    0.30
```

A folder object isn't a string, so it can't bind by value without
conversion. PowerShell then tries binding by property name and finds
`FullName`, through the alias, as a string. Strings, such as `$logs`, still
bind by value.

</details>

### Exercise 2: A pipeline-aware Get-FileExtensionSize

1. Change the workshop version of `Get-FileExtensionSize` from
   [Your first function](09-your-first-function.md) so that `-Path` accepts
   folders from the pipeline, as strings or folder objects.
2. Add a property `Folder` with the folder name to each result.
3. Show the most frequent extension in each subfolder of the sample folder.

<details>
<summary>Solution</summary>

```powershell
function Get-FileExtensionSize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName')]
        [string[]]$Path,

        [Parameter(Mandatory)]
        [int]$Top
    )

    process {
        foreach ($folder in $Path) {
            Get-ChildItem -Path $folder -Recurse -File -ErrorAction SilentlyContinue |
                Group-Object -Property Extension |
                Sort-Object -Property Count -Descending |
                Select-Object -First $Top |
                ForEach-Object {
                    [PSCustomObject]@{
                        Folder        = Split-Path -Path $folder -Leaf
                        Extension     = $_.Name
                        FileCount     = $_.Count
                        TotalFileSize = ($_.Group | Measure-Object -Property Length -Sum).Sum / 1GB
                    }
                }
        }
    }
}

Get-ChildItem -Path $root -Directory | Get-FileExtensionSize -Top 1
```

```text
Folder  Extension FileCount TotalFileSize
------  --------- --------- -------------
backup  .bak              1          0.00
config  .json             2          0.00
data    .csv              2          0.00
logs    .log              6          0.00
scripts .ps1              3          0.00
```

`backup` and `data` have a tie: one `.bak` and one `.txt` file, two `.csv`
and two `.json` files. `Group-Object` sorts the groups by name, but for equal
counts, `Sort-Object` doesn't guarantee an order. Add `-Stable` to
`Sort-Object` to keep the order in which the groups arrive.

</details>

### Exercise 3: Explain a binding with Trace-Command

`Test-Process` from above takes an `[int]`. Why does `'5' | Test-Process`
work, although `'5'` is a string? Trace the binding and find the step that
succeeds.

<details>
<summary>Solution</summary>

```powershell
Trace-Command -Name ParameterBinding -PSHost -Expression { '5' | Test-Process }
```

The relevant lines of the trace:

```text
DEBUG: 2026-11-17 21:14:09.2964 ParameterBinding Information: 0 : BIND PIPELINE object to parameters: [Test-Process]
DEBUG: 2026-11-17 21:14:09.2964 ParameterBinding Information: 0 :     PIPELINE object TYPE = [System.String]
DEBUG: 2026-11-17 21:14:09.2964 ParameterBinding Information: 0 :     RESTORING pipeline parameter's original values
DEBUG: 2026-11-17 21:14:09.2965 ParameterBinding Information: 0 :     Parameter [Number] PIPELINE INPUT ValueFromPipeline NO COERCION
DEBUG: 2026-11-17 21:14:09.2965 ParameterBinding Information: 0 :     BIND arg [5] to parameter [Number]
DEBUG: 2026-11-17 21:14:09.2965 ParameterBinding Information: 0 :         Executing DATA GENERATION metadata: [System.Management.Automation.ArgumentTypeConverterAttribute]
DEBUG: 2026-11-17 21:14:09.2966 ParameterBinding Information: 0 :             result returned from DATA GENERATION: 5
DEBUG: 2026-11-17 21:14:09.2966 ParameterBinding Information: 0 :         BIND arg [5] to param [Number] SKIPPED
DEBUG: 2026-11-17 21:14:09.2966 ParameterBinding Information: 0 :     Parameter [Number] PIPELINE INPUT ValueFromPipeline WITH COERCION
DEBUG: 2026-11-17 21:14:09.2967 ParameterBinding Information: 0 :     BIND arg [5] to parameter [Number]
DEBUG: 2026-11-17 21:14:09.2967 ParameterBinding Information: 0 :         Executing DATA GENERATION metadata: [System.Management.Automation.ArgumentTypeConverterAttribute]
DEBUG: 2026-11-17 21:14:09.2970 ParameterBinding Information: 0 :             result returned from DATA GENERATION: 5
DEBUG: 2026-11-17 21:14:09.2970 ParameterBinding Information: 0 :         COERCE arg to [System.Int32]
DEBUG: 2026-11-17 21:14:09.2971 ParameterBinding Information: 0 :             Parameter and arg types the same, no coercion is needed.
DEBUG: 2026-11-17 21:14:09.2971 ParameterBinding Information: 0 :         BIND arg [5] to param [Number] SUCCESSFUL
```

The first attempt, by value without conversion, is `SKIPPED`, because a
string isn't an `[int]`. The third step of the binding order, by value
*with* conversion, converts `'5'` to the number 5 and succeeds.

</details>

## Key takeaways

- `ValueFromPipeline` binds the whole object by its type;
  `ValueFromPipelineByPropertyName` binds a property with the parameter's
  name or alias.
- PowerShell tries both kinds of binding without type conversion first, and
  only then with conversion.
- A function with pipeline input needs a `process` block. Use `begin` and
  `end` for work that happens once.
- Loop with `foreach` over array parameters inside `process`, so that the
  function works with both the command line and the pipeline.
- Aliases connect your parameters to other property names, and
  `Trace-Command` shows why a binding works or fails.

## Learn more

- [about_Functions_Advanced_Parameters](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)
- [about_Parameter_Binding](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_parameter_binding)
- [about_Functions: input processing methods](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions#input-processing-methods)
- [Trace-Command](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/trace-command)
- [Visualize parameter binding](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/visualize-parameter-binding)
- [about_Parameter_Sets](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_parameter_sets)

[fms-get-largestfile]: https://github.com/raandree/FileManagementSample/blob/main/source/Public/Get-LargestFile.ps1

---

[← Previous: Your first function](09-your-first-function.md)
· [Overview](../README.md) ·
[Next: Splatting →](11-splatting.md)
