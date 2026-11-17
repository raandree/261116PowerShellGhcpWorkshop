# CSV, JSON, and YAML

[Overview](../README.md) › Part 1: PowerShell fundamentals › Topic 6 of 17

Data rarely starts in PowerShell. It arrives as a CSV export, a JSON
configuration file, or a YAML document. PowerShell turns all three formats
into objects, so everything from the previous topics applies, and it turns
objects back into text when you save them.

In this topic, you learn to:

- import CSV files and convert their columns to the right types
- export objects to CSV files for other tools
- add up amounts without rounding errors
- read, change, and write back JSON files
- read and write YAML with the `powershell-yaml` module

## Import a CSV file

`Import-Csv` turns every row of a CSV file into a `PSCustomObject`, and the
header row provides the property names. Everything you know about objects
applies. The workshop demo used a file `People.csv` with 100 records that
isn't part of these notes:

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

## Convert columns to the right type

The sample file `samples/People.csv` uses the same delimiter, and its `Name`
column holds account names, too. Who works on more than five projects?
Compared as strings, `'12' -gt '5'` is `$false`, because the character `1`
sorts before `5`. Only the values 6 to 9 pass the first filter:

```powershell
$people = Import-Csv -Path ./samples/People.csv -Delimiter ';'
($people | Where-Object { $_.Projects -gt 5 }).Count
($people | Where-Object { [int]$_.Projects -gt 5 }).Count
```

```text
8
14
```

Sorting has the same problem: as text, `9` comes before `12` in descending
order. Instead of converting in every command, convert each column once,
right after the import. Calculated properties, as shown in
[PSCustomObject](05-pscustomobject.md), replace the strings with numbers and
dates:

```powershell
$people = Import-Csv -Path ./samples/People.csv -Delimiter ';' |
    Select-Object -Property GivenName, Surname, Department, City,
        @{ Name = 'Age'; Expression = { [int]$_.Age } },
        @{ Name = 'Projects'; Expression = { [int]$_.Projects } },
        @{ Name = 'HireDate'; Expression = { [datetime]$_.HireDate } }
$people | Sort-Object -Property Projects -Descending |
    Select-Object -First 3 -Property GivenName, Projects, HireDate
```

```text
GivenName Projects HireDate
--------- -------- --------
John            12 3/1/2015 12:00:00 AM
Chloe           12 1/4/2016 12:00:00 AM
Ethan           11 3/3/2008 12:00:00 AM
```

From now on, `Projects` sorts as a number and `HireDate` is a `DateTime`
that you can calculate with. `[datetime]` understands the ISO format
`yyyy-MM-dd` of the sample file.

## Inline data and custom headers

`ConvertFrom-Csv` reads CSV text instead of a file, for example from a
*here-string*, a multi-line string between `@'` and `'@`. It suits small
lookup tables and test data inside a script:

```powershell
$servers = @'
Name,Role,Cores
srv01,Web,4
srv02,Database,16
'@ | ConvertFrom-Csv
$servers | Where-Object { [int]$_.Cores -gt 8 }
```

```text
Name  Role     Cores
----  ----     -----
srv02 Database 16
```

`-Header` sets your own property names. It reads files without a header
line, and it renames the columns of files with one. In that case, the
original header line comes back as the first object, as `data/customers.csv`
from the sample folder shows:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
$customersPath = Join-Path -Path $root -ChildPath 'data/customers.csv'
Import-Csv -Path $customersPath -Header Id, Customer, Town, Land | Select-Object -First 3
```

```text
Id         Customer     Town    Land
--         --------     ----    ----
CustomerId Name         City    Country
1          Customer 001 Munich  Germany
2          Customer 002 Hamburg Germany
```

Skip that first object with `Select-Object -Skip 1`, or remove the header
line from the file.

## Export objects to CSV

`Export-Csv` writes one line per object and one column per property. Select
the properties first, and choose the delimiter that the program reading the
file expects, such as the semicolon of `samples/People.csv`:

```powershell
$itPath = Join-Path -Path $root -ChildPath 'it-people.csv'
$people | Where-Object -Property Department -EQ 'IT' |
    Select-Object -Property GivenName, Surname, City, Projects |
    Export-Csv -Path $itPath -Delimiter ';'
Get-Content -Path $itPath -TotalCount 3
```

```text
"GivenName";"Surname";"City";"Projects"
"John";"Doe";"Berlin";"12"
"Sofia";"Rossi";"Munich";"7"
```

A few parameters are worth knowing:

- `-UseCulture` takes the list separator of the current culture instead of
  a fixed delimiter: a comma for `en-US`, a semicolon for `de-DE`.
- `-UseQuotes AsNeeded`, new in PowerShell 7, quotes only the values that
  contain the delimiter, a double quote, or a line break.
- `-Append` adds the objects to the end of an existing file. Without it,
  `Export-Csv` replaces the file without warning.

> [!IMPORTANT]
> In Windows PowerShell 5.1, add `-NoTypeInformation`. Without it, the first
> line of the file is `#TYPE` followed by the type name of the objects.
> PowerShell 6 and later leave this line out by default.

The export turns every value into text. When you import the file again, the
numbers are strings once more, so convert them again.

## Add up amounts exactly

The file `data/orders.csv` in the sample folder holds 800 orders, each with
an amount with two decimals. Add them up:

```powershell
$orders = Import-Csv -Path (Join-Path -Path $root -ChildPath 'data/orders.csv')
($orders | Measure-Object -Property Amount -Sum).Sum
```

```text
208191.999999998
```

The exact total is 208,192.00. `Measure-Object` calculates with the type
`[double]`, a binary floating-point number. A `[double]` can't store most
decimal fractions, such as 0.1, exactly, and 800 tiny errors add up. The
type `[decimal]` stores decimal digits exactly and is the right type for
money:

```powershell
$total = [decimal]0
foreach ($order in $orders) {
    $total += [decimal]$order.Amount
}
$total
```

```text
208192.00
```

Converting the amounts to `[decimal]` before `Measure-Object` doesn't help:
it returns its sum as a `[double]`, even for `[decimal]` input. Add the
amounts yourself, as above.

## Read and change JSON files

JSON works the same way, and `ConvertFrom-Json` returns custom objects:

```powershell
$p | ConvertTo-Json | Set-Content -Path .\People.json
$people = Get-Content -Path .\People.json -Raw | ConvertFrom-Json
$people | Where-Object { $_.Department -eq 'D' }
```

`ConvertTo-Json` serializes two levels deep by default and warns when it cuts
off deeper data. Add `-Depth` for nested objects.

`-Raw` reads the whole file as one string, the complete JSON document. Nested
JSON objects become nested custom objects, and dot notation reaches into
them. To change a setting in `data/settings.json`, read the file, assign the
new values, and write the whole object back:

```powershell
$settingsPath = Join-Path -Path $root -ChildPath 'data/settings.json'
$settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
$settings.logLevel = 'Warning'
$settings.features.notifications = $true
$settings | ConvertTo-Json | Set-Content -Path $settingsPath
Get-Content -Path $settingsPath
```

```text
{
  "applicationName": "Inventory",
  "version": "1.4.2",
  "logLevel": "Warning",
  "retentionDays": 30,
  "features": {
    "export": true,
    "notifications": true
  }
}
```

`ConvertTo-Json` writes its own layout: two spaces of indentation instead of
the four of the original file. The data is the same, but a comparison with
the original shows every indented line as changed.

A custom object from JSON is no different from other custom objects: you
can't add a property by assignment. With `-AsHashtable`, available since
PowerShell 6, `ConvertFrom-Json` returns a hashtable instead, and since
PowerShell 7.3, an ordered one:

```powershell
$config = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json -AsHashtable
$config.owner = 'Operations'
$config.Keys -join ', '
```

```text
applicationName, version, logLevel, retentionDays, features, owner
```

A hashtable also copes with JSON that a custom object can't hold: keys that
differ only in case, and empty keys.

## Read and write YAML

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

With the sample data, the round trip looks like this. `ConvertTo-Yaml`
writes the objects you pipe to it as a YAML list:

```powershell
Import-Module -Name powershell-yaml
$yamlPath = Join-Path -Path $root -ChildPath 'people.yml'
Import-Csv -Path ./samples/People.csv -Delimiter ';' |
    Select-Object -First 2 -Property GivenName, Surname, Department |
    ConvertTo-Yaml | Set-Content -Path $yamlPath
Get-Content -Path $yamlPath
```

```text
- GivenName: John
  Surname: Doe
  Department: IT
- GivenName: Sofia
  Surname: Rossi
  Department: IT
```

Read the file back. Piped directly, the list arrives as one object; from the
variable, the entries arrive one by one and become objects again:

```powershell
$list = ConvertFrom-Yaml -Yaml (Get-Content -Path $yamlPath -Raw) -Ordered
(ConvertFrom-Yaml -Yaml (Get-Content -Path $yamlPath -Raw) -Ordered | Measure-Object).Count
($list | Measure-Object).Count
$list | ForEach-Object { [pscustomobject]$_ }
```

```text
1
2

GivenName Surname Department
--------- ------- ----------
John      Doe     IT
Sofia     Rossi   IT
```

## Common pitfalls

- **The wrong delimiter.** Without `-Delimiter ';'`, `Import-Csv` looks for
  commas, finds none, and returns one big column:

  ```powershell
  Import-Csv -Path ./samples/People.csv | Select-Object -First 1
  ```

  ```text
  Surname;GivenName;Department;City;Age;Projects;HireDate;Name;EmailAddress
  -------------------------------------------------------------------------
  Doe;John;IT;Berlin;40;12;2015-03-01;JDoe;john.doe@example.com
  ```

- **Nested data in a CSV file.** A CSV cell holds one value. An array ends
  up as the text `System.Object[]`:

  ```powershell
  [pscustomobject]@{ Name = 'JDoe'; Groups = 'IT', 'Admins' } | ConvertTo-Csv
  ```

  ```text
  "Name","Groups"
  "JDoe","System.Object[]"
  ```

  Join arrays into one string with a calculated property, for example
  `@{ Name = 'Groups'; Expression = { $_.Groups -join ',' } }`, or use JSON,
  which keeps the structure.

- **Dates in a CSV file.** `Export-Csv` writes a `DateTime` in the format of
  the current culture: `3/1/2015 12:00:00 AM` with `en-US`, but
  `01.03.2015 00:00:00` with `de-DE`. Another system may read it wrong, or not
  at all. Write dates as text in a fixed format, such as
  `$_.HireDate.ToString('yyyy-MM-dd')`.

- **The depth of `ConvertTo-Json`.** Beyond the default depth of 2,
  PowerShell replaces the deeper data with text, here a type name, and warns
  you:

  ```powershell
  @{ App = @{ Logging = @{ File = @{ Path = 'app.log' } } } } | ConvertTo-Json
  ```

  ```text
  WARNING: Resulting JSON is truncated as serialization has exceeded the set depth of 2.
  {
    "App": {
      "Logging": {
        "File": "System.Collections.Hashtable"
      }
    }
  }
  ```

  Add `-Depth` with a value that covers your data, for example `-Depth 10`.

## Exercises

The exercises use `samples/People.csv` and the sample folder. If you start a
new session, create the folder again with
`$root = ./samples/New-WorkshopFolder.ps1 -Force`, from the root of this
repository.

### Exercise 1: People per city

1. Count the people per city in `samples/People.csv`, the largest city first.
2. Export the result with the columns `City` and `People` to the file
   `people-per-city.csv` in the sample folder, with a semicolon as the
   delimiter, and show the file.

<details>
<summary>Solution</summary>

```powershell
$cityPath = Join-Path -Path $root -ChildPath 'people-per-city.csv'
Import-Csv -Path ./samples/People.csv -Delimiter ';' |
    Group-Object -Property City -NoElement |
    Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, Name |
    Select-Object -Property @{ Name = 'City'; Expression = { $_.Name } },
        @{ Name = 'People'; Expression = { $_.Count } } |
    Export-Csv -Path $cityPath -Delimiter ';' -UseQuotes AsNeeded
Get-Content -Path $cityPath
```

```text
City;People
Berlin;6
Munich;5
Vienna;5
Hamburg;4
Zurich;4
```

`-NoElement` leaves out the `Group` property, because only the counts
matter. The hashtable in `Sort-Object` sorts by `Count` in descending order,
and `Name` sorts cities with the same count alphabetically.

</details>

### Exercise 2: The exact order total per month

1. Import `data/orders.csv` from the sample folder.
2. Calculate the exact total of the orders per month with `[decimal]`.
   `OrderDate` has the format `yyyy-MM-dd`, so its first seven characters
   are the month.

<details>
<summary>Solution</summary>

```powershell
$orders = Import-Csv -Path (Join-Path -Path $root -ChildPath 'data/orders.csv')
$orders | Group-Object -Property { $_.OrderDate.Substring(0, 7) } | ForEach-Object {
    $sum = [decimal]0
    foreach ($order in $_.Group) {
        $sum += [decimal]$order.Amount
    }
    [pscustomobject]@{ Month = $_.Name; Orders = $_.Count; Total = $sum }
}
```

```text
Month   Orders    Total
-----   ------    -----
2026-01     93 23344.07
2026-02     84 22045.16
2026-03     93 25363.07
2026-04     90 23384.10
2026-05     93 23264.07
2026-06     90 23014.10
2026-07     81 21403.19
2026-08     62 16957.38
2026-09     60 15249.40
2026-10     54 14167.46
```

`Group-Object` accepts a script block instead of a property name and groups
by its result, here the month. The monthly totals add up to the exact total
of 208,192.00.

</details>

### Exercise 3: Change the retention

1. Read `data/settings.json` from the sample folder.
2. Set `retentionDays` to 90 and write the file back.
3. Read the file again and check the new value.

<details>
<summary>Solution</summary>

```powershell
$settingsPath = Join-Path -Path $root -ChildPath 'data/settings.json'
$settings = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
$settings.retentionDays = 90
$settings | ConvertTo-Json | Set-Content -Path $settingsPath
(Get-Content -Path $settingsPath -Raw | ConvertFrom-Json).retentionDays
```

```text
90
```

The file has two levels, the settings and `features`, so the default depth
of `ConvertTo-Json` is enough. For deeper files, add `-Depth`.

</details>

## Key takeaways

- `Import-Csv` and `ConvertFrom-Json` return custom objects, so filtering,
  sorting, and grouping work as with any other object.
- Every value from a CSV file is a string. Convert the columns once, with
  calculated properties, before you compare, sort, or calculate.
- Name the delimiter that a file uses, such as `-Delimiter ';'`, and add
  `-NoTypeInformation` in Windows PowerShell 5.1.
- Add up money as `[decimal]`; `[double]` and `Measure-Object` produce
  rounding errors.
- Read JSON with `Get-Content -Raw`, and write nested data with `-Depth`.
  `-AsHashtable` returns a hashtable instead of a custom object.
- YAML needs the `powershell-yaml` module; convert its hashtables into
  objects with `[pscustomobject]`.

## Learn more

- [Import-Csv](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/import-csv)
  and [Export-Csv](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/export-csv)
- [ConvertFrom-Csv](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/convertfrom-csv)
- [ConvertFrom-Json](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/convertfrom-json)
  and [ConvertTo-Json](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/convertto-json)
- [powershell-yaml in the PowerShell Gallery](https://www.powershellgallery.com/packages/powershell-yaml)
- [about_Comparison_Operators](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_comparison_operators)
- [Floating-point numeric types in .NET](https://learn.microsoft.com/dotnet/csharp/language-reference/builtin-types/floating-point-numeric-types)

---

[← Previous: PSCustomObject](05-pscustomobject.md)
· [Overview](../README.md) ·
[Next: Inspecting and extending objects →](07-inspecting-and-extending-objects.md)
