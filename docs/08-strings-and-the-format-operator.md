# Strings and the format operator

[Overview](../README.md) › Part 1: PowerShell fundamentals › Topic 8 of 17

Reports, log messages, and file names are strings. PowerShell offers two
kinds of quotes, an escape character, and the format operator `-f` to build
them. This topic shows when to use which, how to take text apart and put it
together, and how to format numbers and dates the same way on every system.

In this topic, you learn to:

- choose between single and double quotes, and escape special characters
- build multi-line text with here-strings
- split, replace, and join text with methods and operators
- format and align numbers and dates with `-f`
- turn the lines of a log file into objects

## Verbatim and expandable strings

Single-quoted strings are *verbatim*: PowerShell prints them exactly as typed.
Double-quoted strings are *expandable*: PowerShell replaces variables with
their values. The backtick `` ` `` is the escape character.

```text
PS> $a = 5
PS> '$a is $a'
$a is $a
PS> "$a is $a"
5 is 5
PS> '$a is' + "$a"
$a is5
PS> '$a is ' + "$a"
$a is 5
PS> "`$a is $a"
$a is 5
PS> "`$a is `n $a"
$a is
 5
PS> "`$a is `n `x $a"
$a is
 x 5
PS> "`$a is `n `t $a"
$a is
         5
```

| Escape sequence | Result                                      |
|-----------------|---------------------------------------------|
| `` `n ``        | New line                                    |
| `` `t ``        | Horizontal tab                              |
| `` `$ ``        | A literal `$`, no variable expansion        |
| `` `" ``        | A literal double quote inside double quotes |
| `` `x ``        | No escape sequence: the backtick is dropped |

> [!TIP]
> Use single quotes unless you need expansion or escape sequences. It makes
> the intent clear. PSScriptAnalyzer can check it with the optional rule
> *AvoidUsingDoubleQuotesForConstantString*, which is off by default.

## Subexpressions

A double-quoted string expands variables, but not expressions. To insert a
property, a method call, or a calculation, wrap it in the *subexpression*
`$()`. Without it, PowerShell expands only the variable, here the whole
person, and appends `.GivenName` as plain text:

```powershell
$person = Import-Csv -Path ./samples/People.csv -Delimiter ';' | Select-Object -First 1
"Name: $person.GivenName"
"Name: $($person.GivenName) $($person.Surname)"
"Projects next year: $([int]$person.Projects + 2)"
```

```text
Name: @{Surname=Doe; GivenName=John; Department=IT; City=Berlin; Age=40; Projects=12; HireDate=2015-03-01; Name=JDoe; EmailAddress=john.doe@example.com}.GivenName
Name: John Doe
Projects next year: 14
```

## Here-strings

A *here-string* spans several lines. It starts with `@'` or `@"` at the end
of a line and ends with `'@` or `"@` at the start of a line. Quotation marks
inside are plain text. Like other strings, `@' '@` is verbatim and `@" "@`
is expandable, which makes it a template for messages and reports:

```powershell
$errors = 3
$message = @"
Nightly check of $($person.City):
- errors found: $errors
- next step: "review the log"
"@
$message
```

```text
Nightly check of Berlin:
- errors found: 3
- next step: "review the log"
```

[CSV, JSON, and YAML](06-csv-json-and-yaml.md) uses a verbatim here-string
for inline CSV data.

## The format operator

The workshop continued the first transcript, so `$a` is still 5. The format
operator `-f` fills numbered placeholders with the values on its
right side: `{0}` is the first value, `{1}` the second. After a colon, a
format string controls how the value is shown. The template below is in
single quotes, so `$a` stays literal text while the placeholders are filled.

```text
PS> '$a is {0}' -f $a
$a is 5
PS> '$a is {0} x {1}' -f $a, 'Test'
$a is 5 x Test
PS> '$a is {0} at {1}' -f $a, (Get-Date)
$a is 5 at 11/17/2026 9:27:29 AM
PS> '$a is {0} at {1:yyMMdd}' -f $a, (Get-Date)
$a is 5 at 261117
PS> '$a is {0:D2} at {1:yyMMdd}' -f $a, (Get-Date)
$a is 05 at 261117
PS> '$a is {0:D4} at {1:yyMMdd}' -f $a, (Get-Date)
$a is 0005 at 261117
PS> $a = 678
PS> '$a is {0:D4} at {1:yyMMdd}' -f $a, (Get-Date)
$a is 0678 at 261117
```

| Format       | Example                                          | Result                       |
|--------------|--------------------------------------------------|------------------------------|
| `D3`         | `'Server{0:D3}' -f 7`                            | `Server007`                  |
| `N2`         | `'{0:N2}' -f 1234.5678`                          | `1,234.57` with en-US        |
| `yyyy-MM-dd` | `'{0:yyyy-MM-dd HH:mm}' -f (Get-Date)`           | `2026-11-17 09:27`           |
| Timestamp    | `'Report_{0:yyyyMMdd_HHmmss}.csv' -f (Get-Date)` | `Report_20261117_092729.csv` |

> [!WARNING]
> In date formats, `MM` is the month and `mm` the minute. Also, `-f` uses .NET
> composite formatting, which formats with the current culture: on a German
> system, `'{0}' -f (Get-Date)` returns `17.11.2026 09:27:29`. Expandable
> strings use the invariant culture, so `"$(Get-Date)"` always returns
> `11/17/2026 09:27:29`.

## Align columns

A placeholder can also set a width: `{0,12}` right-aligns the value in 12
characters, and `{0,-12}` left-aligns it. The width comes before the colon,
so `{2,8:N0}` right-aligns a number with thousands separators in 8
characters. Here are the days of service of the first four people:

```powershell
$people = Import-Csv -Path ./samples/People.csv -Delimiter ';'
$today = Get-Date -Date '2026-11-17'
$people | Select-Object -First 4 | ForEach-Object {
    $days = ($today - [datetime]$_.HireDate).Days
    '{0,-14}{1,-6}{2,8:N0} days' -f "$($_.GivenName) $($_.Surname)", $_.Department, $days
}
```

```text
John Doe      IT       4,279 days
Sofia Rossi   IT       2,712 days
Liam Novak    IT       1,772 days
Noah Kim      IT       5,190 days
```

A value longer than its width isn't cut off; it pushes the rest of the line
to the right. Choose widths that fit your longest value.

## Format for other programs

Text that other programs read, such as CSV files, logs, or file names, must
look the same on every computer. `-f` formats with the current culture, but
the method `ToString()` and `[string]::Format()` accept a culture.
`[cultureinfo]::InvariantCulture` is the culture that never changes:

```powershell
$amount = 1234.5678
$amount.ToString('N2', [cultureinfo]'de-DE')
$amount.ToString('N2', [cultureinfo]::InvariantCulture)
[string]::Format([cultureinfo]::InvariantCulture, '{0:N2} on {1:d}', $amount, $today)
```

```text
1.234,57
1,234.57
1,234.57 on 11/17/2026
```

For dates, `Get-Date -Format` takes the same format strings. The format `o`
writes the ISO 8601 round-trip format, which other programs can read back
exactly:

```powershell
$stamp = Get-Date -Date '2026-11-17 09:27:29'
Get-Date -Date $stamp -Format 'yyyy-MM-dd HH:mm'
Get-Date -Date $stamp -Format o
(Get-Date -Date $stamp -Format 'yyyy-MM-dd').GetType().Name
```

```text
2026-11-17 09:27
2026-11-17T09:27:29.0000000
String
```

`-Format` returns a string, not a `DateTime`, so you can no longer calculate
with the result. Like `Format-Table`, it belongs at the end.

## String methods and operators

Strings have .NET methods, and PowerShell adds operators for the same tasks.
They differ in one important way: the operators `-replace` and `-split` work
with *regular expressions*, patterns such as `\d` for a digit or `\s+` for
one or more spaces.

| Task          | Method                                         | Operator                                    |
|---------------|------------------------------------------------|---------------------------------------------|
| Replace       | `.Replace('a', 'b')`: text, case-sensitive     | `-replace 'a', 'b'`: pattern, ignores case  |
| Split         | `.Split(' ')`: at every occurrence of the text | `-split '\s+'`: at every match of a pattern |
| Join          | `[string]::Join(',', $items)`                  | `$items -join ','`                          |
| Change case   | `.ToUpper()`, `.ToLower()`                     | None                                        |
| Remove spaces | `.Trim()`, `.TrimStart()`, `.TrimEnd()`        | None                                        |

A line of a log file from the sample folder shows the difference. Its level
is padded to five characters, so `INFO` is followed by two spaces:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
$logPath = Join-Path -Path $root -ChildPath 'logs/app-2026-11-03.log'
$line = Get-Content -Path $logPath -TotalCount 1
$line
$line.Split(' ') -join '|'
($line -split '\s+', 4) -join '|'
$line -replace '\d{2}:\d{2}:\d{2}', 'hh:mm:ss'
$line.Substring(20, 5).Trim().ToLower()
```

```text
2026-11-03 08:00:00 INFO  Service started
2026-11-03|08:00:00|INFO||Service|started
2026-11-03|08:00:00|INFO|Service started
2026-11-03 hh:mm:ss INFO  Service started
info
```

`.Split(' ')` returns an empty string between the two spaces. `-split '\s+'`
treats any number of spaces as one separator, and the `4` stops after four
parts, so the message keeps its spaces. `-replace` found the time by its
pattern, two digits, a colon, and so on. Methods can be chained: the last
line cuts the padded level out of the line, removes the space, and changes
the case.

## Turn log lines into objects

With `-split`, every line becomes an object, and the rest is the pipeline
you already know. The multiple assignment `$date, $time, $level, $message =`
puts the four parts into four variables:

```powershell
$entries = Get-Content -Path $logPath | ForEach-Object {
    $date, $time, $level, $message = $_ -split '\s+', 4
    [pscustomobject]@{
        Time    = [datetime]"$date $time"
        Level   = $level
        Message = $message
    }
}
$entries | Where-Object -Property Level -EQ 'ERROR' | Select-Object -First 3
```

```text
Time                 Level Message
----                 ----- -------
11/3/2026 8:14:48 AM ERROR Connection to database failed
11/3/2026 8:30:13 AM ERROR Connection to database failed
11/3/2026 8:45:38 AM ERROR Connection to database failed
```

Now `Time` is a `DateTime`, and you can filter by time, group by level, or
export the errors to a CSV file.

## Common pitfalls

- **`-replace` uses regular expressions.** In a pattern, the dot stands for
  any character, so every character is replaced:

  ```powershell
  'app.log' -replace '.', '_'
  'app.log' -replace '\.', '_'
  'app.log'.Replace('.', '_')
  ```

  ```text
  _______
  app_log
  app_log
  ```

  Escape special characters with a backslash, or use the `.Replace()`
  method for plain text. `[regex]::Escape()` escapes a whole string for you.

- **A variable directly followed by text.** In `"$name_backup.zip"`,
  PowerShell looks for the variable `$name_backup`, which doesn't exist.
  Braces mark where the name ends:

  ```powershell
  $name = 'database'
  "$name_backup.zip"
  "${name}_backup.zip"
  ```

  ```text
  .zip
  database_backup.zip
  ```

  A colon after a variable, as in `"$level: failed"`, is even a syntax
  error: PowerShell reads the name before the colon as a scope, like
  `global` in `$global:count`. Write `"${level}: failed"`.

- **A single quote inside single quotes.** Double it, or switch to double
  quotes:

  ```powershell
  'It''s done'
  "It's done"
  ```

  ```text
  It's done
  It's done
  ```

## Exercises

The exercises use the log files of the sample folder. If you start a new
session, create the folder again with
`$root = ./samples/New-WorkshopFolder.ps1 -Force`, from the root of this
repository.

### Exercise 1: A report line per log file

1. Get every log file in the sample folder, including the archive.
2. Write one aligned line per file: the name left-aligned in 20 characters,
   the size in bytes with thousands separators right-aligned in 8
   characters, and the date of the last change as `yyyy-MM-dd`.

<details>
<summary>Solution</summary>

```powershell
Get-ChildItem -Path $root -Recurse -File -Filter *.log | ForEach-Object {
    '{0,-20}{1,8:N0} bytes  {2:yyyy-MM-dd}' -f $_.Name, $_.Length, $_.LastWriteTime
}
```

```text
app-2026-11-01.log    30,215 bytes  2026-11-01
app-2026-11-02.log    40,285 bytes  2026-11-02
app-2026-11-03.log    50,352 bytes  2026-11-03
web-2026-11-03.log    20,133 bytes  2026-11-03
app-2026-10-30.log    15,104 bytes  2026-10-30
app-2026-10-31.log    25,201 bytes  2026-10-31
```

One template formats all three values. `N0` adds the thousands separator
and no decimals; the date format works inside the placeholder, too.

</details>

### Exercise 2: Count the log levels

1. Read all log files in the sample folder, including the archive.
2. Split every line, and count the lines per level.

<details>
<summary>Solution</summary>

```powershell
Get-ChildItem -Path $root -Recurse -File -Filter *.log |
    Get-Content |
    ForEach-Object { ($_ -split '\s+')[2] } |
    Group-Object -NoElement |
    Sort-Object -Property Count
```

```text
Count Name
----- ----
  144 ERROR
  288 WARN
 3168 INFO
```

The level is the third part of every line, index `2`. `Group-Object`
without `-Property` groups the strings themselves.

</details>

### Exercise 3: File names with time stamps

1. Build the file name `Report_20261117_092729.csv` from the date
   17 November 2026, 09:27:29.
2. The log files carry their date in the name, such as
   `app-2026-11-03.log`. Turn the name of every log file back into a
   `DateTime` and show the name with the weekday of that date.

<details>
<summary>Solution</summary>

```powershell
'Report_{0:yyyyMMdd_HHmmss}.csv' -f (Get-Date -Date '2026-11-17 09:27:29')
```

```text
Report_20261117_092729.csv
```

```powershell
Get-ChildItem -Path $root -Recurse -File -Filter *.log | ForEach-Object {
    $text = $_.BaseName -replace '^\w+-', ''
    $date = [datetime]::ParseExact($text, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
    '{0,-20}{1:dddd}' -f $_.Name, $date
}
```

```text
app-2026-11-01.log  Sunday
app-2026-11-02.log  Monday
app-2026-11-03.log  Tuesday
web-2026-11-03.log  Tuesday
app-2026-10-30.log  Friday
app-2026-10-31.log  Saturday
```

`-replace '^\w+-'` removes the service name and its hyphen at the start of
the name. `ParseExact()` reads the date in exactly the format you name, with
the invariant culture, independent of the computer.

</details>

## Key takeaways

- Single quotes are verbatim, double quotes expand variables. Use `$()` for
  properties and expressions, and `${name}` when text follows a name.
- Here-strings, `@' '@` and `@" "@`, hold multi-line text and quotation
  marks without escaping.
- `-f` fills placeholders such as `{0,-20}` and `{1,10:N0}`; `MM` is the
  month and `mm` the minute.
- `-f` uses the current culture. For files that other programs read, format
  with `[cultureinfo]::InvariantCulture` or a fixed format string.
- `-replace` and `-split` use regular expressions and ignore case;
  `.Replace()` and `.Split()` work with plain text and respect case.
- `-split '\s+'` and `[pscustomobject]` turn lines of text into objects.

## Learn more

- [about_Quoting_Rules](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_quoting_rules)
  and its section on
  [culture settings](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_quoting_rules#culture-settings-affect-string-interpretation)
- [about_Special_Characters](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_special_characters)
- [about_Operators: format operator](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_operators#format-operator--f)
- [about_Split](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_split)
  and [about_Join](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_join)
- [about_Regular_Expressions](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_regular_expressions)
- [Everything you wanted to know about variable substitution in strings](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-string-substitutions)
- [Composite formatting](https://learn.microsoft.com/dotnet/standard/base-types/composite-formatting),
  [standard numeric format strings](https://learn.microsoft.com/dotnet/standard/base-types/standard-numeric-format-strings),
  and [custom date and time format strings](https://learn.microsoft.com/dotnet/standard/base-types/custom-date-and-time-format-strings)
- [Get-Date](https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/get-date)
  and [standard date and time format strings](https://learn.microsoft.com/dotnet/standard/base-types/standard-date-and-time-format-strings)

---

[← Previous: Inspecting and extending objects](07-inspecting-and-extending-objects.md)
· [Overview](../README.md) ·
[Next: Your first function →](09-your-first-function.md)
