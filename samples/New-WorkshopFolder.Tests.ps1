BeforeAll {
    $script:scriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'New-WorkshopFolder.ps1'

    function Get-TreeHash {
        param (
            [System.String]
            $Path
        )

        Get-ChildItem -LiteralPath $Path -Recurse -File |
            Sort-Object -Property FullName |
            ForEach-Object -Process { (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }
    }
}

Describe 'New-WorkshopFolder.ps1' {
    Context 'When the folder does not exist' {
        BeforeAll {
            $script:rootPath = Join-Path -Path $TestDrive -ChildPath 'WorkshopFiles'
            $script:result = & $script:scriptPath -Path $script:rootPath
            $script:files = Get-ChildItem -LiteralPath $script:rootPath -Recurse -File
        }

        It 'Should return the root folder' {
            $script:result | Should -BeOfType ([System.IO.DirectoryInfo])
            $script:result.FullName | Should -Be (Get-Item -LiteralPath $script:rootPath).FullName
        }

        It 'Should create 22 visible files' {
            $script:files.Count | Should -Be 22
        }

        It 'Should create <Count> files with the extension "<Extension>"' -ForEach @(
            @{ Extension = '.log'; Count = 6 }
            @{ Extension = '.txt'; Count = 5 }
            @{ Extension = '.json'; Count = 4 }
            @{ Extension = '.ps1'; Count = 3 }
            @{ Extension = '.csv'; Count = 2 }
            @{ Extension = '.bak'; Count = 1 }
            @{ Extension = ''; Count = 1 }
        ) {
            @($script:files | Where-Object -FilterScript { $_.Extension -eq $Extension }).Count |
                Should -Be $Count
        }

        It 'Should create the folder archive.old, whose name contains a dot' {
            Join-Path -Path $script:rootPath -ChildPath 'logs/archive.old' | Should -Exist
        }

        It 'Should hide its marker file from Get-ChildItem' {
            $script:files.Name | Should -Not -Contain '.workshopfiles'
            Join-Path -Path $script:rootPath -ChildPath '.workshopfiles' | Should -Exist
        }

        It 'Should set the last write time of the files' {
            $logPath = Join-Path -Path $script:rootPath -ChildPath 'logs/app-2026-11-01.log'
            (Get-Item -LiteralPath $logPath).LastWriteTime | Should -Be ([System.DateTime]'2026-11-01 23:59')
        }
    }

    Context 'When the script runs twice' {
        It 'Should write the same content every time' {
            $first = & $script:scriptPath -Path (Join-Path -Path $TestDrive -ChildPath 'First')
            $second = & $script:scriptPath -Path (Join-Path -Path $TestDrive -ChildPath 'Second')

            Get-TreeHash -Path $second.FullName | Should -Be (Get-TreeHash -Path $first.FullName)
        }
    }

    Context 'When the folder already exists' {
        BeforeAll {
            $script:existingPath = Join-Path -Path $TestDrive -ChildPath 'Existing'
            $null = & $script:scriptPath -Path $script:existingPath
        }

        It 'Should throw without -Force' {
            { & $script:scriptPath -Path $script:existingPath } |
                Should -Throw -ExpectedMessage '*already exists*'
        }

        It 'Should re-create the folder with -Force' {
            $extraFilePath = Join-Path -Path $script:existingPath -ChildPath 'extra.txt'
            Set-Content -LiteralPath $extraFilePath -Value 'extra'

            $null = & $script:scriptPath -Path $script:existingPath -Force

            $extraFilePath | Should -Not -Exist
            @(Get-ChildItem -LiteralPath $script:existingPath -Recurse -File).Count | Should -Be 22
        }

        It 'Should not remove a folder that it did not create' {
            $foreignPath = Join-Path -Path $TestDrive -ChildPath 'Foreign'
            $null = New-Item -Path $foreignPath -ItemType Directory

            { & $script:scriptPath -Path $foreignPath -Force } |
                Should -Throw -ExpectedMessage '*not created by this script*'
            $foreignPath | Should -Exist
        }
    }

    Context 'When the WhatIf parameter is used' {
        It 'Should not create anything' {
            $whatIfPath = Join-Path -Path $TestDrive -ChildPath 'WhatIf'

            $null = & $script:scriptPath -Path $whatIfPath -WhatIf

            $whatIfPath | Should -Not -Exist
        }
    }
}
