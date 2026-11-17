# Splatting

[Overview](../README.md) › Part 2: From one-liners to tools › Topic 11 of 17

Long command lines are hard to read and harder to change. *Splatting* passes
the parameters of a command as one hashtable or array instead. You can build
the parameters step by step, add some only when you need them, and pass them
on to other commands.

In this topic, you learn to:

- pass parameters as a hashtable with `@` instead of `$`
- splat an array for positional parameters
- pass the parameters of a function on with `$PSBoundParameters`
- combine a splat with named parameters, and copy it before you change it
- try out risky commands with `-WhatIf` in a splat

## Parameters as a hashtable

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

Each key is the name of a parameter, without the dash, and each value is
its argument. A switch parameter, such as `-Recurse`, takes `$true`. With the
sample folder, the same idea finds all JSON files:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
$params = @{
    Path        = $root
    Recurse     = $true
    File        = $true
    Filter      = '*.json'
    ErrorAction = 'SilentlyContinue'
}
Get-ChildItem @params | Select-Object -Property Name, Length
```

```text
Name          Length
----          ------
app.json          76
web.json          83
settings.json    199
users.json       190
```

## Switch parameters in a splat

A switch parameter is either present or not. In a splat, `$true` means
present and `$false` means absent, so a variable can turn a switch on and
off:

```powershell
$params = @{ Path = $root; Directory = $true }
(Get-ChildItem @params).Count
$params.Directory = $false
(Get-ChildItem @params).Count
```

```text
5
8
```

With `Directory = $true`, you get the five folders. With `$false`, the
switch is off, and `Get-ChildItem` returns the five folders and the three
files in the root of the sample folder.

## Computed parameter names

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

A hashtable key can be any expression. Here, the variable
`$pathParameterName` holds `'Path'` or `'LiteralPath'`, depending on
`$PSCmdlet.ParameterSetName`, the parameter set of the current call. One
`Get-ChildItem` call serves both parameter sets, without an `if` around two
nearly identical commands.

## Array splatting for positional parameters

A *positional parameter* takes its value from its position on the command
line, without a name. An array splats such values in order: the first
element goes to position 0, the second to position 1:

```powershell
$pathParts = 'logs', 'app-2026-11-03.log'
Join-Path @pathParts
```

```text
logs\app-2026-11-03.log
```

`Join-Path` binds `'logs'` to `-Path` and the file name to `-ChildPath`.
Array splatting also passes arguments to native programs, such as
`git.exe`. In scripts, prefer hashtables: they name every parameter and
don't depend on the order.

## Combine splatting with named parameters

A splat doesn't have to carry all parameters. You can add named parameters
before or after it, and you can splat several hashtables in one call:

```powershell
$common = @{ Path = $root; Recurse = $true; File = $true }
Get-ChildItem @common -Filter '*.ps1' | Select-Object -Property Name
```

```text
Name
----
Get-Report.ps1
Set-Config.ps1
Start-Backup.ps1
```

Since PowerShell 7.1, a named parameter on the command line overrides the
same key in the splat. That is handy when one call needs a different value:

```powershell
$params = @{ Path = $root; Recurse = $true; File = $true; Filter = '*.json' }
Get-ChildItem @params -Filter '*.csv' | Select-Object -Property Name
```

```text
Name
----
customers.csv
orders.csv
```

## Pass parameters on with $PSBoundParameters

A *wrapper function* adds a little logic around another command and passes
its parameters on. `$PSBoundParameters` is an automatic variable that
holds the parameters of the current call as a dictionary, ready for
splatting. The following function searches log files and passes its
parameters on to `Select-String`, because they have the same names:

```powershell
function Find-LogEntry {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string[]]$Path,

        [switch]$SimpleMatch
    )

    Write-Verbose -Message "Passing on: $($PSBoundParameters.Keys -join ', ')"
    Select-String @PSBoundParameters | Select-Object -First 3 -Property Filename, LineNumber, Line
}

$logFiles = Get-ChildItem -Path $root -Recurse -Filter '*.log'
Find-LogEntry -Pattern 'ERROR' -Path $logFiles.FullName -SimpleMatch -Verbose
```

```text
VERBOSE: Passing on: Pattern, Path, SimpleMatch, Verbose

Filename           LineNumber Line
--------           ---------- ----
app-2026-11-01.log         25 2026-11-01 08:14:48 ERROR Connection to database failed
app-2026-11-01.log         50 2026-11-01 08:30:13 ERROR Connection to database failed
app-2026-11-01.log         75 2026-11-01 08:45:38 ERROR Connection to database failed
```

`-Verbose` is in `$PSBoundParameters`, too, so `Select-String` receives it
as well. When you add a parameter to the wrapper, it reaches `Select-String`
without further changes, as long as the names match.

## Copy a splat before you change it

A hashtable is a reference type: assigning it to a second variable doesn't
copy it. Both variables point to the same hashtable, and a change through
one is visible through the other:

```powershell
$base = @{ Path = $root; Recurse = $true; File = $true }
$logParams = $base
$logParams.Filter = '*.log'
$base.ContainsKey('Filter')
```

```text
True
```

`Clone()` creates a real copy. Change the copy, and the original stays as it
was:

```powershell
$base = @{ Path = $root; Recurse = $true; File = $true }
$logParams = $base.Clone()
$logParams.Filter = '*.log'
$base.ContainsKey('Filter')
(Get-ChildItem @logParams).Count
(Get-ChildItem @base).Count
```

```text
False
6
22
```

`Clone()` makes a *shallow* copy: when a value is itself a hashtable or
another object, the copy and the original still share it.

## -WhatIf in a splat

Commands that change something usually support `-WhatIf`. It reports what
the command would do, without doing it. In a splat, `WhatIf = $true` turns a
risky call into a dry run, and you remove one line to run it for real. Your
own functions support `-WhatIf` when they declare
`[CmdletBinding(SupportsShouldProcess)]` and ask `$PSCmdlet.ShouldProcess()`
before each change:

```powershell
function Remove-SampleLog {
    [CmdletBinding(SupportsShouldProcess)]
    param ([Parameter(Mandatory)][string]$Path)

    foreach ($file in Get-ChildItem -Path $Path -Recurse -Filter '*.log') {
        if ($PSCmdlet.ShouldProcess($file.Name, 'Remove')) {
            Remove-Item -LiteralPath $file.FullName
        }
    }
}

$removeParams = @{
    Path   = Join-Path -Path $root -ChildPath 'logs/archive.old'
    WhatIf = $true
}
Remove-SampleLog @removeParams
```

The console shows what would happen, and the files stay:

```text
What if: Performing the operation "Remove" on target "app-2026-10-30.log".
What if: Performing the operation "Remove" on target "app-2026-10-31.log".
```

## Common pitfalls

- **`$params` instead of `@params`.** With a dollar sign, PowerShell passes
  the hashtable as one value to the first positional parameter. For
  `Get-ChildItem`, that is `-Path`, and the hashtable becomes a path:

  ```powershell
  Get-ChildItem $params
  ```

  ```text
  Get-ChildItem: Cannot find path 'D:\Git\261116PowerShellGhcpWorkshop\System.Collections.Hashtable' because it does not exist.
  ```

- **The same parameter twice.** A named parameter overrides the splat, as
  shown above, but two splats with the same key fail:

  ```powershell
  $jsonFilter = @{ Filter = '*.json' }
  $logFilter = @{ Filter = '*.log' }
  Get-ChildItem -Path $root -Recurse @jsonFilter @logFilter
  ```

  ```text
  Get-ChildItem:
  Line |
     3 |  Get-ChildItem -Path $root -Recurse @jsonFilter @logFilter
       |                                                 ~~~~~~~~~~
       | Cannot bind parameter because parameter 'Filter' is specified more than once. To provide multiple values to parameters that can accept multiple values, use the array syntax. For example, "-parameter value1,value2,value3".
  ```

  Windows PowerShell 5.1 doesn't know the override at all. There, a named
  parameter that is also in the splat stops the call with the same error.

- **`$PSBoundParameters` doesn't contain default values.** It holds only the
  parameters that the caller passed. A default value stays behind:

  ```powershell
  function Get-LogFile {
      [CmdletBinding()]
      param (
          [Parameter(Mandatory)]
          [string]$Path,

          [string]$Filter = '*.log'
      )

      Get-ChildItem @PSBoundParameters -Recurse -File
  }
  (Get-LogFile -Path $root).Count
  ```

  ```text
  22
  ```

  The function returns all 22 files instead of the 6 log files, because
  `-Filter` never reaches `Get-ChildItem`. Add the value yourself before you
  splat: `$PSBoundParameters['Filter'] = $Filter`.

## Exercises

The exercises use the sample folder from above. If you start a new session,
create it again with `$root = ./samples/New-WorkshopFolder.ps1 -Force`.

### Exercise 1: A wrapper for Get-ChildItem

1. Write a function `Get-SampleFile` with the parameters `-Path`
   (mandatory), `-Filter`, and the switch `-Recurse`.
2. Pass the parameters on to `Get-ChildItem` with `$PSBoundParameters`, and
   always add `-File`.
3. Find all `.txt` files in the sample folder and its subfolders.

<details>
<summary>Solution</summary>

```powershell
function Get-SampleFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [string]$Filter,

        [switch]$Recurse
    )

    Get-ChildItem @PSBoundParameters -File
}

Get-SampleFile -Path $root -Filter '*.txt' -Recurse | Select-Object -Property Name
```

```text
Name
----
notes.TXT
readme.txt
backup-notes.txt
changes.txt
todo.txt
```

The filter `*.txt` also finds `notes.TXT`, because file names on Windows
are case-insensitive.

</details>

### Exercise 2: Conditional parameters

1. Store a file filter in `$filter` and a switch value in
   `$includeSubfolders`.
2. Build a splat for `Get-ChildItem` that contains `Filter` only when
   `$filter` isn't empty, and `Recurse` only when `$includeSubfolders` is
   `$true`.
3. Count the files for `'*.log'` with subfolders, and for an empty filter
   without subfolders.

<details>
<summary>Solution</summary>

```powershell
function Get-FileCount {
    param ([string]$Filter, [bool]$IncludeSubfolders)

    $params = @{ Path = $root; File = $true }
    if ($Filter) { $params.Filter = $Filter }
    if ($IncludeSubfolders) { $params.Recurse = $true }
    (Get-ChildItem @params).Count
}

$filter = '*.log'
$includeSubfolders = $true
Get-FileCount -Filter $filter -IncludeSubfolders $includeSubfolders

$filter = ''
$includeSubfolders = $false
Get-FileCount -Filter $filter -IncludeSubfolders $includeSubfolders
```

```text
6
3
```

The function adds a key only when it has a value, so `Get-ChildItem`
receives exactly the parameters that the call needs. The same pattern works
for any optional setting in a script.

</details>

### Exercise 3: From a long command line to splats

Rewrite this command with one splat for `Get-ChildItem` and one for
`Select-Object`:

```powershell
Get-ChildItem -Path $root -Recurse -File -Filter '*.log' -ErrorAction SilentlyContinue | Sort-Object -Property Length -Descending | Select-Object -First 3 -Property Name, Length
```

<details>
<summary>Solution</summary>

```powershell
$getParams = @{
    Path        = $root
    Recurse     = $true
    File        = $true
    Filter      = '*.log'
    ErrorAction = 'SilentlyContinue'
}
$selectParams = @{
    First    = 3
    Property = 'Name', 'Length'
}
Get-ChildItem @getParams | Sort-Object -Property Length -Descending | Select-Object @selectParams
```

```text
Name               Length
----               ------
app-2026-11-03.log  50352
app-2026-11-02.log  40285
app-2026-11-01.log  30215
```

The pipeline now fits on one line, and every parameter has its own line in
a splat, where you can change it without scrolling sideways.

</details>

## Key takeaways

- Splatting passes parameters as a hashtable with `@`: one parameter per
  line, easy to build up, easy to reuse.
- Switch parameters take `$true` or `$false` in a splat; arrays splat
  positional parameters in order.
- `$PSBoundParameters` passes the parameters of a function on, but only the
  ones that the caller passed, not the default values.
- Named parameters can stand next to a splat and, since PowerShell 7.1,
  override its keys. Copy a splat with `Clone()` before you change it.
- `WhatIf = $true` in a splat turns a risky call into a dry run.

## Learn more

- [about_Splatting](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_splatting)
- [Everything you wanted to know about hashtables](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-hashtable)
- [about_Automatic_Variables](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_automatic_variables)
- [about_Functions_CmdletBindingAttribute](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_cmdletbindingattribute)

---

[← Previous: Pipeline input](10-pipeline-input.md)
· [Overview](../README.md) ·
[Next: Debugging in VS Code →](12-debugging-in-vs-code.md)
