# Sample data

This folder holds the sample data for the exercises in the workshop notes, so
that every exercise runs on any machine with PowerShell.

## Contents

| File                           | Purpose                                                                    |
|--------------------------------|----------------------------------------------------------------------------|
| `People.csv`                   | 24 fictional people for the topics on objects, CSV files, and pipelines    |
| `New-WorkshopFolder.ps1`       | Creates a folder tree with 22 sample files for the file and pipeline tasks |
| `New-WorkshopFolder.Tests.ps1` | Pester tests for `New-WorkshopFolder.ps1`, also an example of a test file  |

## People.csv

The file uses semicolons as separators, like many CSV exports from Excel in
Europe. Read it with:

```powershell
$people = Import-Csv -Path ./samples/People.csv -Delimiter ';'
```

- The columns are `Surname`, `GivenName`, `Department`, `City`, `Age`,
  `Projects`, `HireDate`, `Name`, and `EmailAddress`.
- All people are fictional, and all email addresses use the reserved domain
  `example.com`.
- The departments are IT with 9 people, Sales with 7, HR with 5, and Finance
  with 3.
- `Name` holds the account name, such as `JDoe`, not the surname.
- `Age` and `Projects` contain numbers, but like every value in a CSV file,
  PowerShell reads them as strings.

## The sample folder

Run the script from the root of the repository. It returns the new folder:

```powershell
$root = ./samples/New-WorkshopFolder.ps1 -Force
```

- Without `-Path`, the script creates the folder `WorkshopFiles` in the
  temporary folder of the current user.
- With `-Force`, it replaces an existing folder, but only one that it created
  itself. It refuses to delete any other folder.
- Every run creates the same files with the same sizes, content, and dates,
  on Windows, Linux, and macOS, in Windows PowerShell 5.1 and PowerShell 7.

| Folder             | Files                                                              |
|--------------------|--------------------------------------------------------------------|
| (root)             | `readme.txt`, `notes.TXT`, `LICENSE`                               |
| `data`             | `customers.csv`, `orders.csv`, `settings.json`, `users.json`       |
| `logs`             | Four log files, one per day and service                            |
| `logs/archive.old` | Two older log files                                                |
| `scripts`          | `Get-Report.ps1`, `Set-Config.ps1`, `Start-Backup.ps1`, `todo.txt` |
| `config`           | `app.json`, `web.json`, `changes.txt`                              |
| `backup`           | `database.bak` with 2 MB, `backup-notes.txt`                       |

The folder contains the special cases that the exercises discuss: `LICENSE`
has no extension, `notes.TXT` has an upper-case extension, and the name of
the folder `archive.old` contains a dot.

| Extension      | Files | Total size in bytes |
|----------------|------:|--------------------:|
| `.log`         |     6 |             181,290 |
| `.txt`         |     5 |                 259 |
| `.json`        |     4 |                 548 |
| `.ps1`         |     3 |                 267 |
| `.csv`         |     2 |              23,306 |
| `.bak`         |     1 |           2,097,152 |
| (no extension) |     1 |                  34 |

## Run the tests

The tests need Pester 5 or later. Run them from the root of the repository:

```powershell
Invoke-Pester -Path ./samples -Output Detailed
```
