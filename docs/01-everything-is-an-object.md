# Everything is an object

[Overview](../README.md) › Part 1: PowerShell fundamentals › Topic 1 of 17

PowerShell commands return .NET objects, not text. This topic shows what that
means, how to explore any object with `Get-Member`, and why the same skills
work for dates, files, folders, and everything else in PowerShell.

In this topic, you learn to:

- tell properties from methods, and use both
- explore any object with `Get-Member`
- calculate with dates and time spans
- work with files and folders as objects

## Objects instead of text

Most shells pass text from one command to the next. To get the size of a file
from a directory listing, you cut columns out of lines of text, and the
solution breaks as soon as the output format changes.

PowerShell passes objects. An object carries its data in *properties*, such
as the `Length` of a file, and offers actions as *methods*, such as
`AddDays()` on a date. The console turns objects into text only at the very
end of a pipeline. Until then, every command works with the real data.

```powershell
$christmas = Get-Date -Date '2026-12-24'
$christmas.GetType().FullName
```

```text
System.DateTime
```

`$christmas` is not the text `12/24/2026`. It is a `System.DateTime` object
from .NET, with dozens of properties and methods.

## Explore an object with Get-Member

`Get-Member` lists everything an object offers. With `-MemberType Property`,
it shows only the properties:

```powershell
$christmas | Get-Member -MemberType Property
```

```text
   TypeName: System.DateTime

Name        MemberType Definition
----        ---------- ----------
Date        Property   datetime Date {get;}
Day         Property   int Day {get;}
DayOfWeek   Property   System.DayOfWeek DayOfWeek {get;}
DayOfYear   Property   int DayOfYear {get;}
Hour        Property   int Hour {get;}
Kind        Property   System.DateTimeKind Kind {get;}
Microsecond Property   int Microsecond {get;}
Millisecond Property   int Millisecond {get;}
Minute      Property   int Minute {get;}
Month       Property   int Month {get;}
Nanosecond  Property   int Nanosecond {get;}
Second      Property   int Second {get;}
Ticks       Property   long Ticks {get;}
TimeOfDay   Property   timespan TimeOfDay {get;}
Year        Property   int Year {get;}
```

Read each line from left to right: `DayOfWeek` is a property of the type
`System.DayOfWeek`, and `{get;}` means you can read it but not change it. The
list depends on the .NET version behind PowerShell; Windows PowerShell 5.1,
for example, has no `Microsecond` and `Nanosecond`.

> [!TIP]
> The `TypeName` in the first line is the best search term for the
> documentation. Search for `System.DateTime` on Microsoft Learn, and you find
> every property and method explained, with examples.

## Properties and methods of a date

Properties return data; methods perform an action and need parentheses, even
without arguments. Members called with `::` belong to the type itself rather
than to one object; they are called *static* members.

```powershell
$christmas.DayOfWeek                 # a property
$christmas.AddDays(7).DayOfWeek      # a method that returns a new date
$christmas.ToString('yyyy-MM-dd')    # a method with an argument
[datetime]::IsLeapYear(2028)         # a static method of the type
```

```text
Thursday
Thursday
2026-12-24
True
```

Subtracting two dates returns yet another object, a `TimeSpan`:

```powershell
$christmas - (Get-Date -Date '2026-11-17')
```

```text
Days              : 37
Hours             : 0
Minutes           : 0
Seconds           : 0
Milliseconds      : 0
Ticks             : 31968000000000
TotalDays         : 37
TotalHours        : 888
TotalMinutes      : 53280
TotalSeconds      : 3196800
TotalMilliseconds : 3196800000
```

`Days`, `Hours`, and `Minutes` are the parts of the time span, while
`TotalDays` and `TotalHours` express the whole span in one unit, including
fractions. For "how many days are left", use `.Days`; for "how many hours
in total", use `.TotalHours`.

## Files and folders are objects, too

Everything you just did with dates works the same way with files. The script
[`New-WorkshopFolder.ps1`](../samples/New-WorkshopFolder.ps1) creates a
sample folder with 22 files; run it from the root of this repository:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
```

`Get-Item` returns one file as a `FileInfo` object:

```powershell
$bak = Get-Item -Path (Join-Path -Path $root -ChildPath 'backup/database.bak')
$bak.Length            # the size in bytes
$bak.Length / 1MB      # PowerShell knows the units KB, MB, GB, TB, and PB
$bak.BaseName
$bak.Extension
$bak.Directory.Name    # Directory is a DirectoryInfo object
```

```text
2097152
2
database
.bak
backup
```

`LastWriteTime` is a `DateTime`, so the date arithmetic from above applies.
How long before 17 November 2026 was the backup written?

```powershell
(Get-Date -Date '2026-11-17') - $bak.LastWriteTime
```

```text
Days              : 13
Hours             : 22
Minutes           : 0
Seconds           : 0
Milliseconds      : 0
Ticks             : 12024000000000
TotalDays         : 13.9166666666667
TotalHours        : 334
TotalMinutes      : 20040
TotalSeconds      : 1202400
TotalMilliseconds : 1202400000
```

`Get-ChildItem` returns one object per item, and a folder holds two kinds of
items. `Get-Member` reports both types:

```powershell
Get-ChildItem -Path $root | Get-Member | Select-Object -ExpandProperty TypeName -Unique
```

```text
System.IO.DirectoryInfo
System.IO.FileInfo
```

The console shows only four properties of a file: `Mode`, `LastWriteTime`,
`Length`, and `Name`. A `FileInfo` object has more than 50 members. Choose
the ones you need with `Select-Object`:

```powershell
Get-ChildItem -Path $root -File | Select-Object -Property Name, Length, LastWriteTime
```

```text
Name       Length LastWriteTime
----       ------ -------------
LICENSE        34 9/1/2026 9:00:00 AM
notes.TXT      36 9/2/2026 10:30:00 AM
readme.txt    121 9/1/2026 9:05:00 AM
```

The outputs in these notes come from PowerShell 7.6 with the culture `en-US`.
On a system with another culture, dates look different, for example
`01.09.2026 09:00:00` in German, but the objects are the same.

## Common pitfalls

- **Formatting too early.** `Format-Table` and `Format-List` turn objects
  into formatting instructions. After them, there is no `Name` or `Length`
  left to filter or sort:

  ```powershell
  Get-ChildItem -Path $root -File | Format-Table -Property Name | Get-Member |
      Select-Object -ExpandProperty TypeName -Unique
  ```

  ```text
  Microsoft.PowerShell.Commands.Internal.Format.FormatStartData
  Microsoft.PowerShell.Commands.Internal.Format.GroupStartData
  Microsoft.PowerShell.Commands.Internal.Format.FormatEntryData
  Microsoft.PowerShell.Commands.Internal.Format.GroupEndData
  Microsoft.PowerShell.Commands.Internal.Format.FormatEndData
  ```

  Put `Format-*` commands at the end of a pipeline, or leave them out.

- **A method without parentheses.** `$christmas.ToShortDateString` doesn't
  call the method; it shows its definition:

  ```text
  OverloadDefinitions
  -------------------
  string ToShortDateString()
  ```

  Write `$christmas.ToShortDateString()` to call it.

- **Dates as text.** Compared as strings, `'11/3/2026' -lt '9/1/2026'` is
  `$true`, because the character `1` sorts before `9`. Compare `DateTime`
  objects instead, and the result is `$false`, as it should be:

  ```powershell
  (Get-Date -Date '2026-11-03') -lt (Get-Date -Date '2026-09-01')
  ```

- **Trusting the display.** What the console shows is a selection. When a
  property seems to be missing, it usually isn't: check with `Get-Member` or
  `Select-Object -Property *`.

## Exercises

The exercises use the sample folder from above. If you start a new session,
create it again with `$root = ./samples/New-WorkshopFolder.ps1 -Force`.

### Exercise 1: Explore a date

1. On which day of the week is 1 January 2027?
2. How many days are there from 17 November 2026 to 1 January 2027?
3. Is 2100 a leap year?

<details>
<summary>Solution</summary>

```powershell
$newYear = Get-Date -Date '2027-01-01'
$newYear.DayOfWeek
($newYear - (Get-Date -Date '2026-11-17')).Days
[datetime]::IsLeapYear(2100)
```

```text
Friday
45
False
```

2100 is divisible by 4, but as a full century it is a leap year only when
divisible by 400. The .NET method knows that rule, so you don't have to.

</details>

### Exercise 2: Explore a log file

1. Get the file `logs/app-2026-11-03.log`. Of which type is it, and how big
   is it in KB, rounded to one decimal?
2. How many full days before 17 November 2026 was it last changed?
3. Which properties of the file contain the word `Time`?

<details>
<summary>Solution</summary>

```powershell
$log = Get-Item -Path (Join-Path -Path $root -ChildPath 'logs/app-2026-11-03.log')
$log.GetType().FullName
[math]::Round($log.Length / 1KB, 1)
((Get-Date -Date '2026-11-17') - $log.LastWriteTime).Days
$log | Get-Member -Name *Time* -MemberType Property
```

```text
System.IO.FileInfo
49.2
13

   TypeName: System.IO.FileInfo

Name              MemberType Definition
----              ---------- ----------
CreationTime      Property   datetime CreationTime {get;set;}
CreationTimeUtc   Property   datetime CreationTimeUtc {get;set;}
LastAccessTime    Property   datetime LastAccessTime {get;set;}
LastAccessTimeUtc Property   datetime LastAccessTimeUtc {get;set;}
LastWriteTime     Property   datetime LastWriteTime {get;set;}
LastWriteTimeUtc  Property   datetime LastWriteTimeUtc {get;set;}
```

Without `-MemberType Property`, the wildcard `*Time*` also matches the
methods `GetLifetimeService` and `InitializeLifetimeService`. Life**time**
contains the word, too.

</details>

### Exercise 3: Folder or file?

List every item directly in the sample folder with its name, and whether it
is a folder. Find the property that tells you with `Get-Member`.

<details>
<summary>Solution</summary>

Both `FileInfo` and `DirectoryInfo` objects carry the property
`PSIsContainer`, which PowerShell adds to every item of a drive:

```powershell
Get-ChildItem -Path $root | Select-Object -Property Name, PSIsContainer
```

```text
Name       PSIsContainer
----       -------------
backup              True
config              True
data                True
logs                True
scripts             True
LICENSE            False
notes.TXT          False
readme.txt         False
```

</details>

## Key takeaways

- Every PowerShell command returns objects; the console shows a text view of
  them only at the end of a pipeline.
- `Get-Member` reveals the type, the properties, and the methods of any
  object. The type name leads you to the documentation.
- Properties hold data. Methods perform actions and need parentheses. Static
  members, such as `[datetime]::IsLeapYear()`, belong to the type.
- Date arithmetic returns `TimeSpan` objects; use `Days` for the part and
  `TotalDays` for the whole span.
- Files and folders are `FileInfo` and `DirectoryInfo` objects, and
  `Format-*` commands belong at the end of a pipeline.

## Learn more

- [about_Objects](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_objects)
- [about_Properties](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_properties)
  and [about_Methods](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_methods)
- [Get-Member](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/get-member)
- [PowerShell 101: Discovering objects](https://learn.microsoft.com/powershell/scripting/learn/ps101/03-discovering-objects)
- [DateTime struct](https://learn.microsoft.com/dotnet/api/system.datetime),
  [TimeSpan struct](https://learn.microsoft.com/dotnet/api/system.timespan),
  and [FileInfo class](https://learn.microsoft.com/dotnet/api/system.io.fileinfo)

---

[← Overview](../README.md) ·
[Next: The pipeline, loops, and filters →](02-pipeline-loops-and-filters.md)
