<#
    .SYNOPSIS
        Creates a folder tree with sample files for the workshop exercises.

    .DESCRIPTION
        New-WorkshopFolder.ps1 creates a folder with five subfolders and 22
        files: log, text, JSON, PowerShell, CSV, and backup files of different
        sizes and dates. The content is the same on every run, on every
        platform, and in every culture, so the results of the exercises are
        predictable.

        The tree also contains the special cases the exercises discuss: a file
        without an extension (LICENSE), a file with an upper-case extension
        (notes.TXT), and a folder whose name contains a dot
        (logs/archive.old).

        The script marks the folder with the hidden file .workshopfiles. With
        the Force parameter, it replaces only a folder that carries this
        marker, so it never deletes a folder it did not create.

    .PARAMETER Path
        Specifies the folder to create. The default is the folder
        WorkshopFiles in the temporary folder of the current user.

    .PARAMETER Force
        Replaces the folder when it already exists and was created by this
        script.

    .EXAMPLE
        ./New-WorkshopFolder.ps1

        Creates the sample tree in the folder WorkshopFiles in the temporary
        folder and returns the folder.

    .EXAMPLE
        $root = ./New-WorkshopFolder.ps1 -Path ~/WorkshopFiles -Force
        Get-ChildItem -Path $root -Recurse -File

        Re-creates the sample tree in the home folder and lists its files.

    .OUTPUTS
        System.IO.DirectoryInfo

        The root folder of the sample tree.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
[OutputType([System.IO.DirectoryInfo])]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Path = (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath 'WorkshopFiles'),

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $Force
)

$ErrorActionPreference = 'Stop'

$invariant = [System.Globalization.CultureInfo]::InvariantCulture
$utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
$markerName = '.workshopfiles'

# Resolve relative paths and ~ against the PowerShell location, not the process directory.
$rootPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
$markerPath = Join-Path -Path $rootPath -ChildPath $markerName

function Get-SampleLogContent {
    param (
        [System.DateTime]$Start,
        [System.Int32]$LineCount
    )

    $messages = @(
        'Service started'
        'Loaded configuration from config/app.json'
        'Request processed in 120 ms'
        'User signed in'
        'Cache refreshed'
        'Request processed in 85 ms'
        'Scheduled job finished'
    )

    $lines = for ($index = 0; $index -lt $LineCount; $index++) {
        if ($index % 25 -eq 24) {
            $level = 'ERROR'
            $message = 'Connection to database failed'
        } elseif ($index % 10 -eq 9) {
            $level = 'WARN '
            $message = 'Response time above 500 ms'
        } else {
            $level = 'INFO '
            $message = $messages[$index % $messages.Count]
        }

        $timestamp = $Start.AddSeconds($index * 37).ToString('yyyy-MM-dd HH:mm:ss', $invariant)
        '{0} {1} {2}' -f $timestamp, $level, $message
    }

    ($lines -join "`n") + "`n"
}

function Get-SampleCsvContent {
    param (
        [System.String]$Kind
    )

    $cities = @('Berlin', 'Munich', 'Hamburg', 'Vienna', 'Zurich')
    $countries = @('Germany', 'Germany', 'Germany', 'Austria', 'Switzerland')

    if ($Kind -eq 'Customers') {
        $lines = @('CustomerId,Name,City,Country')
        for ($index = 1; $index -le 60; $index++) {
            $cityIndex = $index % $cities.Count
            $lines += '{0},Customer {0:D3},{1},{2}' -f $index, $cities[$cityIndex], $countries[$cityIndex]
        }
    } else {
        $lines = @('OrderId,CustomerId,OrderDate,Amount')
        $firstDay = New-Object -TypeName System.DateTime -ArgumentList 2026, 1, 1
        for ($index = 0; $index -lt 800; $index++) {
            $customerId = (($index * 7) % 60) + 1
            $orderDate = $firstDay.AddDays($index % 300).ToString('yyyy-MM-dd', $invariant)
            $amount = ((($index * 37) % 500) + 9.99).ToString('0.00', $invariant)
            $lines += '{0},{1},{2},{3}' -f (10001 + $index), $customerId, $orderDate, $amount
        }
    }

    ($lines -join "`n") + "`n"
}

$readmeText = @'
Sample files for the PowerShell workshop exercises.
Created by New-WorkshopFolder.ps1. Every run creates the same files.
'@

$settingsJson = @'
{
    "applicationName": "Inventory",
    "version": "1.4.2",
    "logLevel": "Information",
    "retentionDays": 30,
    "features": {
        "export": true,
        "notifications": false
    }
}
'@

$usersJson = @'
[
    { "name": "jdoe", "role": "Administrator", "enabled": true },
    { "name": "swang", "role": "Editor", "enabled": true },
    { "name": "guest", "role": "Reader", "enabled": false }
]
'@

$appJson = @'
{
    "port": 8080,
    "database": "inventory",
    "timeoutSeconds": 30
}
'@

$webJson = @'
{
    "port": 443,
    "certificate": "web.example.com",
    "compression": true
}
'@

$getReportScript = @'
param ([string]$Path = '.')

Get-ChildItem -Path $Path -File |
    Measure-Object -Property Length -Sum
'@

$setConfigScript = @'
param ([string]$Name, [string]$Value)

Write-Output "Setting $Name to $Value"
'@

$startBackupScript = @'
param ([string]$Destination = './backup')

Write-Output "Backing up to $Destination"
'@

# Each entry: relative path, content, and last write time. Log files start at 08:00 on their date.
$files = @(
    @{ Path = 'readme.txt'; Text = $readmeText; Date = '2026-09-01 09:05' }
    @{ Path = 'notes.TXT'; Text = 'Notes with an upper-case extension.'; Date = '2026-09-02 10:30' }
    @{ Path = 'LICENSE'; Text = 'Sample file without an extension.'; Date = '2026-09-01 09:00' }
    @{ Path = 'data/customers.csv'; Text = (Get-SampleCsvContent -Kind 'Customers'); Date = '2026-10-15 17:45' }
    @{ Path = 'data/orders.csv'; Text = (Get-SampleCsvContent -Kind 'Orders'); Date = '2026-11-03 18:00' }
    @{ Path = 'data/settings.json'; Text = $settingsJson; Date = '2026-10-01 08:15' }
    @{ Path = 'data/users.json'; Text = $usersJson; Date = '2026-10-20 11:20' }
    @{ Path = 'logs/app-2026-11-01.log'; Lines = 600; Date = '2026-11-01 23:59' }
    @{ Path = 'logs/app-2026-11-02.log'; Lines = 800; Date = '2026-11-02 23:59' }
    @{ Path = 'logs/app-2026-11-03.log'; Lines = 1000; Date = '2026-11-03 23:59' }
    @{ Path = 'logs/web-2026-11-03.log'; Lines = 400; Date = '2026-11-03 22:30' }
    @{ Path = 'logs/archive.old/app-2026-10-30.log'; Lines = 300; Date = '2026-10-30 23:59' }
    @{ Path = 'logs/archive.old/app-2026-10-31.log'; Lines = 500; Date = '2026-10-31 23:59' }
    @{ Path = 'scripts/Get-Report.ps1'; Text = $getReportScript; Date = '2026-09-15 14:00' }
    @{ Path = 'scripts/Set-Config.ps1'; Text = $setConfigScript; Date = '2026-09-16 15:00' }
    @{ Path = 'scripts/Start-Backup.ps1'; Text = $startBackupScript; Date = '2026-09-17 16:00' }
    @{ Path = 'scripts/todo.txt'; Text = "Add error handling.`nWrite Pester tests."; Date = '2026-10-05 12:00' }
    @{ Path = 'config/app.json'; Text = $appJson; Date = '2026-10-10 09:30' }
    @{ Path = 'config/web.json'; Text = $webJson; Date = '2026-10-11 09:45' }
    @{ Path = 'config/changes.txt'; Text = 'Changed the app port to 8080.'; Date = '2026-10-10 09:31' }
    @{ Path = 'backup/database.bak'; Bytes = 2MB; Date = '2026-11-03 02:00' }
    @{ Path = 'backup/backup-notes.txt'; Text = 'Nightly backup of the database.'; Date = '2026-11-03 02:05' }
)

if (Test-Path -LiteralPath $rootPath) {
    if (-not $Force) {
        throw "The folder '$rootPath' already exists. Use -Force to re-create it."
    }

    if (-not (Test-Path -LiteralPath $markerPath)) {
        throw "The folder '$rootPath' was not created by this script. Choose another path."
    }

    if ($PSCmdlet.ShouldProcess($rootPath, 'Remove the existing workshop folder')) {
        Remove-Item -LiteralPath $rootPath -Recurse -Force
    }
}

if ($PSCmdlet.ShouldProcess($rootPath, 'Create the workshop sample folder')) {
    $null = New-Item -Path $rootPath -ItemType Directory -Force

    foreach ($file in $files) {
        $filePath = Join-Path -Path $rootPath -ChildPath $file.Path
        $null = New-Item -Path (Split-Path -Path $filePath -Parent) -ItemType Directory -Force

        $lastWriteTime = [System.DateTime]::ParseExact($file.Date, 'yyyy-MM-dd HH:mm', $invariant)

        if ($file.ContainsKey('Bytes')) {
            $bytes = New-Object -TypeName 'System.Byte[]' -ArgumentList $file.Bytes
            [System.IO.File]::WriteAllBytes($filePath, $bytes)
        } elseif ($file.ContainsKey('Lines')) {
            $content = Get-SampleLogContent -Start $lastWriteTime.Date.AddHours(8) -LineCount $file.Lines
            [System.IO.File]::WriteAllText($filePath, $content, $utf8NoBom)
        } else {
            $text = $file.Text -replace "`r`n", "`n"
            if (-not $text.EndsWith("`n")) {
                $text += "`n"
            }
            [System.IO.File]::WriteAllText($filePath, $text, $utf8NoBom)
        }

        [System.IO.File]::SetLastWriteTime($filePath, $lastWriteTime)
    }

    [System.IO.File]::WriteAllText($markerPath, "Created by New-WorkshopFolder.ps1`n", $utf8NoBom)
    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        $marker = Get-Item -LiteralPath $markerPath -Force
        $marker.Attributes = $marker.Attributes -bor [System.IO.FileAttributes]::Hidden
    }

    Get-Item -LiteralPath $rootPath
}
