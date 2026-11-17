# Your first function

[Overview](../README.md) › Part 2: From one-liners to tools › Topic 9 of 17

A one-liner answers a question once. A function gives the answer a name and
parameters, so that you and your colleagues can ask the same question about
any folder, again and again. This topic turns the pipeline from
[Building a pipeline step by step](03-building-a-pipeline-step-by-step.md)
into a function and then makes it robust.

In this topic, you learn to:

- turn a pipeline into a function with typed, mandatory parameters
- document a function with comment-based help
- reject invalid input with validation attributes
- report progress with `Write-Verbose` and handle errors with `try` and
  `catch`
- load a function from a file by dot-sourcing

## From pipeline to function

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

A *parameter* is a named input of a function. `[Parameter(Mandatory)]` and
the types in square brackets are *attributes*: they tell PowerShell how to
treat a value before your code runs. When you leave out a mandatory
parameter, PowerShell shows *Supply values for the following parameters*
and waits until you type the value.

## Run it against the sample folder

`D:\LabSources` is the folder the workshop used. The sample folder works on
any machine. Create it from the root of this repository, then call the
function:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
Get-FileExtensionSize -Path $root -Top 5
```

```text
Extension FileCount TotalFileSize
--------- --------- -------------
.log              6          0.00
.TXT              5          0.00
.json             4          0.00
.ps1              3          0.00
.csv              2          0.00
```

Every total reads `0.00`: the sample files are small, and the function
reports gigabytes. In a table, PowerShell 7.6 rounds such floating-point
numbers to two decimals for display, but the objects keep the exact values:

```powershell
$result = Get-FileExtensionSize -Path $root -Top 5
$result[0].TotalFileSize
$result[0].TotalFileSize * 1GB
```

```text
0.00016883946955204
181290
```

The text group is named `.TXT` because `notes.TXT` is the first text file
in the folder, and `Group-Object` ignores case. Exercise 1 below switches the
function to kilobytes.

## The demo-project version

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

The `[Parameter()]` attribute alone already makes a function advanced:
`(Get-Command -Name Get-FileExtensionSize).CmdletBinding` returns `True` for
the workshop version, too, and `Get-Command -Syntax` lists
`[<CommonParameters>]`. Write `[CmdletBinding()]` anyway. It states your
intent, and it takes options such as `SupportsShouldProcess`, which adds
`-WhatIf` and `-Confirm` to the function.

## Everything a function emits is output

Languages such as C# return only the value after `return`. PowerShell
returns the result of every statement that you don't assign or discard;
`return` only leaves the function early. A friendly message becomes part of
the result:

```powershell
function Get-SampleFileCount {
    'Counting the files...'
    (Get-ChildItem -Path $root -Recurse -File).Count
}
$count = Get-SampleFileCount
$count
```

```text
Counting the files...
22
```

`$count` now holds two values: the text and the number. Messages for people
belong on another *stream*, a separate channel next to the output.
`Write-Verbose` uses such a stream, as the next sections show.

## Comment-based help

*Comment-based help* is a block comment with keywords such as `.SYNOPSIS`,
`.PARAMETER`, and `.EXAMPLE`. `Get-Help` reads it, so your function documents
itself like a built-in cmdlet. The following function counts the lines of
one log level in the log files of a folder. Besides help, it uses validation
attributes and verbose messages, which the next sections explain:

```powershell
function Get-LogLevelCount {
    <#
    .SYNOPSIS
        Counts the lines of one log level in the log files of a folder.

    .DESCRIPTION
        Searches the folder and its subfolders for .log files and returns
        the files with the most lines of the log level first.

    .PARAMETER Path
        The folder to search.

    .PARAMETER Level
        The log level to count: INFO, WARN, or ERROR. The default is ERROR.

    .PARAMETER Top
        The number of files to return, from 1 to 100. The default is 3.

    .EXAMPLE
        Get-LogLevelCount -Path $root -Level WARN -Top 5

        Returns the five log files with the most warnings.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -Path $_ -PathType Container },
            ErrorMessage = 'The folder {0} does not exist.')]
        [string]$Path,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'ERROR',

        [ValidateRange(1, 100)]
        [int]$Top = 3
    )

    $files = Get-ChildItem -Path $Path -Recurse -File -Filter '*.log'
    Write-Verbose -Message "Found $($files.Count) log files."

    $counts = foreach ($file in $files) {
        Write-Verbose -Message "Counting $Level lines in $($file.Name)."
        [PSCustomObject]@{
            Name  = $file.Name
            Level = $Level
            Count = @(Select-String -Path $file.FullName -Pattern " $Level " -SimpleMatch).Count
        }
    }

    $counts | Sort-Object -Property Count -Descending | Select-Object -First $Top
}
```

`Get-Help` turns the comment into a help topic, just like the help of a
built-in cmdlet:

```powershell
Get-Help -Name Get-LogLevelCount
```

```text
NAME
    Get-LogLevelCount

SYNOPSIS
    Counts the lines of one log level in the log files of a folder.


SYNTAX
    Get-LogLevelCount [-Path] <String> [[-Level] <String>] [[-Top] <Int32>] [<CommonParameters>]


DESCRIPTION
    Searches the folder and its subfolders for .log files and returns
    the files with the most lines of the log level first.


RELATED LINKS

REMARKS
    To see the examples, type: "Get-Help Get-LogLevelCount -Examples"
    For more information, type: "Get-Help Get-LogLevelCount -Detailed"
    For technical information, type: "Get-Help Get-LogLevelCount -Full"
```

PowerShell adds the syntax line itself, with every parameter and its type.
`Get-Help -Name Get-LogLevelCount -Examples` shows only the examples, and
`-Parameter Level` describes one parameter. The help block can also stand at
the end of the function body, or directly before the `function` keyword.

## Validate the input

*Validation attributes* check a parameter value before the first line of
your function runs. Invalid input stops the call with a clear error, so your
code never has to deal with it.

| Attribute                                                      | Accepts                                                             |
|----------------------------------------------------------------|---------------------------------------------------------------------|
| `[ValidateRange(1, 100)]`                                      | Numbers from 1 to 100                                               |
| `[ValidateSet('INFO', 'WARN', 'ERROR')]`                       | One of the listed values, with tab completion                       |
| `[ValidateScript({ Test-Path -Path $_ -PathType Container })]` | Every value for which the script returns `$true`; `$_` is the value |

```powershell
Get-LogLevelCount -Path $root -Level DEBUG
```

```text
Get-LogLevelCount: Cannot validate argument on parameter 'Level'. The argument "DEBUG" does not belong to the set "INFO,WARN,ERROR" specified by the ValidateSet attribute. Supply an argument that is in the set and then try the command again.
```

```powershell
Get-LogLevelCount -Path 'C:\NoSuchFolder'
```

```text
Get-LogLevelCount: Cannot validate argument on parameter 'Path'. The folder C:\NoSuchFolder does not exist.
```

Without `ErrorMessage`, the error of `ValidateScript` quotes the script
itself, which doesn't help a user much. In the message, `{0}` stands for the
value; `ErrorMessage` works in PowerShell 6 and later. `-PathType Container`
makes `Test-Path` accept only folders, not files.

## Verbose messages

`Write-Verbose` writes a message to the *verbose stream*. PowerShell shows it
only when you call the function with `-Verbose`, one of the common
parameters of every advanced function:

```powershell
Get-LogLevelCount -Path $root -Level WARN -Top 2 -Verbose
```

```text
VERBOSE: Found 6 log files.
VERBOSE: Counting WARN lines in app-2026-11-01.log.
VERBOSE: Counting WARN lines in app-2026-11-02.log.
VERBOSE: Counting WARN lines in app-2026-11-03.log.
VERBOSE: Counting WARN lines in web-2026-11-03.log.
VERBOSE: Counting WARN lines in app-2026-10-30.log.
VERBOSE: Counting WARN lines in app-2026-10-31.log.

Name               Level Count
----               ----- -----
app-2026-11-03.log WARN     80
app-2026-11-02.log WARN     64
```

Without `-Verbose`, the same call returns only the two objects. Verbose
messages never end up in the output, so they don't break a pipeline. Write
them generously: they let a function explain itself when something goes
wrong.

## Handle errors with try and catch

PowerShell knows two kinds of errors. A *non-terminating* error reports a
problem and lets the command continue, for example with the next file. A
*terminating* error stops the statement or the script. `try` and `catch`
handle only terminating errors:

```powershell
try {
    Get-Content -Path 'C:\NoSuchFolder\settings.json'
    'The file was read.'
}
catch {
    "Caught: $($_.Exception.Message)"
}
```

```text
Get-Content:
Line |
   2 |      Get-Content -Path 'C:\NoSuchFolder\settings.json'
     |      ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
     | Cannot find path 'C:\NoSuchFolder\settings.json' because it does not exist.
The file was read.
```

The error of `Get-Content` is non-terminating, so `catch` never runs, and
the next line claims success. `-ErrorAction Stop` turns the error into a
terminating one, and `catch` takes over:

```powershell
try {
    Get-Content -Path 'C:\NoSuchFolder\settings.json' -ErrorAction Stop
    'The file was read.'
}
catch {
    "Caught: $($_.Exception.Message)"
}
```

```text
Caught: Cannot find path 'C:\NoSuchFolder\settings.json' because it does not exist.
```

In `catch`, `$_` is the error record, and `$_.Exception.Message` holds its
text. Add `-ErrorAction Stop` to the commands whose failure must stop your
code. `Get-FileExtensionSize` makes the opposite decision with
`-ErrorAction SilentlyContinue`: an unreadable folder there is expected and
harmless.

## Load a function from a file

A function that you define in the console lives until you close it. To keep
it, save it in a `.ps1` file. Running the file isn't enough, though:

```powershell
$scriptFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'Get-Square.ps1'
Set-Content -Path $scriptFile -Value 'function Get-Square { param ([int]$Number) $Number * $Number }'
& $scriptFile
Get-Square -Number 4
```

```text
Get-Square:
Line |
   4 |  Get-Square -Number 4
     |  ~~~~~~~~~~
     | The term 'Get-Square' is not recognized as a name of a cmdlet, function, script file, or executable program.
Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
```

A script runs in its own *scope*, and the functions it defines disappear
when it ends. *Dot-sourcing*, a dot and a space before the path, runs the
script in the current scope instead, so its functions stay:

```powershell
. $scriptFile
Get-Square -Number 4
```

```text
16
```

Once you have more than a handful of functions, put them into a module
instead; [Scaffolding a module with Sampler](13-scaffolding-a-module-with-sampler.md)
shows how.

## Common pitfalls

- **`Write-Host` instead of output.** `Write-Host` writes to the screen, not
  to the output, so a variable or the next command receives nothing:

  ```powershell
  function Get-FileCount { Write-Host (Get-ChildItem -Path $root -Recurse -File).Count }
  $fileCount = Get-FileCount
  $null -eq $fileCount
  ```

  ```text
  22
  True
  ```

  Return data as output, and use `Write-Verbose` for messages.

- **Unwanted output from methods.** Some .NET methods return a value that
  you don't need. `Add()` of an `ArrayList` returns the index of the new
  item, and every index ends up in the output:

  ```powershell
  function Get-ConfigExtension {
      $list = [System.Collections.ArrayList]::new()
      foreach ($file in Get-ChildItem -Path (Join-Path -Path $root -ChildPath 'config') -File) {
          $list.Add($file.Extension)
      }
      $list
  }
  Get-ConfigExtension
  ```

  ```text
  0
  1
  2
  .json
  .txt
  .json
  ```

  Discard the value with `$null = $list.Add($file.Extension)`, or use a
  `[System.Collections.Generic.List[string]]`, whose `Add()` returns nothing.

- **A parameter named `$Input`.** `$input` is an automatic variable that
  PowerShell fills with the pipeline input, and it wins over your parameter:

  ```powershell
  function Test-Input { param ([string]$Input) "You passed: $Input" }
  Test-Input -Input 'hello'
  ```

  ```text
  You passed:
  ```

  Name the parameter `$InputObject`, as the built-in cmdlets do.

- **A default value on a mandatory parameter.** PowerShell prompts for a
  mandatory parameter, so its default value is never used. PSScriptAnalyzer
  catches this mistake:

  ```powershell
  $code = 'function Get-Top { param ([Parameter(Mandatory)][int]$Top = 5) $Top }'
  Invoke-ScriptAnalyzer -ScriptDefinition $code | Select-Object -Property RuleName, Message | Format-List
  ```

  ```text
  RuleName : PSAvoidDefaultValueForMandatoryParameter
  Message  : Mandatory Parameter 'Top' is initialized in the Param block. To fix a violation of this
             rule, please leave it uninitialized.
  ```

  Decide: either the parameter is mandatory, or it has a default value.

## Exercises

The exercises use the sample folder from above. If you start a new session,
create it again with `$root = ./samples/New-WorkshopFolder.ps1 -Force`.

### Exercise 1: Make the function more useful

Start from the workshop version of `Get-FileExtensionSize` and apply the
three improvements from the tip:

1. Report the total size in kilobytes, rounded to two decimals, in a
   property `TotalSizeKB`. Gigabytes are too coarse for the sample folder.
2. Rank the extensions by total size instead of by number of files.
3. Accept only values from 1 to 100 for `-Top`.

<details>
<summary>Solution</summary>

```powershell
function Get-FileExtensionSize {
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateRange(1, 100)]
        [int]$Top
    )

    Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
        Group-Object -Property Extension |
        ForEach-Object {
            [PSCustomObject]@{
                Extension   = $_.Name
                FileCount   = $_.Count
                TotalSizeKB = [math]::Round(($_.Group | Measure-Object -Property Length -Sum).Sum / 1KB, 2)
            }
        } |
        Sort-Object -Property TotalSizeKB -Descending |
        Select-Object -First $Top
}

Get-FileExtensionSize -Path $root -Top 3
```

```text
Extension FileCount TotalSizeKB
--------- --------- -----------
.bak              1     2048.00
.log              6      177.04
.csv              2       22.76
```

```powershell
Get-FileExtensionSize -Path $root -Top 0
```

```text
Get-FileExtensionSize: Cannot validate argument on parameter 'Top'. The 0 argument is less than the minimum allowed range of 1. Supply an argument that is greater than or equal to 1 and then try the command again.
```

To rank by size, the function must know the size of every group before it
sorts. So it creates the objects first, then sorts and selects. The single
`.bak` file now leads the list, while it didn't even make the top five by
count.

</details>

### Exercise 2: Help and verbose messages

1. Add comment-based help to your function from Exercise 1, with a synopsis,
   a description of both parameters, and one example.
2. Add a verbose message that reports how many files the function found.
3. Show the example with `Get-Help`, and run the function with `-Verbose`.

<details>
<summary>Solution</summary>

```powershell
function Get-FileExtensionSize {
    <#
    .SYNOPSIS
        Gets the file extensions with the largest total size in a folder.

    .PARAMETER Path
        The folder to search, including its subfolders.

    .PARAMETER Top
        The number of extensions to return, from 1 to 100.

    .EXAMPLE
        Get-FileExtensionSize -Path $root -Top 3

        Returns the three extensions that use the most space below $root.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateRange(1, 100)]
        [int]$Top
    )

    $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue
    Write-Verbose -Message "Found $($files.Count) files."

    $files |
        Group-Object -Property Extension |
        ForEach-Object {
            [PSCustomObject]@{
                Extension   = $_.Name
                FileCount   = $_.Count
                TotalSizeKB = [math]::Round(($_.Group | Measure-Object -Property Length -Sum).Sum / 1KB, 2)
            }
        } |
        Sort-Object -Property TotalSizeKB -Descending |
        Select-Object -First $Top
}

Get-Help -Name Get-FileExtensionSize -Examples
```

```text
NAME
    Get-FileExtensionSize

SYNOPSIS
    Gets the file extensions with the largest total size in a folder.


    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-FileExtensionSize -Path $root -Top 3

    Returns the three extensions that use the most space below $root.
```

```powershell
Get-FileExtensionSize -Path $root -Top 2 -Verbose
```

```text
VERBOSE: Found 22 files.

Extension FileCount TotalSizeKB
--------- --------- -----------
.bak              1     2048.00
.log              6      177.04
```

The verbose message goes to a separate stream, so the output still contains
only the two objects.

</details>

## Key takeaways

- A function turns a pipeline into a reusable tool. Use an approved verb,
  typed parameters, and one `[PSCustomObject]` per result.
- Mandatory parameters and validation attributes reject bad input before
  your code runs.
- Everything a function doesn't assign or discard is output. Send messages
  to `Write-Verbose`, and discard unwanted values with `$null =`.
- `try` and `catch` handle only terminating errors; add `-ErrorAction Stop`
  to a command whose failure must stop your code.
- Comment-based help makes `Get-Help` work for your function, and
  dot-sourcing a file loads its functions into your session.

## Learn more

- [about_Functions](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions)
  and [about_Functions_Advanced](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_advanced)
- [about_Functions_CmdletBindingAttribute](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute)
- [about_Functions_OutputTypeAttribute](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_outputtypeattribute)
- [about_Comment_Based_Help](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_comment_based_help)
- [Approved verbs for PowerShell commands](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- [about_Functions_Advanced_Parameters](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)
- [about_Try_Catch_Finally](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_try_catch_finally)
  and [about_CommonParameters](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_commonparameters)
- [about_Return](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_return)
  and [about_Scripts](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_scripts)

[fms-get-fileextensionsize]: https://github.com/raandree/FileManagementSample/blob/main/source/Public/Get-FileExtensionSize.ps1

---

[← Previous: Strings and the format operator](08-strings-and-the-format-operator.md)
· [Overview](../README.md) ·
[Next: Pipeline input →](10-pipeline-input.md)
