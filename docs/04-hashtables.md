# Hashtables

[Overview](../README.md) › Part 1: PowerShell fundamentals › Topic 4 of 17

A hashtable stores values under names, so you find any value by its name in
one step. Hashtables hold settings, serve as lookup tables, and pass
parameters to commands. This topic shows how to create, read, change, and
loop over them, and where their limits are.

In this topic, you learn to:

- create a hashtable and read, add, change, and remove its entries
- loop over the entries of a hashtable
- build a lookup table from a CSV file
- group objects into a hashtable with `Group-Object -AsHashTable`
- keep the order of the keys with `[ordered]`

## Keys and values

A hashtable stores key-value pairs, and every key is unique. You create one
with `@{ }`: inside the braces, each entry is a *key*, an equals sign, and a
*value*, separated by semicolons or line breaks. Adding a key that exists
fails:

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

## Read and check entries

You read a value with *dot notation*, as if the key were a property, or with
*index notation* in square brackets. Here are the settings from
`config/app.json` of the sample folder as a hashtable:

```powershell
$app = @{
    Port           = 8080
    Database       = 'inventory'
    TimeoutSeconds = 30
}
$app.Port
$app['Database']
$app.Count
$app.ContainsKey('Port')
$app.ContainsKey('Owner')
```

```text
8080
inventory
3
True
False
```

Index notation also takes a variable, `$app[$name]`, and keys with spaces or
special characters. Reading a key that doesn't exist, such as `$app.Owner`,
returns `$null` without an error. That's convenient, but a typo in a key name
goes unnoticed, so check with `ContainsKey()` when it matters.

`Keys` returns all keys and `Values` all values. Sort the keys when you show
them, because a hashtable has no order of its own:

```powershell
$app.Keys | Sort-Object
```

```text
Database
Port
TimeoutSeconds
```

## Keys are case-insensitive

PowerShell compares the keys of a hashtable without regard to case, just as
it compares strings. `Port`, `port`, and `PORT` are the same key:

```powershell
$app['PORT']
$app.ContainsKey('database')
$app['port'] = 9090
$app.Count
$app.Port
```

```text
8080
True
3
9090
```

The assignment to `port` changed the existing key `Port`; the hashtable still
has three entries.

## Loop over the entries

A hashtable goes down the pipeline as one object, not as a list of entries.
Its method `GetEnumerator()` returns the entries one by one:

```powershell
($app | Measure-Object).Count
($app.GetEnumerator() | Measure-Object).Count
```

```text
1
3
```

Each entry has a `Key` and a `Value` property. PowerShell adds `Name` as an
alias of `Key`, which is why the default display shows the columns `Name` and
`Value`. Sort the entries when the order matters for the output:

```powershell
$app.GetEnumerator() | Sort-Object -Property Key | ForEach-Object {
    $_.Key + ' = ' + $_.Value
}
```

```text
Database = inventory
Port = 9090
TimeoutSeconds = 30
```

A `foreach` statement over the keys works, too:
`foreach ($key in $app.Keys) { $app[$key] }`.

## Nested hashtables

A value can be another hashtable. That gives you a tree of settings, much like
a JSON file:

```powershell
$config = @{
    App = @{ Port = 8080; Database = 'inventory' }
    Web = @{ Port = 443; Certificate = 'web.example.com' }
}
$config.Web.Port
$config['App']['Database']
$config.App.Port = 9090
$config.App.Port
```

```text
443
inventory
9090
```

Since PowerShell 6, `ConvertFrom-Json -AsHashtable` turns the text of a JSON
file into such nested hashtables; see
[CSV, JSON, and YAML](06-csv-json-and-yaml.md).

## Build a lookup table

A *lookup table* answers the question "which value belongs to this key?" in
one step. Searching a list with `Where-Object` checks every item, again for
every question. With thousands of items, a lookup table is much faster.

The file `data/customers.csv` in the sample folder lists 60 customers with
their city and country. Build a table that returns the country of a city:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
$customers = Import-Csv -Path (Join-Path -Path $root -ChildPath 'data/customers.csv')
$countryOfCity = @{}
foreach ($customer in $customers) {
    $countryOfCity[$customer.City] = $customer.Country
}
$countryOfCity.Count
$countryOfCity['Vienna']
```

```text
5
Austria
```

The 60 customers live in five cities. Each assignment overwrites the entry of
its city, so every city ends up in the table once:

```powershell
$countryOfCity.GetEnumerator() | Sort-Object -Property Key
```

```text
Name                           Value
----                           -----
Berlin                         Germany
Hamburg                        Germany
Munich                         Germany
Vienna                         Austria
Zurich                         Switzerland
```

A city that isn't in the table, such as `$countryOfCity['Paris']`, returns
`$null`. Exercise 1 uses the table to add the country to every person in
`People.csv`.

## Group objects into a hashtable

With `-AsHashTable`, `Group-Object` returns one hashtable instead of
`GroupInfo` objects. The keys are the values you group by, and each value
holds the objects of its group:

```powershell
$people = Import-Csv -Path ./samples/People.csv -Delimiter ';'
$byDepartment = $people | Group-Object -Property Department -AsHashTable
$byDepartment['HR'].Count
$byDepartment.HR.Name
```

```text
5
SWang
MSchneider
EJohansson
HWeber
LNowak
```

Use it when you look up groups by name again and again. By default, the keys
keep the type of the values you group by; add `-AsString` to turn them into
strings.

## Pass parameters with splatting

*Splatting* passes the entries of a hashtable to a command as parameters: each
key is a parameter name, and each value its value. Write `@` instead of `$` in
front of the variable name, and give a switch parameter such as `-Recurse` the
value `$true`:

```powershell
$params = @{
    Path    = $root
    Filter  = '*.json'
    Recurse = $true
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

[Splatting](11-splatting.md) shows why this makes scripts easier to read and
to change.

## Hashtables as records

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

Run the demo in a few new sessions, and the keys often come back in a
different order. `[ordered]` creates an `OrderedDictionary`, which keeps the
keys in the order you add them and also lets you read a value by its
position:

```powershell
$person = [ordered]@{ GivenName = 'John'; LastName = 'Doe'; Age = 40; Department = 'IT' }
$person
$person[0]
```

```text
Name                           Value
----                           -----
GivenName                      John
LastName                       Doe
Age                            40
Department                     IT
John
```

`[ordered]` works only in front of a literal: `[ordered]$hashtable` fails with
*The ordered attribute can be specified only on a hash literal node*. For
records, PowerShell has a better tool, the custom object of the next topic,
[PSCustomObject](05-pscustomobject.md).

## Common pitfalls

- **Changing a hashtable while you loop over it.** Adding, removing, or even
  changing an entry inside `foreach ($key in $h.Keys)` stops the loop with
  *Collection was modified; enumeration operation may not execute*. Loop over
  a copy of the keys instead: `foreach ($key in @($h.Keys))`. Exercise 3
  walks you through it.

- **A key named `Count`.** Dot notation looks for a key first, so a key named
  `Count`, `Keys`, or `Values` hides the property of the same name. The
  intrinsic member `PSBase` reaches the real property:

  ```powershell
  $stock = @{ Apples = 3; Pears = 5; Count = 10 }
  $stock.Count
  $stock.PSBase.Count
  ```

  ```text
  10
  3
  ```

- **Duplicate keys in a literal.** `@{ Name = 'a'; name = 'b' }` contains the
  same key twice, because keys ignore case. PowerShell rejects the whole
  script before it runs a single line, with the message *Duplicate keys 'name'
  are not allowed in hash literals*. When you build a hashtable from data,
  assign the entries one by one, as in the lookup table above, and later
  values overwrite earlier ones.

- **Piping a hashtable.** `$app | Where-Object ...` receives one object, the
  whole hashtable, not its entries. Pipe `$app.GetEnumerator()` instead.

## Exercises

The exercises use `samples/People.csv` and the sample folder. If you start a
new session, create the folder again with
`$root = ./samples/New-WorkshopFolder.ps1 -Force`.

### Exercise 1: Countries for people

`People.csv` has a `City` column, but no country.

1. Build the city-to-country lookup table from `data/customers.csv`.
2. List the first five people with their `Name`, `City`, and country.
3. How many people live in each country?

<details>
<summary>Solution</summary>

A calculated property looks up the country of each person's city:

```powershell
$customers = Import-Csv -Path (Join-Path -Path $root -ChildPath 'data/customers.csv')
$countryOfCity = @{}
foreach ($customer in $customers) {
    $countryOfCity[$customer.City] = $customer.Country
}

$people = Import-Csv -Path ./samples/People.csv -Delimiter ';'
$withCountry = $people |
    Select-Object -Property Name, City, @{ Name = 'Country'; Expression = { $countryOfCity[$_.City] } }
$withCountry | Select-Object -First 5
```

```text
Name    City    Country
----    ----    -------
JDoe    Berlin  Germany
SRossi  Munich  Germany
LNovak  Vienna  Austria
NKim    Hamburg Germany
ZTanaka Berlin  Germany
```

```powershell
$withCountry | Group-Object -Property Country | Select-Object -Property Count, Name
```

```text
Count Name
----- ----
    5 Austria
   15 Germany
    4 Switzerland
```

Each of the 24 people costs one lookup in a table of five entries. With
`Where-Object`, each person would cost a search through all 60 customers.

</details>

### Exercise 2: People per department

1. Count the people per department with an empty hashtable and the increment
   operator `++`. Show the result, the largest department first.
2. Do the same with `Group-Object -AsHashTable`. What do the values of the two
   hashtables contain?

<details>
<summary>Solution</summary>

`$headcount[$person.Department]++` creates the key on first use, because
`$null` incremented becomes 1:

```powershell
$people = Import-Csv -Path ./samples/People.csv -Delimiter ';'
$headcount = @{}
foreach ($person in $people) {
    $headcount[$person.Department]++
}
$headcount.GetEnumerator() | Sort-Object -Property Value -Descending
```

```text
Name                           Value
----                           -----
IT                             9
Sales                          7
HR                             5
Finance                        3
```

```powershell
$byDepartment = $people | Group-Object -Property Department -AsHashTable
$byDepartment.GetEnumerator() |
    Sort-Object -Property { $_.Value.Count } -Descending |
    Select-Object -Property Key, @{ Name = 'People'; Expression = { $_.Value.Count } }
```

```text
Key     People
---     ------
IT           9
Sales        7
HR           5
Finance      3
```

The counter stores numbers. `Group-Object -AsHashTable` stores the people
themselves, so `$byDepartment.IT` gives you all nine IT people with all their
properties, and `Count` gives you the number.

</details>

### Exercise 3: Remove empty parameters

A script collects parameters for `Get-ChildItem` and wants to remove the
entries without a value before it splats them:

```powershell
$params = @{ Path = $root; Filter = '*.log'; Recurse = $true; Depth = $null; Exclude = $null }
foreach ($key in $params.Keys) {
    if ($null -eq $params[$key]) { $params.Remove($key) }
}
$params.Count
```

1. Run the code. Which error do you get, and how many entries are left?
2. Fix the loop, so that it removes both empty entries.
3. Splat the hashtable to `Get-ChildItem`, and count the log files.

<details>
<summary>Solution</summary>

The loop stops with *Collection was modified; enumeration operation may not
execute*, and `$params.Count` returns 4: the first `Remove()` worked, and the
next step of the loop failed. Loop over a copy of the keys, which `@( )`
creates:

```powershell
$params = @{ Path = $root; Filter = '*.log'; Recurse = $true; Depth = $null; Exclude = $null }
foreach ($key in @($params.Keys)) {
    if ($null -eq $params[$key]) { $params.Remove($key) }
}
$params.Count
(Get-ChildItem @params).Count
```

```text
3
6
```

The cleanup matters: splatted with `Depth = $null`, `Get-ChildItem` fails
with *Cannot bind parameter 'Depth' to the target*, because `$null` is no
valid depth.

</details>

## Key takeaways

- A hashtable maps unique keys to values. Read with `$h.Key` or `$h['Key']`;
  assign to add or change an entry.
- Keys are case-insensitive, and the order of the keys isn't defined. Use
  `[ordered]@{}` when the order matters.
- A hashtable is one object in the pipeline; `GetEnumerator()` returns its
  entries.
- Build a lookup table once and look up many times, instead of searching a
  list with `Where-Object` again and again.
- Never change a hashtable while you loop over its keys; loop over
  `@($h.Keys)`.
- For records, use `[pscustomobject]`; for parameters, use splatting.

## Learn more

- [about_Hash_Tables](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_hash_tables)
- [Everything you wanted to know about hashtables](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-hashtable)
- [Group-Object](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/group-object)
- [about_Splatting](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_splatting)
- [PowerShell scripting performance considerations: looking up entries](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations#looking-up-entries-by-property-in-large-collections)

---

[← Previous: Building a pipeline step by step](03-building-a-pipeline-step-by-step.md)
· [Overview](../README.md) ·
[Next: PSCustomObject →](05-pscustomobject.md)
