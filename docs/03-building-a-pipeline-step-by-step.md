# Building a pipeline step by step

[Overview](../README.md) › Part 1: PowerShell fundamentals › Topic 3 of 17

Long pipelines aren't written in one go. You build them one command at a time
and look at the output after every step, until the result is right. This topic
builds the running example of the workshop that way and shows how the objects
change from step to step.

In this topic, you learn to:

- build a pipeline one command at a time and check every step
- group objects with `Group-Object` and look inside the groups
- add computed columns with calculated properties
- rank groups by count or by size, and round the results

## The running example

The running example: find the five file extensions that occur most often in a
folder tree. Build such a pipeline one command at a time, and look at the
output after every step.

![The pipeline in five steps: Get-ChildItem, Group-Object, Sort-Object,
Select-Object, and Measure-Object](../assets/diagrams/pipeline-top-extensions.svg)

The workshop used `D:\LabSources`, the AutomatedLab sources folder. Here, you
use the sample folder from
[Everything is an object](01-everything-is-an-object.md), so that your output
matches the output on this page. Run the script from the root of this
repository:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
```

The file objects carry their full paths, which differ on every machine. That's
why the first four steps end with `Select-Object -Property`, which picks the
columns to show.

## Step 1: Get all files

Get all files, including the files in subfolders:

```powershell
Get-ChildItem -Path $root -Recurse -File |
    Select-Object -Property Name, Extension, Length
```

```text
Name               Extension  Length
----               ---------  ------
LICENSE                           34
notes.TXT          .TXT           36
readme.txt         .txt          121
backup-notes.txt   .txt           32
database.bak       .bak      2097152
app.json           .json          76
changes.txt        .txt           30
web.json           .json          83
customers.csv      .csv         1940
orders.csv         .csv        21366
settings.json      .json         199
users.json         .json         190
app-2026-11-01.log .log        30215
app-2026-11-02.log .log        40285
app-2026-11-03.log .log        50352
web-2026-11-03.log .log        20133
app-2026-10-30.log .log        15104
app-2026-10-31.log .log        25201
Get-Report.ps1     .ps1          104
Set-Config.ps1     .ps1           78
Start-Backup.ps1   .ps1           85
todo.txt           .txt           40
```

These are 22 `FileInfo` objects. The `Extension` property is what the next
step groups by. Note the two special cases: `LICENSE` has no extension, and
`notes.TXT` has an upper-case one.

## Step 2: Group by extension

Group them by extension. `Group-Object` returns one `GroupInfo` object per
extension: `Name` is the extension, `Count` the number of files, and `Group`
holds the file objects themselves.

```powershell
Get-ChildItem -Path $root -Recurse -File |
    Group-Object -Property Extension |
    Select-Object -Property Count, Name
```

```text
Count Name
----- ----
    1
    1 .bak
    2 .csv
    4 .json
    6 .log
    3 .ps1
    5 .TXT
```

The 22 files have become 7 groups, sorted by name. The group without a name
holds `LICENSE`. `Get-Member` shows what a `GroupInfo` object offers:

```powershell
$groups = Get-ChildItem -Path $root -Recurse -File | Group-Object -Property Extension
$groups[0] | Get-Member -MemberType Property
```

```text
   TypeName: Microsoft.PowerShell.Commands.GroupInfo

Name   MemberType Definition
----   ---------- ----------
Count  Property   int Count {get;}
Group  Property   System.Collections.ObjectModel.Collection[psobject] Group {get;}
Name   Property   string Name {get;}
Values Property   System.Collections.ArrayList Values {get;}
```

`Group` is a collection of the original objects, so everything you know about
files still works inside a group. Here are the files of the text group:

```powershell
($groups | Where-Object Name -eq '.TXT').Group | Select-Object -Property Name, Extension
```

```text
Name             Extension
----             ---------
notes.TXT        .TXT
readme.txt       .txt
backup-notes.txt .txt
changes.txt      .txt
todo.txt         .txt
```

## Why the text group is named .TXT

`Group-Object` names a group after the first value it puts into it.
`Get-ChildItem` returns the files of the root folder first, and `notes.TXT`
comes before `readme.txt`, so the whole group is called `.TXT`. Two short
lists show the rule:

```powershell
('B', 'b' | Group-Object).Name
('b', 'B' | Group-Object).Name
```

```text
B
b
```

> [!NOTE]
> `Group-Object` ignores case, so `.TXT` and `.txt` end up in the same group.
> Add `-CaseSensitive` to keep them apart.

With `-CaseSensitive`, you get eight groups instead of seven: `.txt` with four
files and `.TXT` with one. For file extensions, ignoring case is usually what
you want: on Windows, `notes.TXT` and `notes.txt` name the same file.

## Step 3: Sort the groups

Sort the groups, the most files first:

```powershell
Get-ChildItem -Path $root -Recurse -File |
    Group-Object -Property Extension |
    Sort-Object -Property Count -Descending |
    Select-Object -Property Count, Name
```

```text
Count Name
----- ----
    6 .log
    5 .TXT
    4 .json
    3 .ps1
    2 .csv
    1
    1 .bak
```

## Step 4: Keep the top five

Keep the first five, and store them for the next step:

```powershell
$top5 = Get-ChildItem -Path $root -Recurse -File |
    Group-Object -Property Extension |
    Sort-Object -Property Count -Descending |
    Select-Object -First 5
$top5 | Select-Object -Property Count, Name
```

```text
Count Name
----- ----
    6 .log
    5 .TXT
    4 .json
    3 .ps1
    2 .csv
```

`$top5` holds the five `GroupInfo` objects, with all the files inside them.
`Select-Object -Property` in the last line only chooses what to show.

## Step 5: Measure each group

Measure each group. `Measure-Object` adds up the `Length` of the files in
`Group`:

```powershell
$top5 | ForEach-Object { ($_.Group | Measure-Object -Property Length -Sum).Sum }
```

```text
181290
259
548
267
23306
```

The sizes come back as bare numbers, without the extension they belong to.
To return both, the workshop took a short detour through
[hashtables](04-hashtables.md) and [custom objects](05-pscustomobject.md). The
result is the function `Get-FileExtensionSize` in
[Your first function](09-your-first-function.md).

## Add a calculated property

`Select-Object` can keep the extension and add the size in one step. Besides
property names, it accepts a *calculated property*: a hashtable with the
`Name` of a new column and an `Expression`, a script block that computes the
value from `$_`:

```powershell
$top5 | Select-Object -Property Name, Count,
    @{ Name = 'Size'; Expression = { ($_.Group | Measure-Object -Property Length -Sum).Sum } }
```

```text
Name  Count      Size
----  -----      ----
.log      6 181290.00
.TXT      5    259.00
.json     4    548.00
.ps1      3    267.00
.csv      2  23306.00
```

`Measure-Object` returns its sum as a `double`, a floating-point number. In a
table, PowerShell 7.6 shows such numbers with two decimals, so the whole bytes
appear as `181290.00`. Kilobytes are easier to read. Divide by `1KB`, and
round with the static method `[math]::Round()`, here to two decimals:

```powershell
$top5 | Select-Object -Property Name, Count, @{
    Name       = 'SizeKB'
    Expression = { [math]::Round(($_.Group | Measure-Object -Property Length -Sum).Sum / 1KB, 2) }
}
```

```text
Name  Count SizeKB
----  ----- ------
.log      6 177.04
.TXT      5   0.25
.json     4   0.54
.ps1      3   0.26
.csv      2  22.76
```

The table would show two decimals without `[math]::Round()`, too, but only
the display would be rounded. The value keeps all its digits, and
`Export-Csv` writes `177.041015625` instead of `177.04`. Round the value when
you pass it on.

## Rank by size instead of count

The five most frequent extensions aren't the five largest. To rank by size,
sort the groups by their total size. `Sort-Object` accepts a script block
instead of a property name:

```powershell
Get-ChildItem -Path $root -Recurse -File |
    Group-Object -Property Extension |
    Sort-Object -Property { ($_.Group | Measure-Object -Property Length -Sum).Sum } -Descending |
    Select-Object -First 5 -Property Count, Name
```

```text
Count Name
----- ----
    1 .bak
    6 .log
    2 .csv
    4 .json
    3 .ps1
```

A single backup file now leads the list, and the five small text files drop
out.

## The workshop one-liner

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

## Common pitfalls

- **Folders counted without `-File`.** In the sample folder, five folders
  join `LICENSE` in the group without an extension, and the folder
  `archive.old` creates a group `.old`. The nameless group ties for first
  place, and `.csv` drops out of the top five:

  ```powershell
  Get-ChildItem -Path $root -Recurse |
      Group-Object -Property Extension |
      Sort-Object -Property Count -Descending |
      Select-Object -Property Count, Name
  ```

  ```text
  Count Name
  ----- ----
      6
      6 .log
      5 .TXT
      4 .json
      3 .ps1
      2 .csv
      1 .bak
      1 .old
  ```

- **`Select-Object -First` before `Sort-Object`.** The order of the commands
  matters. Selected first, the five groups are simply the first five by
  name, and sorting them afterwards can't bring back `.TXT` and `.ps1`:

  ```powershell
  Get-ChildItem -Path $root -Recurse -File |
      Group-Object -Property Extension |
      Select-Object -First 5 |
      Sort-Object -Property Count -Descending |
      Select-Object -Property Count, Name
  ```

  ```text
  Count Name
  ----- ----
      6 .log
      4 .json
      2 .csv
      1
      1 .bak
  ```

- **Forgetting `-Recurse`.** Without it, `Get-ChildItem` reads only the top
  folder: three files in two groups. The result still looks plausible, which
  makes the mistake easy to miss. Compare the number of files with what you
  expect.

- **Floating-point sums.** `Measure-Object` adds up `double` values, and a
  decimal fraction often can't be stored exactly as a `double`. The 800
  amounts in `data/orders.csv` have two decimals each, but their sum doesn't:

  ```powershell
  $orders = Import-Csv -Path (Join-Path -Path $root -ChildPath 'data/orders.csv')
  ($orders | Measure-Object -Property Amount -Sum).Sum
  [math]::Round(($orders | Measure-Object -Property Amount -Sum).Sum, 2)
  ```

  ```text
  208191.999999998
  208192
  ```

  Round sums before you report them. For an exact total, calculate with
  `[decimal]`, as [CSV, JSON, and YAML](06-csv-json-and-yaml.md) shows.

- **Rounding at the midpoint.** `[math]::Round()` rounds a value that lies
  exactly halfway to the nearest even number, a convention called
  *banker's rounding*. To round halves away from zero, as most people learn at
  school, pass `AwayFromZero`:

  ```powershell
  [math]::Round(2.5)
  [math]::Round(3.5)
  [math]::Round(2.5, [MidpointRounding]::AwayFromZero)
  ```

  ```text
  2
  4
  3
  ```

## Exercises

The exercises use the sample folder from above. If you start a new session,
create it again with `$root = ./samples/New-WorkshopFolder.ps1 -Force`.

### Exercise 1: The largest extensions

Find the three extensions that use the most space. Show the extension, the
number of files, and the total size in KB, rounded to two decimals.

<details>
<summary>Solution</summary>

```powershell
Get-ChildItem -Path $root -Recurse -File |
    Group-Object -Property Extension |
    Select-Object -Property Name, Count, @{
        Name       = 'SizeKB'
        Expression = { [math]::Round(($_.Group | Measure-Object -Property Length -Sum).Sum / 1KB, 2) }
    } |
    Sort-Object -Property SizeKB -Descending |
    Select-Object -First 3
```

```text
Name Count  SizeKB
---- -----  ------
.bak     1 2048.00
.log     6  177.04
.csv     2   22.76
```

The calculated property creates the column `SizeKB`, and because it is a
real property now, `Sort-Object` can sort by its name. The order matters
again: calculate, sort, and only then select the first three.

</details>

### Exercise 2: Files per folder

1. Count the files in each folder of the sample tree, the fullest folder
   first.
2. Which property of a file leads you to the name of its folder?

<details>
<summary>Solution</summary>

`Group-Object` accepts a script block as well as a property name. A file's
`Directory` property is a `DirectoryInfo` object, and its `Name` is the
folder name:

```powershell
Get-ChildItem -Path $root -Recurse -File |
    Group-Object -Property { $_.Directory.Name } |
    Sort-Object -Property Count -Descending |
    Select-Object -Property Count, Name
```

```text
Count Name
----- ----
    4 data
    4 logs
    4 scripts
    3 config
    3 WorkshopFiles
    2 archive.old
    2 backup
```

`WorkshopFiles` is the root of the sample tree. Two folders with the same name
in different places would end up in one group; group by
`{ $_.Directory.FullName }` to keep them apart.

</details>

### Exercise 3: The newest file per extension

For every extension, show the most recently changed file with its extension,
name, and `LastWriteTime`.

<details>
<summary>Solution</summary>

Sort the files inside each group, and keep the first one:

```powershell
Get-ChildItem -Path $root -Recurse -File |
    Group-Object -Property Extension |
    ForEach-Object { $_.Group | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1 } |
    Select-Object -Property Extension, Name, LastWriteTime
```

```text
Extension Name               LastWriteTime
--------- ----               -------------
          LICENSE            9/1/2026 9:00:00 AM
.bak      database.bak       11/3/2026 2:00:00 AM
.csv      orders.csv         11/3/2026 6:00:00 PM
.json     users.json         10/20/2026 11:20:00 AM
.log      app-2026-11-03.log 11/3/2026 11:59:00 PM
.ps1      Start-Backup.ps1   9/17/2026 4:00:00 PM
.txt      backup-notes.txt   11/3/2026 2:05:00 AM
```

The output shows the files, not the groups, so the extension is the file's
own: `.txt`, although the group is named `.TXT`.

</details>

## Key takeaways

- Build a pipeline one command at a time, and look at the output after every
  step. `Get-Member` tells you what the next command receives.
- `Group-Object` returns `GroupInfo` objects with `Name`, `Count`, and
  `Group`, which holds the original objects. It ignores case and names each
  group after the first value it sees.
- A calculated property, `@{ Name = '...'; Expression = { ... } }`, adds a
  computed column in `Select-Object`; `Sort-Object` and `Group-Object` accept
  script blocks, too.
- The order of the commands matters: calculate, sort, and then select.
- Use `-File` and `-Recurse` deliberately, and round with `[math]::Round()`
  before you pass a value on.

## Learn more

- [Group-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/group-object)
- [Sort-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/sort-object)
- [Select-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/select-object)
- [Measure-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/measure-object)
- [about_Calculated_Properties](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_calculated_properties)
- [Math.Round method](https://learn.microsoft.com/dotnet/api/system.math.round)
- [PSScriptAnalyzer rule AvoidUsingCmdletAliases](https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/rules/avoidusingcmdletaliases)

---

[← Previous: The pipeline, loops, and filters](02-pipeline-loops-and-filters.md)
· [Overview](../README.md) ·
[Next: Hashtables →](04-hashtables.md)
