BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    $script:ManagedScriptNotes = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json'
    $script:DatabasePath = Join-Path $TestDrive 'ciem.db'
    $script:ManifestPath = Join-Path $PSScriptRoot '..' '..' 'data' 'psu-scripts.json'
    $script:Manifest = Get-Content -Path $script:ManifestPath -Raw | ConvertFrom-Json -Depth 10
    $script:RemediationRoot = Join-Path (Join-Path $PSScriptRoot '..' '..') ([string]$script:Manifest.remediationTemplates.path)
    $script:ExpectedScriptNames = @(
        @($script:Manifest.scripts | ForEach-Object { ([string]$_.name).Replace('\', '/').TrimStart('/') })
        @(Get-ChildItem -Path $script:RemediationRoot -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) })
    )
}

Describe 'Initialize-CIEMPSUInstance' {
    BeforeEach {
        Remove-Item -Path $script:DatabasePath -Force -ErrorAction SilentlyContinue

        Mock -ModuleName Devolutions.CIEM Get-Command {
            [pscustomobject]@{ Name = $Name }
        } -ParameterFilter { $Name -in @('Get-PSUApp', 'Get-PSUScript') }

        Mock -ModuleName Devolutions.CIEM Get-PSUApp {
            @(
                [pscustomobject]@{
                    Name    = 'Devolutions CIEM'
                    BaseUrl = '/ciem'
                    Module  = 'Devolutions.CIEM'
                    Command = 'New-DevolutionsCIEMApp'
                }
            )
        }

        Mock -ModuleName Devolutions.CIEM Get-PSUScript {
            @($script:ExpectedScriptNames | ForEach-Object {
                    [pscustomobject]@{
                        Name        = $_
                        FullPath    = "$_.ps1"
                        CommitNotes = $script:ManagedScriptNotes
                    }
                })
        }

        Mock -ModuleName Devolutions.CIEM Import-CIEMScript {
            [pscustomobject]@{
                Status       = 'Registered'
                TotalScripts = $script:ExpectedScriptNames.Count
            }
        }

        Mock -ModuleName Devolutions.CIEM New-CIEMDatabase {
            New-Item -Path (Split-Path $script:DatabasePath -Parent) -ItemType Directory -Force | Out-Null
            Set-Content -Path $script:DatabasePath -Value ''
            $script:DatabasePath
        }

        Mock -ModuleName Devolutions.CIEM Invoke-CIEMQuery {
            if ($Query -match "sqlite_master.+name\s*=\s*'providers'") {
                return @([pscustomobject]@{ name = 'providers' })
            }
            if ($Query -match "sqlite_master.+name\s*=\s*'provider_auth_methods'") {
                return @([pscustomobject]@{ name = 'provider_auth_methods' })
            }
            if ($Query -match "sqlite_master.+name\s*=\s*'checks'") {
                return @([pscustomobject]@{ name = 'checks' })
            }
            if ($Query -match "sqlite_master.+name\s*=\s*'attack_path_rules'") {
                return @([pscustomobject]@{ name = 'attack_path_rules' })
            }
            if ($Query -match 'COUNT\(\*\).+FROM\s+providers') {
                return @([pscustomobject]@{ RowCount = 2 })
            }
            if ($Query -match 'COUNT\(\*\).+FROM\s+provider_auth_methods') {
                return @([pscustomobject]@{ RowCount = 5 })
            }
            if ($Query -match 'COUNT\(\*\).+FROM\s+checks') {
                return @([pscustomobject]@{ RowCount = 10 })
            }
            if ($Query -match 'COUNT\(\*\).+FROM\s+attack_path_rules') {
                return @([pscustomobject]@{ RowCount = 3 })
            }

            throw "Unexpected CIEM bootstrap verification query: $Query"
        }
    }

    It 'registers scripts, initializes the database, and verifies the ready state' {
        $result = Initialize-CIEMPSUInstance -Integrated

        $result.Status | Should -Be 'Ready'
        $result.AppCount | Should -Be 1
        $result.ScriptCount | Should -Be $script:ExpectedScriptNames.Count
        $result.ExpectedScriptCount | Should -Be $script:ExpectedScriptNames.Count
        $result.DatabaseInitialized | Should -BeTrue
        $result.DatabasePath | Should -Be $script:DatabasePath

        Should -Invoke -CommandName Get-PSUApp -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $Integrated.IsPresent }
        Should -Invoke -CommandName Import-CIEMScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $Integrated.IsPresent }
        Should -Invoke -CommandName New-CIEMDatabase -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $PassThru.IsPresent }
        Should -Invoke -CommandName Get-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $Integrated.IsPresent }
    }

    It 'throws before bootstrap when duplicate CIEM apps exist' {
        Mock -ModuleName Devolutions.CIEM Get-PSUApp {
            @(
                [pscustomobject]@{ Name = 'Devolutions CIEM'; BaseUrl = '/ciem' }
                [pscustomobject]@{ Name = 'Devolutions CIEM'; BaseUrl = '/ciem' }
            )
        }

        { Initialize-CIEMPSUInstance -Integrated } |
            Should -Throw -ExpectedMessage "*expected one or zero Devolutions CIEM app registrations before configuration completes*"

        Should -Invoke -CommandName Import-CIEMScript -ModuleName Devolutions.CIEM -Times 0
        Should -Invoke -CommandName New-CIEMDatabase -ModuleName Devolutions.CIEM -Times 0
    }

    It 'throws when the script registration verification is incomplete' {
        Mock -ModuleName Devolutions.CIEM Get-PSUScript {
            @(
                [pscustomobject]@{
                    Name        = $script:ExpectedScriptNames[0]
                    CommitNotes = $script:ManagedScriptNotes
                }
            )
        }

        { Initialize-CIEMPSUInstance -Integrated } |
            Should -Throw -ExpectedMessage '*expected*CIEM-managed PSU scripts*'
    }

    It 'throws when database initialization does not create the database file' {
        Mock -ModuleName Devolutions.CIEM New-CIEMDatabase {
            $script:DatabasePath
        }

        { Initialize-CIEMPSUInstance -Integrated } |
            Should -Throw -ExpectedMessage '*CIEM database was not created*'
    }
}
