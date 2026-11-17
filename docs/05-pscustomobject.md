# PSCustomObject

[Overview](../README.md) › Part 1: PowerShell fundamentals › Topic 5 of 17

A hashtable stores values under keys, but it makes a poor record. A
`PSCustomObject` holds the same data as real properties, so every command
that works with objects works with it, too. This topic shows how to create
custom objects, how to build them from other objects, and how to work with
whole lists of them.

In this topic, you learn to:

- create custom objects with `[pscustomobject]`
- control the order of their properties
- build new objects with `Select-Object` and calculated properties
- sort, group, and measure lists of custom objects
- convert objects to hashtables and back

## From hashtable to object

In [Hashtables](04-hashtables.md), two people stored as hashtables came back
as one long list of key-value pairs, in no particular order.
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

The `Age` column is right-aligned because the values are numbers: an object
keeps the type of every value, while text formats such as CSV don't. The
table compares both data structures:

|                | Hashtable `@{}`                         | PSCustomObject `[pscustomobject]@{}`   |
|----------------|-----------------------------------------|----------------------------------------|
| What it is     | A collection of key-value pairs         | An object with properties              |
| Order          | Not defined; use `[ordered]` to keep it | The order in which you defined it      |
| Default output | One row per key-value pair              | A table or list of the properties      |
| Add an entry   | Assign it: `$h.NewKey = 'value'`        | `Add-Member`; plain assignment fails   |
| Typical use    | Lookups, settings, splatting            | Records, function output, CSV and JSON |

## Keep the property order

The order in the table above is no coincidence. When you cast a hashtable
*literal*, the text between `@{` and `}`, PowerShell creates the properties
in the order you typed them. A hashtable in a variable has already lost that
order, and the cast keeps whatever order the hashtable has. That order can
change from one session to the next, so yours may differ:

```powershell
$hash = @{ GivenName = 'John'; LastName = 'Doe'; Age = 40; Department = 'IT' }
[pscustomobject]$hash
```

```text
Department Age LastName GivenName
---------- --- -------- ---------
IT          40 Doe      John
```

The same happens when you wrap the literal in parentheses. When you build
the properties step by step, for example in a loop, collect them in an
ordered dictionary. `[ordered]` remembers the order in which you added the
keys, and the cast keeps it:

```powershell
$ordered = [ordered]@{}
$ordered.GivenName = 'John'
$ordered.LastName = 'Doe'
$ordered.Age = 40
$ordered.Department = 'IT'
[pscustomobject]$ordered
```

```text
GivenName LastName Age Department
--------- -------- --- ----------
John      Doe       40 IT
```

## Create objects with Select-Object

`Select-Object -Property` does more than hide columns: it creates new custom
objects that carry only the properties you name. A *calculated property* adds
a property of your own. It is a hashtable with a `Name` and an `Expression`,
a script block in which `$_` is the current input object.

The sample folder from [Everything is an object](01-everything-is-an-object.md)
provides the input. Create it from the root of this repository, and report
the name, the size in KB, and the age in days of every log file:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
$today = Get-Date -Date '2026-11-17'
$logs = Get-ChildItem -Path $root -Recurse -File -Filter *.log |
    Select-Object -Property Name,
        @{ Name = 'SizeKB'; Expression = { [math]::Round($_.Length / 1KB, 1) } },
        @{ Name = 'AgeDays'; Expression = { ($today - $_.LastWriteTime).Days } }
$logs
```

```text
Name               SizeKB AgeDays
----               ------ -------
app-2026-11-01.log  29.50      15
app-2026-11-02.log  39.30      14
app-2026-11-03.log  49.20      13
web-2026-11-03.log  19.70      13
app-2026-10-30.log  14.80      17
app-2026-10-31.log  24.60      16
```

The age is measured from a fixed date, 17 November 2026, so your results
match these notes; use `Get-Date` without parameters for the real age. In a
table, PowerShell 7.6 shows a decimal number of the type `[double]` with two
decimals. Only the display changes: `$logs[0].SizeKB` still returns `29.5`.

The new objects are no longer files. The methods of a `FileInfo` object, such
as `Delete()`, and every property you didn't select are gone. Select what you
need, but select it as late as possible.

## Build objects in a loop

`Select-Object` is the quickest way to pick, rename, and calculate a few
properties. When you compute several values, or combine data from several
sources, create the object yourself with `[pscustomobject]` inside
`ForEach-Object`. Functions return their results the same way, as you see in
[Your first function](09-your-first-function.md).

```powershell
$report = Get-ChildItem -Path $root -Recurse -File | ForEach-Object {
    [pscustomobject]@{
        Name    = $_.Name
        Folder  = $_.Directory.Name
        SizeKB  = [math]::Round($_.Length / 1KB, 1)
        AgeDays = ($today - $_.LastWriteTime).Days
    }
}
$report.Count
$report | Select-Object -First 5
```

```text
22

Name             Folder         SizeKB AgeDays
----             ------         ------ -------
LICENSE          WorkshopFiles    0.00      76
notes.TXT        WorkshopFiles    0.00      75
readme.txt       WorkshopFiles    0.10      76
backup-notes.txt backup           0.00      13
database.bak     backup        2048.00      13
```

The hashtable literal inside the loop keeps the order of the properties, so
every row has the same columns in the same order. `WorkshopFiles` is the
name of the sample folder itself, for the three files in its root.

Objects like these are also what export commands expect: every property
becomes a column in a CSV file or a key in a JSON document.
[CSV, JSON, and YAML](06-csv-json-and-yaml.md) shows how to write and read
these formats.

## Work with lists of objects

`$report` is an array of 22 custom objects, and every `*-Object` command
works with it. Sort it to find the largest files:

```powershell
$report | Sort-Object -Property SizeKB -Descending | Select-Object -First 3
```

```text
Name               Folder  SizeKB AgeDays
----               ------  ------ -------
database.bak       backup 2048.00      13
app-2026-11-03.log logs     49.20      13
app-2026-11-02.log logs     39.30      14
```

Group it to count the files per folder:

```powershell
$report | Group-Object -Property Folder | Sort-Object -Property Count -Descending |
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

Measure it to get the sum, the average, and the maximum in one step. The
values you didn't ask for, `Minimum` and `StandardDeviation`, stay empty:

```powershell
$report | Measure-Object -Property SizeKB -Sum -Average -Maximum
```

```text
Count             : 22
Average           : 102.222727272727
Sum               : 2248.9
Maximum           : 2048
Minimum           :
StandardDeviation :
Property          : SizeKB
```

To read one property of every object, use the property on the array itself.
PowerShell calls this *member-access enumeration*: `$report.Name` returns the
`Name` of every object in `$report`. These are the files that changed in the
two weeks before 17 November:

```powershell
($report | Where-Object -Property AgeDays -LT 14).Name
```

```text
backup-notes.txt
database.bak
orders.csv
app-2026-11-03.log
web-2026-11-03.log
```

## From object to hashtable and back

Sometimes you need a hashtable after all: to add or remove keys freely, or to
pass the values as parameters, as in [Splatting](11-splatting.md). Every
object has a hidden property `PSObject` that lists its properties with their
names and values; [Inspecting and extending objects](07-inspecting-and-extending-objects.md)
explains it in detail. Copy the properties into an ordered dictionary, change
it, and cast it back into an object:

```powershell
$person = [pscustomobject]@{ GivenName = 'John'; LastName = 'Doe'; Age = 40 }
$hash = [ordered]@{}
foreach ($property in $person.PSObject.Properties) {
    $hash[$property.Name] = $property.Value
}
$hash.Remove('Age')
$hash.Email = 'john.doe@example.com'
[pscustomobject]$hash
```

```text
GivenName LastName Email
--------- -------- -----
John      Doe      john.doe@example.com
```

The result is a new object. `$person` itself is unchanged and still has its
`Age`.

## Common pitfalls

- **Assigning a new property.** A custom object accepts new values for its
  existing properties, but it doesn't grow a new property by assignment:

  ```powershell
  $person.Email = 'john.doe@example.com'
  ```

  ```text
  SetValueInvocationException: Exception setting "Email": "The property 'Email' cannot be found on this object. Verify that the property exists and can be set."
  ```

  Add the property with `Add-Member`, as shown in
  [Inspecting and extending objects](07-inspecting-and-extending-objects.md),
  or create the object with every property from the start, with `$null` for
  the values you fill in later.

- **Comparing objects with `-eq`.** Two custom objects are equal only when
  they are the same object. Equal values are not enough:

  ```powershell
  $a = [pscustomobject]@{ Name = 'JDoe'; City = 'Berlin' }
  $b = [pscustomobject]@{ Name = 'JDoe'; City = 'Berlin' }
  $a -eq $b
  $a.Name -eq $b.Name
  ```

  ```text
  False
  True
  ```

  Compare the properties you care about, or let `Compare-Object` do it:
  `Compare-Object -ReferenceObject $a -DifferenceObject $b -Property Name, City`
  returns nothing when the values match.

- **Property names with spaces.** Quote such a name, both when you create
  the property and when you read it. Better still, rename it with a
  calculated property:

  ```powershell
  $row = [pscustomobject]@{ 'Full Name' = 'John Doe'; 'Hire Date' = '2015-03-01' }
  $row.'Full Name'
  $row | Select-Object -Property @{ Name = 'FullName'; Expression = { $_.'Full Name' } }
  ```

  ```text
  John Doe

  FullName
  --------
  John Doe
  ```

- **Objects with different properties in one list.** The table takes its
  columns from the first object, so the `City` of the second person is
  missing:

  ```powershell
  [pscustomobject]@{ Name = 'JDoe' }, [pscustomobject]@{ Name = 'SRossi'; City = 'Munich' }
  ```

  ```text
  Name
  ----
  JDoe
  SRossi
  ```

  Give every object the same properties, with `$null` where a value is
  missing, or name the columns with `Select-Object -Property Name, City`.

## Exercises

The exercises use the sample folder and `samples/People.csv`. If you start a
new session, create the folder again with
`$root = ./samples/New-WorkshopFolder.ps1 -Force`, from the root of this
repository.

### Exercise 1: A file report

1. Create one object per file in the sample folder with the properties
   `Name`, `Extension`, `SizeKB` rounded to two decimals, and `AgeDays`, the
   full days before 17 November 2026.
2. Show the files that are older than 60 days, the oldest first.
3. How many KB do these old files use in total?

<details>
<summary>Solution</summary>

```powershell
$today = Get-Date -Date '2026-11-17'
$files = Get-ChildItem -Path $root -Recurse -File | ForEach-Object {
    [pscustomobject]@{
        Name      = $_.Name
        Extension = $_.Extension
        SizeKB    = [math]::Round($_.Length / 1KB, 2)
        AgeDays   = ($today - $_.LastWriteTime).Days
    }
}
$old = $files | Where-Object -Property AgeDays -GT 60 | Sort-Object -Property AgeDays -Descending
$old
```

```text
Name           Extension SizeKB AgeDays
----           --------- ------ -------
LICENSE                    0.03      76
readme.txt     .txt        0.12      76
notes.TXT      .TXT        0.04      75
Get-Report.ps1 .ps1        0.10      62
Set-Config.ps1 .ps1        0.08      61
```

```powershell
($old | Measure-Object -Property SizeKB -Sum).Sum
```

```text
0.37
```

The objects carry only the four properties you defined, so the filter, the
sort, and the sum all work with names you chose. `LICENSE` has no extension,
so its `Extension` is empty.

</details>

### Exercise 2: People as objects

1. Import `samples/People.csv` with `Import-Csv -Delimiter ';'`.
2. Create one object per person with the properties `FullName` (given name
   and surname), `Department`, and `YearsOfService`, the full years from
   `HireDate` to 17 November 2026.
3. Show the five people with the longest service.

<details>
<summary>Solution</summary>

```powershell
$today = Get-Date -Date '2026-11-17'
$staff = Import-Csv -Path ./samples/People.csv -Delimiter ';' | ForEach-Object {
    $hireDate = [datetime]$_.HireDate
    $years = $today.Year - $hireDate.Year
    if ($hireDate.AddYears($years) -gt $today) { $years-- }
    [pscustomobject]@{
        FullName       = '{0} {1}' -f $_.GivenName, $_.Surname
        Department     = $_.Department
        YearsOfService = $years
    }
}
$staff | Sort-Object -Property YearsOfService -Descending | Select-Object -First 5
```

```text
FullName       Department YearsOfService
--------       ---------- --------------
Ethan Clarke   Finance                18
Daniel Okafor  IT                     17
Mia Schneider  HR                     16
Sara Lindqvist Sales                  15
Noah Kim       IT                     14
```

`Import-Csv` reads every value as a string, so `[datetime]` converts
`HireDate` first. The `if` subtracts one year when the anniversary in 2026
is still ahead: someone hired on 1 December 2015 has 10 full years, not 11.
`YearsOfService` is a number, so `Sort-Object` sorts it as a number.

</details>

## Key takeaways

- `[pscustomobject]@{}` creates an object with properties. It is the standard
  way to return structured data from your code.
- Only the cast of a hashtable literal keeps the order you typed. Use
  `[ordered]` for a hashtable that you build step by step.
- `Select-Object` with calculated properties creates new objects from
  existing ones; `[pscustomobject]` in a loop gives you full control.
- Lists of custom objects work with `Sort-Object`, `Group-Object`,
  `Measure-Object`, and member-access enumeration such as `$report.Name`.
- An assignment doesn't add a property. Use `Add-Member`, or convert the
  object to a hashtable and back.
- `-eq` on two objects checks whether they are the same object, not whether
  their values are equal.

## Learn more

- [about_PSCustomObject](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_pscustomobject)
- [Everything you wanted to know about PSCustomObject](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-pscustomobject)
- [about_Calculated_Properties](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_calculated_properties)
- [about_Member-Access_Enumeration](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_member-access_enumeration)
- [Compare-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/compare-object)
- [Sort-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/sort-object),
  [Group-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/group-object),
  and [Measure-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/measure-object)

---

[← Previous: Hashtables](04-hashtables.md)
· [Overview](../README.md) ·
[Next: CSV, JSON, and YAML →](06-csv-json-and-yaml.md)
