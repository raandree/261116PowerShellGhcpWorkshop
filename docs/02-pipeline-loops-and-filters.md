# The pipeline, loops, and filters

[Overview](../README.md) › Part 1: PowerShell fundamentals › Topic 2 of 17

The pipeline joins commands, so that each command works on the objects of the
command before it. This topic shows how `ForEach-Object` and `Where-Object`
reach each of those objects, which kind of loop fits which task, and why you
filter as early as you can.

In this topic, you learn to:

- work with the current object through `$_`
- filter objects with `Where-Object` and process them with `ForEach-Object`
- choose between the `foreach` statement, `ForEach-Object`, and the methods
  `.ForEach()` and `.Where()`
- filter left with parameters such as `-Filter`
- search log files with `Select-String`

## One object at a time

The pipeline operator `|` passes objects from one command to the next, one at
a time. In the script blocks of `ForEach-Object` and `Where-Object`, the
automatic variable `$_` holds the current object. `$PSItem` is the same
variable with a longer, more readable name.

A *script block* is code in braces that a command runs for you, here once for
every object. An *automatic variable* is a variable that PowerShell sets by
itself.

![Where-Object receives the numbers 1 to 10 one at a time, keeps 8, 9, and 10,
and drops the rest](../assets/diagrams/dollar-underscore.svg)

```powershell
$a = 1..10
$a | ForEach-Object { "Test $_" }             # runs once for every number
$a | Where-Object { $_ -gt 7 }                # keeps 8, 9, and 10
$a | ForEach-Object { if ($_ -gt 7) { $_ } }  # same result, more code
```

The range operator `..` creates the numbers 1 to 10. The first pipeline
returns `Test 1` to `Test 10`, and the other two return 8, 9, and 10.
`ForEach-Object` with an `if` can filter, too, but `Where-Object` states the
intent.

> [!WARNING]
> An `else` branch needs the `else` keyword. In
> `ForEach-Object { if ($_ -gt 7) { $_ } {} }`, the trailing `{}` is a script
> block that PowerShell outputs for every number: you get 8, 9, and 10 plus
> ten script blocks.

Count the objects and their types to see the extra script blocks:

```powershell
$result = $a | ForEach-Object { if ($_ -gt 7) { $_ } {} }
$result.Count
$result | ForEach-Object { $_.GetType().Name } | Group-Object | Select-Object -Property Count, Name
```

```text
13

Count Name
----- ----
    3 Int32
   10 ScriptBlock
```

With `else` in front of it, the second script block runs only for the numbers
1 to 7: `if ($_ -gt 7) { $_ } else { "$_ is too small" }`.

## How the pipeline streams objects

"One at a time" has a practical meaning: a command doesn't wait until the
command before it has finished. As soon as the first command sends an object,
the next command processes it. `Write-Host` writes straight to the console,
not to the pipeline, so you can watch the order:

```powershell
1..3 |
    ForEach-Object { Write-Host "Step 1 sends $_"; $_ } |
    ForEach-Object { Write-Host "Step 2 receives $_" }
```

```text
Step 1 sends 1
Step 2 receives 1
Step 1 sends 2
Step 2 receives 2
Step 1 sends 3
Step 2 receives 3
```

Streaming saves memory, and you see the first results while the rest is still
on its way. Some commands can't work that way. `Sort-Object` must see every
object before it knows which one comes first, so it collects all objects and
only then passes them on. `Group-Object` behaves the same.

```powershell
1..3 |
    ForEach-Object { Write-Host "Step 1 sends $_"; $_ } |
    Sort-Object -Descending |
    ForEach-Object { Write-Host "Step 3 receives $_" }
```

```text
Step 1 sends 1
Step 1 sends 2
Step 1 sends 3
Step 3 receives 3
Step 3 receives 2
Step 3 receives 1
```

`Select-Object -First` works the other way round. As soon as it has enough
objects, PowerShell stops the commands before it. That's why
`Get-ChildItem -Recurse | Select-Object -First 5` returns after five items
instead of walking the whole folder tree.

## Filter with Where-Object

The examples from here on use the sample folder from
[Everything is an object](01-everything-is-an-object.md). Run the script from
the root of this repository:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
$files = Get-ChildItem -Path $root -Recurse -File
```

`Where-Object` keeps every object for which its script block returns `$true`.
Which files are larger than 40 KB?

```powershell
$files | Where-Object { $_.Length -gt 40KB } | Select-Object -Property Name, Length
```

```text
Name                Length
----                ------
database.bak       2097152
app-2026-11-03.log   50352
```

Since Windows PowerShell 3.0, `Where-Object` also has a *simplified syntax*
that reads almost like a sentence. Name the property, the operator, and the
value, without braces and without `$_`:

```powershell
$files | Where-Object Length -gt 40KB | Select-Object -Property Name, Length
```

It returns the same two files. The simplified syntax compares one property
with one value. For two or more conditions, use a script block with `-and` or
`-or`:

```powershell
$files | Where-Object { $_.Extension -eq '.log' -and $_.Length -gt 30KB } |
    Select-Object -Property Name, Length
```

```text
Name               Length
----               ------
app-2026-11-02.log  40285
app-2026-11-03.log  50352
```

## Filter left

Filter as early as possible, ideally with a parameter of the first command,
such as `Get-ChildItem -Filter *.log`. PowerShell 101 calls this
*filter left*. Both commands below find the six log files of the sample
folder:

```powershell
(Get-ChildItem -Path $root -Recurse -Filter *.log).Count
(Get-ChildItem -Path $root -Recurse | Where-Object Extension -eq '.log').Count
```

```text
6
6
```

The result is the same, but the work behind it is not. With `-Filter`, the
file system applies the pattern while PowerShell reads the folders, so
PowerShell creates objects for the six log files only. With `Where-Object`,
PowerShell first creates an object for each of the 28 files and folders, and
then throws most of them away. The more files a folder tree holds, the more
that counts.

`-Filter` takes a single pattern with the wildcards `*` and `?`. On Windows,
it ignores case: `-Filter *.txt` finds `notes.TXT`, too. For anything more
complex, filter with `Where-Object`, but as early in the pipeline as you can.

Build a pipeline like this in the console, one command at a time, and check
the output after every step. `Get-History` lists the commands of the current
session, which makes it easy to copy a working pipeline into a script:

```powershell
Get-History -Count 5                                # the last five commands
(Get-History -Id 12).CommandLine | Set-Clipboard    # copy command 12
```

## Process objects with ForEach-Object

`ForEach-Object` runs its script block, the parameter `-Process`, once for
every object. Two more script blocks are optional: `-Begin` runs once before
the first object, and `-End` once after the last one. This counts the log
files:

```powershell
Get-ChildItem -Path $root -Recurse -Filter *.log |
    ForEach-Object -Begin { $count = 0 } -Process { $count++ } -End { "$count log files" }
```

```text
6 log files
```

The script blocks run in your scope, so `$count` still holds 6 after the
command. Functions use the same three blocks to accept pipeline input; see
[Pipeline input](10-pipeline-input.md).

`ForEach-Object` has a simplified syntax, too: with the name of a property,
such as `ForEach-Object BaseName`, it returns the value of that property for
every object.

## The foreach statement

PowerShell has another way to loop: the `foreach` *statement*, a keyword of
the language rather than a command. It loops over a collection that is
already in memory and gives the current item a name of your choice:

```powershell
$logs = Get-ChildItem -Path $root -Recurse -Filter *.log
foreach ($log in $logs) {
    $lines = Get-Content -Path $log.FullName
    $log.Name + ': ' + $lines.Count + ' lines'
}
```

```text
app-2026-11-01.log: 600 lines
app-2026-11-02.log: 800 lines
app-2026-11-03.log: 1000 lines
web-2026-11-03.log: 400 lines
app-2026-10-30.log: 300 lines
app-2026-10-31.log: 500 lines
```

The same task with `ForEach-Object`, in the middle of a pipeline, returns the
same six lines:

```powershell
Get-ChildItem -Path $root -Recurse -Filter *.log |
    ForEach-Object { $_.Name + ': ' + (Get-Content -Path $_.FullName).Count + ' lines' }
```

Which one should you use? It depends on where your data is:

| Loop                | Input                                   | Current item        | Speed      | Use it for                                     |
|---------------------|-----------------------------------------|---------------------|------------|------------------------------------------------|
| `foreach` statement | A collection in a variable              | A variable you name | Fastest    | Loops in scripts over data you already have    |
| `ForEach-Object`    | Objects from the pipeline, as they come | `$_`                | Slowest    | Pipelines, especially with large or slow input |
| `.ForEach()` method | A collection in a variable              | `$_`                | In between | Short expressions on a variable                |

The differences in speed show only with many objects. In a test for these
notes, the `foreach` statement doubled 200,000 numbers in less than a tenth of
a second, several times faster than `ForEach-Object`. For a few hundred files,
readable code matters more.

## The .Where() and .ForEach() methods

Arrays and other collections have two built-in methods, `.Where()` and
`.ForEach()`. They take a script block with `$_`, like the cmdlets, but work
on a collection in memory instead of a pipeline:
`$files.Where({ $_.Length -gt 40KB })` returns the same two files as
`Where-Object` above.

`.Where()` has modes that `Where-Object` lacks: `First`, `Last`, `SkipUntil`,
`Until`, and `Split`. `Split` returns two collections, the matching objects
and the rest. With the name of a property, `.ForEach()` returns its values:

```powershell
$files.Where({ $_.Extension -eq '.json' }, 'First').Name
$small, $large = $files.Where({ $_.Length -lt 1KB }, 'Split')
$small.Count
$large.Count
$large.Where({ $_.Extension -eq '.csv' }).ForEach('Name')
```

```text
app.json
13
9
customers.csv
orders.csv
```

## Search text with Select-String

`Where-Object` filters objects; `Select-String` filters lines of text, much
like `grep` in Unix or `findstr` in Windows. It returns one `MatchInfo`
object per matching line, with properties such as `Filename`, `LineNumber`,
and `Line`:

```powershell
$log = Join-Path -Path $root -ChildPath 'logs/app-2026-11-03.log'
Select-String -Path $log -Pattern 'ERROR' | Select-Object -First 3 -Property LineNumber, Line
```

```text
LineNumber Line
---------- ----
        25 2026-11-03 08:14:48 ERROR Connection to database failed
        50 2026-11-03 08:30:13 ERROR Connection to database failed
        75 2026-11-03 08:45:38 ERROR Connection to database failed
```

`-Pattern` is a *regular expression*, a pattern language for text:
`ERROR|WARN` finds lines with either word. Add `-SimpleMatch` to search for
the exact text instead. Matches ignore case unless you add `-CaseSensitive`,
and `-Quiet` returns only whether the pattern occurs:

```powershell
(Select-String -Path $log -Pattern 'ERROR|WARN').Count
(Select-String -Path $log -Pattern 'error').Count
(Select-String -Path $log -Pattern 'error' -CaseSensitive).Count
Select-String -Path $log -Pattern 'database' -Quiet
```

```text
120
40
0
True
```

`Select-String` also accepts files from the pipeline, so you can filter left
with `Get-ChildItem -Filter *.log` and then search all log files at once.
Exercise 2 does exactly that.

## Common pitfalls

- **`$_` in a nested script block.** Every script block that processes
  objects sets its own `$_`. Inside the inner `Where-Object` below, `$_` is
  the person, not the department, and the count is 0 for both departments:

  ```powershell
  $people = Import-Csv -Path ./samples/People.csv -Delimiter ';'
  'IT', 'HR' | ForEach-Object {
      ($people | Where-Object { $_.Department -eq $_ }).Count
  }
  ```

  Save the outer object in a variable before you start the inner pipeline:

  ```powershell
  'IT', 'HR' | ForEach-Object {
      $department = $_
      $count = ($people | Where-Object { $_.Department -eq $department }).Count
      "$department has $count people"
  }
  ```

  ```text
  IT has 9 people
  HR has 5 people
  ```

- **`$_` outside a pipeline.** PowerShell sets `$_` only where it processes
  one object after another: in `ForEach-Object` and `Where-Object`, in the
  methods `.ForEach()` and `.Where()`, in a `switch` statement, in a `catch`
  block, and in a few more places that about_PSItem lists. Everywhere else,
  `$_` is empty, including the `foreach` statement:

  ```powershell
  foreach ($number in 1..3) { "Number: $_" }
  ```

  ```text
  Number:
  Number:
  Number:
  ```

  In a `foreach` statement, use the loop variable, here `$number`.

- **`foreach`, the statement, and `foreach`, the alias.** At the start of a
  statement, `foreach` is the keyword. After a `|`, it is an alias of
  `ForEach-Object`, just like `%`; `Get-Alias -Definition ForEach-Object`
  lists both. The statement can't feed a pipeline directly:
  `foreach ($n in 3, 1, 2) { $n * 10 } | Sort-Object` fails with
  *An empty pipe element is not allowed*. Store the result in a variable
  first, or wrap the statement in `$( )`:

  ```powershell
  $(foreach ($n in 3, 1, 2) { $n * 10 }) | Sort-Object
  ```

- **`break` in `ForEach-Object`.** `ForEach-Object` is a command, not a loop,
  so `break` and `continue` don't refer to it. They look for an enclosing loop
  and, if there is none, stop the whole script. To skip to the next object,
  use `return`:

  ```powershell
  1..5 | ForEach-Object {
      if ($_ -eq 3) { return }
      $_
  }
  'after the loop'
  ```

  ```text
  1
  2
  4
  5
  after the loop
  ```

  With `break` instead of `return`, a script prints `1` and `2` and then
  ends, without `after the loop`.

## Exercises

The exercises use the sample folder from above. If you start a new session,
create it again with `$root = ./samples/New-WorkshopFolder.ps1 -Force`.

### Exercise 1: Find large log files

1. List the log files that are larger than 40 KB, with their names and sizes.
   Filter left.
2. Lower the limit to 20 KB, and sort the result, the largest file first.
3. Write the filter once with a script block and once with the simplified
   syntax.

<details>
<summary>Solution</summary>

```powershell
Get-ChildItem -Path $root -Recurse -Filter *.log |
    Where-Object Length -gt 40KB |
    Select-Object -Property Name, Length
```

```text
Name               Length
----               ------
app-2026-11-03.log  50352
```

```powershell
Get-ChildItem -Path $root -Recurse -Filter *.log |
    Where-Object { $_.Length -gt 20KB } |
    Sort-Object -Property Length -Descending |
    Select-Object -Property Name, Length
```

```text
Name               Length
----               ------
app-2026-11-03.log  50352
app-2026-11-02.log  40285
app-2026-11-01.log  30215
app-2026-10-31.log  25201
```

`-Filter *.log` lets the file system skip everything that isn't a log file.
The first solution uses the simplified syntax and the second a script block;
both work in either place. `web-2026-11-03.log` is missing from the second
list: with 20,133 bytes, it is just below 20 KB, which is 20,480 bytes.

</details>

### Exercise 2: Count the errors

1. How many lines with `ERROR` do all log files contain together?
2. How many does each file contain, and which file contains the most?

<details>
<summary>Solution</summary>

```powershell
(Get-ChildItem -Path $root -Recurse -Filter *.log | Select-String -Pattern 'ERROR').Count
```

```text
144
```

```powershell
Get-ChildItem -Path $root -Recurse -Filter *.log |
    Select-String -Pattern 'ERROR' |
    Group-Object -Property Filename |
    Sort-Object -Property Count -Descending |
    Select-Object -Property Count, Name
```

```text
Count Name
----- ----
   40 app-2026-11-03.log
   32 app-2026-11-02.log
   24 app-2026-11-01.log
   20 app-2026-10-31.log
   16 web-2026-11-03.log
   12 app-2026-10-30.log
```

Every `MatchInfo` object knows the file it comes from, so `Group-Object` can
count the matches per file. Sorted by count, the first line answers the
second question: `app-2026-11-03.log` contains 40 errors.

</details>

### Exercise 3: Add up the file sizes

1. Calculate the total size of all files in the sample folder with
   `ForEach-Object -Begin -Process -End`.
2. Calculate it again with `Measure-Object`. What else can `Measure-Object`
   tell you about the sizes?

<details>
<summary>Solution</summary>

```powershell
Get-ChildItem -Path $root -Recurse -File |
    ForEach-Object -Begin { $total = 0 } -Process { $total += $_.Length } -End { $total }
```

```text
2302856
```

```powershell
Get-ChildItem -Path $root -Recurse -File |
    Measure-Object -Property Length -Sum -Average -Maximum -Minimum
```

```text
Count             : 22
Average           : 104675.272727273
Sum               : 2302856
Maximum           : 2097152
Minimum           : 30
StandardDeviation :
Property          : Length
```

Both return 2,302,856 bytes. `Measure-Object` states the intent in one
command and counts the files on the way. `-Begin -Process -End` is worth
knowing for calculations that `Measure-Object` doesn't offer, and it is the
same pattern that functions use for pipeline input.

</details>

## Key takeaways

- The pipeline passes objects one at a time. In `ForEach-Object` and
  `Where-Object`, `$_` or `$PSItem` is the current object.
- `Where-Object` filters and `ForEach-Object` processes. The simplified syntax
  handles one comparison; a script block handles everything else.
- Filter left: a parameter such as `-Filter` is faster than `Where-Object`,
  because PowerShell creates fewer objects.
- Use the `foreach` statement for data in a variable, `ForEach-Object` inside
  a pipeline, and `.Where()` and `.ForEach()` for short expressions.
- `Sort-Object` waits for all objects; `Select-Object -First` stops the
  pipeline early.
- `Select-String` searches text with regular expressions and returns
  `MatchInfo` objects that you can group and count.

## Learn more

- [about_Pipelines](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_pipelines)
- [about_Automatic_Variables](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_automatic_variables)
  and [about_PSItem](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_psitem)
- [ForEach-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/foreach-object)
  and [Where-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/where-object)
- [PowerShell 101: One-liners and the pipeline](https://learn.microsoft.com/powershell/scripting/learn/ps101/04-pipelines#filter-left)
- [about_Foreach](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_foreach)
- [about_Arrays: the Where() and ForEach() methods](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_arrays)
- [Select-String](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/select-string)
  and [Get-History](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/get-history)
- [about_Break](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_break)
  and [about_Continue](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_continue)

---

[← Previous: Everything is an object](01-everything-is-an-object.md)
· [Overview](../README.md) ·
[Next: Building a pipeline step by step →](03-building-a-pipeline-step-by-step.md)
