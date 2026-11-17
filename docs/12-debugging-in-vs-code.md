# Debugging in VS Code

[Overview](../README.md) › Part 3: Engineering practices › Topic 12 of 17

A debugger pauses your code at a line that you choose, so that you can look
at every variable and run the code one statement at a time. This topic walks
through a debug session of the workshop function in VS Code and shows the
console debugger, which works wherever PowerShell runs.

In this topic, you learn to:

- start a debug session with a launch configuration
- pause at breakpoints, also only when a condition is true
- inspect variables, watch expressions, and the call stack
- step through code that you didn't write to understand it
- debug in the console with `Set-PSBreakpoint` and `Wait-Debugger`

## Debugger concepts

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

The PowerShell extension for VS Code connects VS Code to the debugger that
is built into PowerShell. A breakpoint in VS Code is a PowerShell breakpoint,
and **Step Into** in VS Code is the same step as the command `s` in the
console debugger. That is why the console sessions on this page show
exactly where VS Code stops, too.

## Launch configurations

A *launch configuration* tells VS Code what to start when you press F5. The
demo project ships two launch configurations: one debugs the current file,
the other an interactive session.

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

- **PowerShell: Launch Current File** runs the file in the active editor
  under the debugger; `${file}` stands for that file. Without a `cwd`
  setting, the script starts in the workspace folder.
- **PowerShell Interactive Session** starts no script. It debugs every
  command that you run in the PowerShell Extension Terminal, the PowerShell
  console that the extension opens in VS Code. To debug the build of the
  demo project, set a breakpoint in a test or a function, start this
  configuration, and run `./build.ps1 -Tasks test` in the Extension
  Terminal. [Building with Sampler](15-building-with-sampler.md) explains
  the build.

The configurations live in `.vscode/launch.json`. To create the file, open
the Run and Debug view, select **create a launch.json file**, choose
**PowerShell**, and pick a configuration. In the open file,
**Add Configuration...** adds more, such as **PowerShell: Launch Script**
for a fixed script, or **PowerShell: Run Pester Tests**. A single file
doesn't need `launch.json` at all: open it, set a breakpoint, and press F5.

> [!NOTE]
> The extension dot-sources the script that it debugs: the setting
> `powershell.debugging.executeMode` defaults to `DotSource`. After the run,
> the functions and variables of the script stay in the Extension Terminal,
> ready for you to explore, until you restart the session.

## Keyboard shortcuts

| Key       | Action            |
|-----------|-------------------|
| F5        | Start or continue |
| F9        | Toggle breakpoint |
| F10       | Step over         |
| F11       | Step into         |
| Shift+F11 | Step out          |
| Shift+F5  | Stop              |

Ctrl+Shift+D opens the Run and Debug view, Ctrl+Shift+Y opens the Debug
Console, and Ctrl+Shift+F5 restarts the debug session. On macOS, press Cmd
instead of Ctrl. F8 runs the selected lines in the PowerShell Extension
Terminal.

## Walkthrough: debug the workshop function

This walkthrough debugs the workshop version of `Get-FileExtensionSize`
against the sample folder.

1. Open the folder of this repository in VS Code. In the PowerShell
   Extension Terminal, create the sample folder:
   `./samples/New-WorkshopFolder.ps1 -Force`.
2. Create a file `debug-demo.ps1` with the following content. The last two
   lines call the function for the sample folder:

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

   $root = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'WorkshopFiles'
   Get-FileExtensionSize -Path $root -Top 5
   ```

3. Click left of the line number 16, or put the cursor on line 16 and press
   F9. A red dot marks the breakpoint.
4. Open the Run and Debug view with Ctrl+Shift+D, select
   **PowerShell: Launch Current File** in the configuration list at the top,
   and press F5.
5. The debugger stops before line 16 runs and highlights the line. `$_` is
   the first group that `ForEach-Object` received.
6. In **VARIABLES**, the group **Auto** shows the variables that matter at
   this point, such as `$_`. Expand `$_` to see `Name`, `Count`, and `Group`.
   **Local**, **Script**, and **Global** list the variables of each scope.
   You can also hover over a variable in the editor to see its value.
7. In **WATCH**, select **+** and enter `$_.Group.Count`, then add
   `$_.Name`. Watch expressions are PowerShell, and VS Code evaluates them
   whenever the debugger pauses: they show `6` and `.log`.
8. Press F5 to continue. The debugger stops on line 16 again, and the watch
   shows `5` and `.TXT`. Three more presses of F5 bring `.json`, `.ps1`, and
   `.csv`.
9. **CALL STACK** shows how execution got here: two frames of
   `Get-FileExtensionSize`, one for the script block of `ForEach-Object` on
   line 16 and one for the function body on line 15, then the script on
   line 29. Select a frame to see its variables.
10. To step through the function, remove the breakpoint with F9, set one on
    line 29, and restart with Ctrl+Shift+F5. Press F11 twice: the first
    stop is the opening brace of the function on line 1, the second is
    line 10. Press F10 to run the pipeline on line 10 in one step. The
    debugger stops on line 15, and `$fileGroups` holds five groups.
11. Press Shift+F5 to stop.

## Conditional breakpoints

A breakpoint inside a loop stops at every pass. A *conditional breakpoint*
stops only when an expression is true. Right-click the red dot, select
**Edit Breakpoint**, choose **Expression**, enter the condition, and press
Enter. The condition is PowerShell, for example `$Top -gt 3`. Write `-eq`
and `-gt`, not `==` and `>`: the extension rejects such a condition and
tells you which operator to use.

Two more options help with loops:

- **Hit Count** stops only at the *n*th pass, for example at the third group
  with `3`.
- A **logpoint** writes a message instead of stopping. The extension wraps
  the message in a PowerShell string with double quotes and writes it with
  `Write-Host`. So `Searching $Path for the top $Top extensions` on line 10
  shows the values.

The extension turns each of these into a PowerShell breakpoint with an
*action*, a script block that runs whenever the breakpoint is reached. The
condition `$Top -gt 3` becomes `if ($Top -gt 3) { break }`. You can write the
same action yourself with `Set-PSBreakpoint -Action`, as Exercise 3 shows.

> [!IMPORTANT]
> In a condition, a logpoint, or an action, `$_` is the breakpoint itself,
> not the current object of the pipeline. Named variables, such as `$Top` or
> `$fileGroups`, work as expected. To test the pipeline object, read `$_`
> from the scope of your code:
> `(Get-Variable -Name _ -Scope 1 -ValueOnly).Name -eq '.bak'`.

## The Debug Console

While the debugger pauses, you can run any command in the paused session.
Open the Debug Console with Ctrl+Shift+Y, type an expression, and press
Enter; Shift+Enter starts a new line. In the PowerShell extension, the
result appears in the PowerShell Extension Terminal. The Extension Terminal
itself accepts commands at a pause, too, including the commands of the
console debugger.

At the breakpoint on line 16, try these:

- `$fileGroups | Select-Object -Property Name, Count` lists all five groups,
  while the watch shows only the current one.
- `$_.Group | Select-Object -Property Name, Length` lists the files of the
  current group with their sizes.

To change a value while the debugger pauses, right-click the variable in
**VARIABLES** and select **Set Value**. The new value is a PowerShell
expression, such as `10` or `$null`.

## Debug to understand code

The debugger shows what code *does*, not what you think it does. For a
function that you don't know, a *function breakpoint* is the fastest way in.
In the **BREAKPOINTS** section, select **+** and type the name of the
function. The debugger then stops whenever the function runs, wherever its
code lives. In the console, the same is a command breakpoint:
`Set-PSBreakpoint -Command Get-LargestFile`.

Which parameter set does `Get-LargestFile` from the demo project use for
folder objects, and which for strings? The following console session answers
the question. It runs in the folder `W:\`, which holds `debug-demo.ps1`,
`Get-LargestFile.ps1` from the demo project, and a sample folder
`WorkshopFiles`:

```text
PS W:\> . ./Get-LargestFile.ps1
PS W:\> $root = Get-Item -Path ./WorkshopFiles
PS W:\> $null = Set-PSBreakpoint -Command Get-LargestFile
PS W:\> $null = Get-ChildItem -Path $root -Directory | Select-Object -First 1 | Get-LargestFile -Top 1
Entering debug mode. Use h or ? for help.

Hit Command breakpoint on 'Get-LargestFile'

At W:\Get-LargestFile.ps1:111 char:5
+     {
+     ~
[DBG]: PS W:\>> $PSCmdlet.ParameterSetName
LiteralPath
[DBG]: PS W:\>> $LiteralPath
Microsoft.PowerShell.Core\FileSystem::W:\WorkshopFiles\backup
[DBG]: PS W:\>> c
PS W:\> $null = './WorkshopFiles/logs' | Get-LargestFile -Top 1
Hit Command breakpoint on 'Get-LargestFile'

At W:\Get-LargestFile.ps1:111 char:5
+     {
+     ~
[DBG]: PS W:\>> $PSCmdlet.ParameterSetName
Path
[DBG]: PS W:\>> $Path
./WorkshopFiles/logs
[DBG]: PS W:\>> c
PS W:\>
```

Folder objects arrive in the parameter set `LiteralPath`, through their
`PSPath` property, which carries the provider prefix
`Microsoft.PowerShell.Core\FileSystem::`. Strings arrive in `Path`. Ten
seconds in the debugger confirm what [Pipeline input](10-pipeline-input.md)
explains in theory.

## Debug in the console

The console debugger needs no editor, so it also works on a server. Set
breakpoints with `Set-PSBreakpoint`:

| Breakpoint | Example                                              | Stops                                                        |
|------------|------------------------------------------------------|--------------------------------------------------------------|
| Line       | `Set-PSBreakpoint -Script ./debug-demo.ps1 -Line 16` | Before the statement on line 16 runs                         |
| Variable   | `Set-PSBreakpoint -Variable fileGroups`              | When a new value is written; `-Mode Read` stops on reads     |
| Command    | `Set-PSBreakpoint -Command Get-FileExtensionSize`    | Before the command runs; wildcards such as `Get-*` work, too |

Line breakpoints need a script file. Variable and command breakpoints work
for everything that runs in the session, even for code that you type at the
prompt. When a breakpoint hits, the prompt starts with `[DBG]:`, and these
commands control the execution:

| Command  | Short | Action                                                              |
|----------|-------|---------------------------------------------------------------------|
| StepInto | `s`   | Runs the next statement and stops                                   |
| StepOver | `v`   | Runs the next statement, without stopping in the functions it calls |
| StepOut  | `o`   | Runs to the end of the current function or script block             |
| Continue | `c`   | Runs to the next breakpoint or to the end                           |
| List     | `l`   | Shows the code around the current line                              |
|          | `k`   | Shows the call stack, like `Get-PSCallStack`                        |
| Stop     | `q`   | Stops the script and leaves the debugger                            |
|          | `h`   | Shows the help of the debugger; `?` does the same                   |

Enter repeats `s`, `v`, and `l`. Between these commands, you can run any
PowerShell command, for example to display a variable. The following
session, again in the folder `W:\`, sets a line breakpoint on line 29 of
`debug-demo.ps1` and uses the stepping commands:

```text
PS W:\> $null = Set-PSBreakpoint -Script ./debug-demo.ps1 -Line 29
PS W:\> ./debug-demo.ps1
Entering debug mode. Use h or ? for help.

Hit Line breakpoint on 'W:\debug-demo.ps1:29'

At W:\debug-demo.ps1:29 char:1
+ Get-FileExtensionSize -Path $root -Top 5
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[DBG]: PS W:\>> s
At W:\debug-demo.ps1:1 char:32
+ function Get-FileExtensionSize {
+                                ~
[DBG]: PS W:\>> s
At W:\debug-demo.ps1:10 char:5
+     $fileGroups = Get-ChildItem -Path $Path -Recurse -File -ErrorActi …
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[DBG]: PS W:\>> v
At W:\debug-demo.ps1:15 char:5
+     $fileGroups | ForEach-Object {
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[DBG]: PS W:\>> $fileGroups.Count
5
[DBG]: PS W:\>> s
At W:\debug-demo.ps1:15 char:34
+     $fileGroups | ForEach-Object {
+                                  ~
[DBG]: PS W:\>> s
At W:\debug-demo.ps1:16 char:9
+         $_ | Add-Member -Name Size -MemberType NoteProperty -Value ($ …
+         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[DBG]: PS W:\>> $_.Name
.log
[DBG]: PS W:\>> k

Command               Arguments                      Location
-------               ---------                      --------
Get-FileExtensionSize {Path=W:\WorkshopFiles, Top=5} debug-demo.ps1: line 16
Get-FileExtensionSize {Path=W:\WorkshopFiles, Top=5} debug-demo.ps1: line 15
debug-demo.ps1        {}                             debug-demo.ps1: line 29
<ScriptBlock>         {}                             <No file>

[DBG]: PS W:\>> o
At W:\debug-demo.ps1:19 char:5
+     $fileGroups | ForEach-Object {
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[DBG]: PS W:\>> q
PS W:\>
```

`s` on line 29 enters the function, and `v` runs the whole pipeline on
line 10 in one step. `k` lists the same frames as **CALL STACK** in VS Code.
`o` leaves the script block of `ForEach-Object`, and with it all its
remaining passes, and stops on line 19. Remove all breakpoints with
`Get-PSBreakpoint | Remove-PSBreakpoint`.

`Wait-Debugger` is a breakpoint inside the code itself. The script stops at
that line and enters the debugger, without `Set-PSBreakpoint`:

```powershell
$files = Get-ChildItem -Path ./WorkshopFiles -Recurse -File
Wait-Debugger
$files.Count
```

Saved as `wait-demo.ps1` in the folder `W:\`, the script stops at
`Wait-Debugger`:

```text
PS W:\> ./wait-demo.ps1
Entering debug mode. Use h or ? for help.

At W:\wait-demo.ps1:2 char:1
+ Wait-Debugger
+ ~~~~~~~~~~~~~
[DBG]: PS W:\>> $files.Count
22
[DBG]: PS W:\>> c
22
PS W:\>
```

> [!CAUTION]
> Remove `Wait-Debugger` when you are done. A script that stops at it waits
> for a debugger and looks hung.

## Common pitfalls

- **A breakpoint in a file that doesn't run.** A line breakpoint belongs to
  one file. When the code runs from a copy, the breakpoint never hits. The
  following session sets a breakpoint in `v1/Get-Square.ps1` but loads the
  function from `v2/Get-Square.ps1`:

  ```text
  PS W:\> $null = Set-PSBreakpoint -Script ./v1/Get-Square.ps1 -Line 3
  PS W:\> . ./v2/Get-Square.ps1
  PS W:\> Get-Square -Number 4
  16
  PS W:\> (Get-Command -Name Get-Square).ScriptBlock.File
  W:\v2\Get-Square.ps1
  PS W:\>
  ```

  The demo project is a typical case. Its build merges the files from
  `source/Public` into one module file below `output/module`, and the tests
  import that built module. A breakpoint in
  `source/Public/Get-FileExtensionSize.ps1` doesn't stop the tests. Set it
  in the built module, or use a function breakpoint.

- **`$_` in a breakpoint action.** The action of a breakpoint, and with it
  every condition and logpoint from VS Code, receives the breakpoint as `$_`.
  A condition such as `$_.Name -eq '.bak'` is never true. This session shows
  what `$_` is inside an action:

  ```text
  PS W:\> $null = Set-PSBreakpoint -Script ./debug-demo.ps1 -Line 16 -Action { Write-Host "`$_ is a $($_.GetType().Name)" }
  PS W:\> $null = ./debug-demo.ps1
  $_ is a LineBreakpoint
  $_ is a LineBreakpoint
  $_ is a LineBreakpoint
  $_ is a LineBreakpoint
  $_ is a LineBreakpoint
  PS W:\>
  ```

  Use named variables in conditions, or read the pipeline object with
  `Get-Variable -Name _ -Scope 1 -ValueOnly`.

- **A stale session.** The Extension Terminal keeps functions, variables,
  and modules between runs, so an old version can answer instead of the
  code in your editor. `Import-Module` doesn't load a module again that is
  already loaded:

  ```powershell
  $moduleFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'StaleDemo.psm1'
  Set-Content -Path $moduleFile -Value 'function Get-Version { 1 }'
  Import-Module -Name $moduleFile
  Set-Content -Path $moduleFile -Value 'function Get-Version { 2 }'
  Import-Module -Name $moduleFile
  Get-Version
  Import-Module -Name $moduleFile -Force
  Get-Version
  ```

  ```text
  1
  2
  ```

  Reload a module with `Import-Module -Force`. For a clean slate, run
  **PowerShell: Restart Session** from the Command Palette, or set
  `"createTemporaryIntegratedConsole": true` in the launch configuration to
  get a new Extension Terminal for each debug session.

## Exercises

The exercises use the sample folder and `debug-demo.ps1` from the
walkthrough. Debug either in VS Code or in the console; the solutions show
console sessions in the folder `W:\`.

### Exercise 1: Find a planted bug

The following version of the function reports the wrong extensions. Save it
as `bug-hunt.ps1`.

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
        Select-Object -First $Top |
        Sort-Object -Property Count -Descending

    $fileGroups | ForEach-Object {
        [PSCustomObject]@{
            Extension = $_.Name
            FileCount = $_.Count
        }
    }
}

$root = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'WorkshopFiles'
Get-FileExtensionSize -Path $root -Top 3
```

1. Run the script. Which extensions does it report, and which should it
   report?
2. Set a breakpoint on line 15, run the script again, and look at
   `$fileGroups`.
3. Fix the bug.

<details>
<summary>Solution</summary>

The script reports three extensions, but not the three most frequent:

```text
PS W:\> ./bug-hunt.ps1

Extension FileCount
--------- ---------
.csv              2
.bak              1
                  1

PS W:\>
```

At the breakpoint, `$fileGroups` holds the groups in the wrong order:

```text
PS W:\> $null = Set-PSBreakpoint -Script ./bug-hunt.ps1 -Line 15
PS W:\> ./bug-hunt.ps1
Entering debug mode. Use h or ? for help.

Hit Line breakpoint on 'W:\bug-hunt.ps1:15'

At W:\bug-hunt.ps1:15 char:5
+     $fileGroups | ForEach-Object {
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[DBG]: PS W:\>> $fileGroups | Select-Object -Property Name, Count

Name Count
---- -----
.csv     2
.bak     1
         1

[DBG]: PS W:\>> q
PS W:\>
```

`Group-Object` returns the groups sorted by name. `Select-Object -First 3`
keeps the first three names, `''`, `.bak`, and `.csv`, before
`Sort-Object` sees the counts. Swap the two commands, so that the pipeline
sorts first and selects second:

```powershell
$fileGroups = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
    Group-Object -Property Extension |
    Sort-Object -Property Count -Descending |
    Select-Object -First $Top
```

With the fix in `bug-hunt.ps1`, the script reports the right extensions:

```text
PS W:\> ./bug-hunt.ps1

Extension FileCount
--------- ---------
.log              6
.TXT              5
.json             4

PS W:\>
```

</details>

### Exercise 2: Stop when a variable changes

1. Set a breakpoint that stops when `debug-demo.ps1` writes a new value to
   `$fileGroups`, without a line number.
2. Run the script. On which line does the debugger stop, and what does
   `$fileGroups` hold at that moment?

<details>
<summary>Solution</summary>

```text
PS W:\> $null = Set-PSBreakpoint -Variable fileGroups -Mode Write
PS W:\> $null = ./debug-demo.ps1
Entering debug mode. Use h or ? for help.

Hit Variable breakpoint on '$fileGroups' (Write access)

At W:\debug-demo.ps1:10 char:5
+     $fileGroups = Get-ChildItem -Path $Path -Recurse -File -ErrorActi …
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[DBG]: PS W:\>> $fileGroups.Count
5
[DBG]: PS W:\>> c
PS W:\>
```

The debugger stops on line 10, the only line that writes `$fileGroups`.
The documentation describes the stop as *before* the write, but in this
session, the variable already holds the five groups. A variable breakpoint
needs no line number: it finds every write, wherever it happens.

</details>

### Exercise 3: Stop only for the .bak group

1. In VS Code, give the breakpoint on line 16 of `debug-demo.ps1` a
   condition that is true only for the group `.bak`.
2. The script calls the function with `-Top 5`. Does the breakpoint hit?
   What do you need to change?
3. Set the same breakpoint in the console with `Set-PSBreakpoint -Action`.

<details>
<summary>Solution</summary>

The condition must read the pipeline object from the scope of the code,
because `$_` in a condition is the breakpoint:
`(Get-Variable -Name _ -Scope 1 -ValueOnly).Name -eq '.bak'`. With
`-Top 5`, the breakpoint never hits: `.bak` has only one file and isn't
among the five most frequent extensions. With `-Top 10`, all seven groups
pass line 16, and the debugger stops once, for `.bak`. In the console, the
action decides with `break` whether to stop:

```text
PS W:\> $null = Set-PSBreakpoint -Script ./debug-demo.ps1 -Line 16 -Action { if ((Get-Variable -Name _ -Scope 1 -ValueOnly).Name -eq '.bak') { break } }
PS W:\> $null = . ./debug-demo.ps1
PS W:\> $null = Get-FileExtensionSize -Path $root -Top 10
Entering debug mode. Use h or ? for help.

Hit Line breakpoint on 'W:\debug-demo.ps1:16'

At W:\debug-demo.ps1:16 char:9
+         $_ | Add-Member -Name Size -MemberType NoteProperty -Value ($ …
+         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
[DBG]: PS W:\>> $_.Name
.bak
[DBG]: PS W:\>> $_.Group.Name
database.bak
[DBG]: PS W:\>> c
PS W:\>
```

Dot-sourcing the script defines the function and `$root` in the session,
and its call with `-Top 5` finishes without a stop. The second call stops
for `.bak` only.

</details>

## Key takeaways

- A launch configuration defines what F5 starts. *PowerShell Interactive
  Session* debugs every command in the PowerShell Extension Terminal.
- VS Code breakpoints are PowerShell breakpoints: conditions, hit counts,
  and logpoints become breakpoint actions.
- VARIABLES, WATCH, and CALL STACK show the state at every stop. Step into
  functions with F11, over them with F10, and out with Shift+F11.
- A function breakpoint is the fastest way into code you don't know.
- In the console, `Set-PSBreakpoint` sets line, variable, and command
  breakpoints, and `s`, `v`, `o`, `c`, and `k` control the debugger.

## Learn more

- [Using Visual Studio Code for PowerShell development](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/vscode/using-vscode)
- [Debugging in VS Code](https://code.visualstudio.com/docs/debugtest/debugging)
- [about_Debuggers](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_debuggers)
- [Set-PSBreakpoint](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/set-psbreakpoint)
  and [Wait-Debugger](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/wait-debugger)
- [PowerShell extension for VS Code](https://marketplace.visualstudio.com/items?itemName=ms-vscode.PowerShell)

---

[← Previous: Splatting](11-splatting.md)
· [Overview](../README.md) ·
[Next: Scaffolding a module with Sampler →](13-scaffolding-a-module-with-sampler.md)
