BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

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

        $script:BootstrapSteps = [System.Collections.Generic.List[string]]::new()

        Mock -ModuleName Devolutions.CIEM Get-PSUApp { throw 'Initialize-CIEMPSUInstance must not query live PSU apps.' }
        Mock -ModuleName Devolutions.CIEM Get-PSUScript { throw 'Initialize-CIEMPSUInstance must not query live PSU scripts.' }
        Mock -ModuleName Devolutions.CIEM Import-CIEMScript { throw 'Initialize-CIEMPSUInstance must not register PSU scripts.' }

        Mock -ModuleName Devolutions.CIEM Get-CIEMPSUScriptDefinition {
            $script:BootstrapSteps.Add('Get-CIEMPSUScriptDefinition')
            @($script:ExpectedScriptNames | ForEach-Object {
                    [pscustomobject]@{
                        Name                    = $_
                        Content                 = 'Write-Output test'
                        Description             = $_
                        Status                  = 'Published'
                        Timeout                 = 30
                        DisableManualInvocation = $false
                    }
                })
        }

        Mock -ModuleName Devolutions.CIEM New-CIEMDatabase {
            $script:BootstrapSteps.Add('New-CIEMDatabase')
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

    It 'validates packaged PSU resources, initializes the database, and does not register scripts' {
        $result = Initialize-CIEMPSUInstance -Integrated

        $result.Status | Should -Be 'Initialized'
        $result.ExpectedScriptCount | Should -Be $script:ExpectedScriptNames.Count
        $result.DatabaseInitialized | Should -BeTrue
        $result.DatabasePath | Should -Be $script:DatabasePath
        $result.PSObject.Properties.Name | Should -Not -Contain 'PrunedLegacyScripts'

        Should -Invoke -CommandName Get-CIEMPSUScriptDefinition -ModuleName Devolutions.CIEM -Times 1
        Should -Invoke -CommandName Get-PSUApp -ModuleName Devolutions.CIEM -Times 0
        Should -Invoke -CommandName Get-PSUScript -ModuleName Devolutions.CIEM -Times 0
        Should -Invoke -CommandName Import-CIEMScript -ModuleName Devolutions.CIEM -Times 0
        Should -Invoke -CommandName New-CIEMDatabase -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $PassThru.IsPresent }
        $script:BootstrapSteps | Should -Be @(
            'Get-CIEMPSUScriptDefinition'
            'New-CIEMDatabase'
        )
    }

    It 'throws when packaged script definitions cannot be resolved' {
        Mock -ModuleName Devolutions.CIEM Get-CIEMPSUScriptDefinition { @() }

        { Initialize-CIEMPSUInstance -Integrated } |
            Should -Throw -ExpectedMessage '*script definitions could not be resolved*'

        Should -Invoke -CommandName Import-CIEMScript -ModuleName Devolutions.CIEM -Times 0
        Should -Invoke -CommandName New-CIEMDatabase -ModuleName Devolutions.CIEM -Times 0
    }

    It 'throws when database initialization does not create the database file' {
        Mock -ModuleName Devolutions.CIEM New-CIEMDatabase {
            $script:DatabasePath
        }

        { Initialize-CIEMPSUInstance -Integrated } |
            Should -Throw -ExpectedMessage '*CIEM database was not created*'
    }
}
