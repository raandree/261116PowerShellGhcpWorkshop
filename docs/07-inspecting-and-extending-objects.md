# Inspecting and extending objects

[Overview](../README.md) › Part 1: PowerShell fundamentals › Topic 7 of 17

Every object can tell you what it is made of, and you can add to it. This
topic looks inside objects with `Get-Member`, `Format-List`, and the hidden
`PSObject` property. It then extends single objects with `Add-Member`, and
every object of a type with `Update-TypeData`.

In this topic, you learn to:

- list the members of an object and tell the member types apart
- show every property of an object with its value
- add properties and methods to an object with `Add-Member`
- extend every object of a type with `Update-TypeData`
- find the static members of a type

## What an object is made of

`Get-Member` shows what an object is made of. The properties of a
`PSCustomObject` are *NoteProperties*: static values attached to the object.

```powershell
$p = [pscustomobject]@{ GivenName = 'John'; LastName = 'Doe'; Age = 40; Department = 'IT' }
$p | Get-Member
```

<details>
<summary>Output</summary>

```text
   TypeName: System.Management.Automation.PSCustomObject

Name        MemberType   Definition
----        ----------   ----------
Equals      Method       bool Equals(System.Object obj)
GetHashCode Method       int GetHashCode()
GetType     Method       type GetType()
ToString    Method       string ToString()
Age         NoteProperty int Age=40
Department  NoteProperty string Department=IT
GivenName   NoteProperty string GivenName=John
LastName    NoteProperty string LastName=Doe
```

</details>

The column `MemberType` tells you where a member comes from. These are the
member types you meet most often:

| Member type      | What it is                           | Comes from                                        |
|------------------|--------------------------------------|---------------------------------------------------|
| `Property`       | A property of the .NET type          | The type itself                                   |
| `Method`         | A method of the .NET type            | The type itself                                   |
| `NoteProperty`   | A stored value                       | `[pscustomobject]`, `Select-Object`, `Add-Member` |
| `ScriptProperty` | A value that a script block computes | `Add-Member`, `Update-TypeData`                   |
| `AliasProperty`  | A second name for another property   | `Add-Member`, `Update-TypeData`                   |
| `ScriptMethod`   | A method written as a script block   | `Add-Member`, `Update-TypeData`                   |

## Show every property and its value

The console shows a selection of the properties, and for some types only one
line of text. `Format-List -Property *` shows every property with its value:

```powershell
$christmas = Get-Date -Date '2026-12-24'
$christmas
$christmas | Format-List -Property *
```

```text
Thursday, December 24, 2026 12:00:00 AM


DisplayHint : DateTime
DateTime    : Thursday, December 24, 2026 12:00:00 AM
Date        : 12/24/2026 12:00:00 AM
Day         : 24
DayOfWeek   : Thursday
DayOfYear   : 358
Hour        : 0
Kind        : Unspecified
Millisecond : 0
Microsecond : 0
Nanosecond  : 0
Minute      : 0
Month       : 12
Second      : 0
Ticks       : 639336672000000000
TimeOfDay   : 00:00:00
Year        : 2026
```

Two of these properties don't come from .NET. `DateTime` is a
ScriptProperty that PowerShell adds to every `DateTime` object, and
`DisplayHint` is a NoteProperty that `Get-Date` attaches to the dates it
returns.

`Select-Object -Property *` shows the same values. It returns new objects
instead of formatting instructions, though, so you can still sort, filter,
or export the result. Use `Format-List -Property *` to look, and
`Select-Object -Property *` to continue working.

## Walk through the properties

Every object has the hidden property `PSObject`, one of PowerShell's
*intrinsic members*. `PSObject.Properties` lists the properties with their
names, values, and types. With it, your code can handle objects whose
properties it doesn't know in advance. Try it with the settings file of the
sample folder:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
$settings = Get-Content -Path (Join-Path -Path $root -ChildPath 'data/settings.json') -Raw |
    ConvertFrom-Json
$settings.PSObject.Properties | Select-Object -Property Name, Value, TypeNameOfValue
```

```text
Name            Value                               TypeNameOfValue
----            -----                               ---------------
applicationName Inventory                           System.String
version         1.4.2                               System.String
logLevel        Information                         System.String
retentionDays   30                                  System.Int64
features        @{export=True; notifications=False} System.Management.Automation.PSCustomObject
```

Whole numbers from JSON become `Int64`, and the nested `features` object is
a custom object of its own. When the name of a property is in a variable, index
`Properties` with it: `$settings.PSObject.Properties['retentionDays'].Value`
returns `30`.

## Extend an object with Add-Member

`Add-Member` extends an object. A *NoteProperty* adds a value; a
*ScriptProperty* adds a computed value, evaluated every time you read it.
Inside its script block, `$this` is the object itself.

```powershell
$p | Add-Member -Name Gender -MemberType NoteProperty -Value M
$p | Add-Member -Name FullName -MemberType ScriptProperty -Value {
    "$($this.GivenName) $($this.LastName)"
}
$p
```

```text
GivenName  : John
LastName   : Doe
Age        : 40
Department : IT
Gender     : M
FullName   : John Doe
```

Three details worth knowing:

- **Table or list?** For objects without a predefined view, PowerShell shows a
  table for up to four properties and a list for five or more. That is why
  the output switched to a list after adding `Gender`.
- **Always current.** A ScriptProperty is computed on every access. After
  `$p.GivenName = 'Jane'`, `$p.FullName` returns `Jane Doe`.
- **Subexpressions in strings.** Inside double quotes, `$($this.GivenName)`
  needs the subexpression `$()`. Without it, PowerShell expands only `$this`
  and appends `.GivenName` as plain text.

## Extend objects in a pipeline

By default, `Add-Member` changes the object and returns nothing. With
`-PassThru`, it returns the extended object, so it fits into a pipeline. The
next example also adds an *AliasProperty*, a second name for an existing
property. With it, code written for `LastName`, like the examples above,
works with the `Surname` of the sample file, too:

```powershell
$people = Import-Csv -Path ./samples/People.csv -Delimiter ';' |
    Add-Member -MemberType AliasProperty -Name LastName -Value Surname -PassThru
$people | Select-Object -First 3 -Property GivenName, LastName, Department
```

```text
GivenName LastName Department
--------- -------- ----------
John      Doe      IT
Sofia     Rossi    IT
Liam      Novak    IT
```

Without `-PassThru`, the pipeline would return nothing, and `$people` would
be empty.

## Add a method with ScriptMethod

A *ScriptMethod* is a method written as a script block. Unlike a
ScriptProperty, it takes arguments, which you declare with `param`.
`Add-Member` extends .NET objects, too, such as this `FileInfo` object of a
log file. The new method counts the lines with a given level:

```powershell
$log = Get-Item -Path (Join-Path -Path $root -ChildPath 'logs/app-2026-11-03.log')
$log | Add-Member -MemberType ScriptMethod -Name CountLevel -Value {
    param ($Level)
    @(Select-String -Path $this.FullName -Pattern " $Level ").Count
}
$log.CountLevel('ERROR')
$log.CountLevel('WARN')
```

```text
40
80
```

The workshop function in [Your first function](09-your-first-function.md)
uses `Add-Member` the same way, to attach the total size to each group that
`Group-Object` returns.

## Extend every object of a type

`Add-Member` extends one object. To extend every object of a type, now and
for the rest of the session, use `Update-TypeData`. This command gives every
folder a `FileCount` property:

```powershell
Update-TypeData -TypeName System.IO.DirectoryInfo -MemberType ScriptProperty -MemberName FileCount -Value {
    @(Get-ChildItem -LiteralPath $this.FullName -File).Count
}
Get-ChildItem -Path $root -Directory | Select-Object -Property Name, FileCount
```

```text
Name    FileCount
----    ---------
backup          2
config          3
data            4
logs            4
scripts         4
```

PowerShell extends its own types the same way; the `DateTime` property of a
date above is one example. Type data that you add with `Update-TypeData`
lasts until the session ends. To have it in every session, add the command
to your PowerShell profile.

## Find static members

Static members belong to the type, not to an object, as
[Everything is an object](01-everything-is-an-object.md) showed with
`[datetime]::IsLeapYear()`. `Get-Member` lists them only when you add
`-Static`. Pipe the type itself, in square brackets, to `Get-Member`:

```powershell
[string] | Get-Member -Static -Name IsNullOr*
```

```text
   TypeName: System.String

Name               MemberType Definition
----               ---------- ----------
IsNullOrEmpty      Method     static bool IsNullOrEmpty(string value)
IsNullOrWhiteSpace Method     static bool IsNullOrWhiteSpace(string value)
```

```powershell
[string]::IsNullOrWhiteSpace('   ')
```

```text
True
```

`[string]::IsNullOrWhiteSpace()` is a reliable test for missing input: it
returns `$true` for `$null`, an empty string, and a string of spaces.

## Common pitfalls

- **Adding a member that exists.** `Add-Member` refuses to replace a member:

  ```powershell
  $p | Add-Member -Name Gender -MemberType NoteProperty -Value F
  ```

  ```text
  Add-Member: Cannot add a member with the name "Gender" because a member with that name already exists. To overwrite the member anyway, add the Force parameter to your command.
  ```

  Add `-Force` to replace the existing member.

- **A NoteProperty is a copy, not a live value.** A NoteProperty stores the
  value at the moment you add it. Only a ScriptProperty follows changes:

  ```powershell
  $p | Add-Member -Name FullNameCopy -MemberType NoteProperty -Value "$($p.GivenName) $($p.LastName)"
  $p.GivenName = 'Jane'
  $p.FullNameCopy
  $p.FullName
  ```

  ```text
  John Doe
  Jane Doe
  ```

- **`Update-TypeData` twice in one session.** Running the same command again,
  for example after you changed the script block, fails:

  ```powershell
  Update-TypeData -TypeName System.IO.DirectoryInfo -MemberType ScriptProperty -MemberName FileCount -Value { @(Get-ChildItem -LiteralPath $this.FullName -File).Count }
  ```

  ```text
  Update-TypeData: Error in TypeData "System.IO.DirectoryInfo": The member FileCount is already present.
  ```

  Add `-Force` to replace the existing definition.

## Exercises

The exercises use the sample folder and `samples/People.csv`. If you start a
new session, create the folder again with
`$root = ./samples/New-WorkshopFolder.ps1 -Force`, from the root of this
repository.

### Exercise 1: SizeKB on every file

1. Give every file a `SizeKB` property, the size in KB rounded to one
   decimal, with `Update-TypeData`.
2. Show the name and `SizeKB` of the five largest files in the sample
   folder.

<details>
<summary>Solution</summary>

```powershell
Update-TypeData -TypeName System.IO.FileInfo -MemberType ScriptProperty -MemberName SizeKB -Value {
    [math]::Round($this.Length / 1KB, 1)
} -Force
Get-ChildItem -Path $root -Recurse -File |
    Sort-Object -Property SizeKB -Descending |
    Select-Object -First 5 -Property Name, SizeKB
```

```text
Name                SizeKB
----                ------
database.bak       2048.00
app-2026-11-03.log   49.20
app-2026-11-02.log   39.30
app-2026-11-01.log   29.50
app-2026-10-31.log   24.60
```

`-Force` lets you run the solution again without an error. `Sort-Object`
and `Select-Object` use `SizeKB` like any other property, because every
`FileInfo` object in the session has it now.

</details>

### Exercise 2: Every property of a person

1. Show the name and the value of every property of the first person in
   `samples/People.csv`.
2. Which properties of this person contain the text `doe`, in any case?

<details>
<summary>Solution</summary>

```powershell
$first = Import-Csv -Path ./samples/People.csv -Delimiter ';' | Select-Object -First 1
$first.PSObject.Properties | Select-Object -Property Name, Value
```

```text
Name         Value
----         -----
Surname      Doe
GivenName    John
Department   IT
City         Berlin
Age          40
Projects     12
HireDate     2015-03-01
Name         JDoe
EmailAddress john.doe@example.com
```

```powershell
$first.PSObject.Properties | Where-Object -Property Value -Like '*doe*' |
    Select-Object -ExpandProperty Name
```

```text
Surname
Name
EmailAddress
```

`-Like` ignores case, so `*doe*` finds the surname `Doe`, the account name
`JDoe`, and the email address.

</details>

### Exercise 3: A method for a short name

1. Import `samples/People.csv`, and give every person a ScriptMethod
   `GetShortName()` that returns the initial of the given name and the
   surname, such as `J. Doe`.
2. Call the method for the first three people.

<details>
<summary>Solution</summary>

```powershell
$people = Import-Csv -Path ./samples/People.csv -Delimiter ';' |
    Add-Member -MemberType ScriptMethod -Name GetShortName -Value {
        '{0}. {1}' -f $this.GivenName.Substring(0, 1), $this.Surname
    } -PassThru
$people | Select-Object -First 3 | ForEach-Object { $_.GetShortName() }
```

```text
J. Doe
S. Rossi
L. Novak
```

`-PassThru` passes every extended person on, so `$people` holds all 24
people with the new method. `Substring(0, 1)` returns the first character of
the given name.

</details>

## Key takeaways

- `Get-Member` lists the members of an object; the `MemberType` shows
  whether a member comes from .NET or from PowerShell.
- `Format-List -Property *` shows every property with its value;
  `Select-Object -Property *` does the same and keeps the objects.
- `PSObject.Properties` lets your code read names and values of any object.
- `Add-Member` extends one object: `NoteProperty` for a stored value,
  `ScriptProperty` for a computed value, `AliasProperty` for a second name,
  and `ScriptMethod` for a method. Use `-PassThru` in pipelines.
- `Update-TypeData` extends every object of a type for the rest of the
  session; add `-Force` to redefine a member.
- `Get-Member -Static` reveals the static members of a type.

## Learn more

- [Get-Member](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/get-member)
- [Add-Member](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/add-member)
- [Update-TypeData](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/update-typedata)
- [about_Intrinsic_Members](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_intrinsic_members)
- [about_Automatic_Variables: $this](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_automatic_variables#this)
- [PowerShell 101: Discovering objects](https://learn.microsoft.com/powershell/scripting/learn/ps101/03-discovering-objects#properties)

---

[← Previous: CSV, JSON, and YAML](06-csv-json-and-yaml.md)
· [Overview](../README.md) ·
[Next: Strings and the format operator →](08-strings-and-the-format-operator.md)
