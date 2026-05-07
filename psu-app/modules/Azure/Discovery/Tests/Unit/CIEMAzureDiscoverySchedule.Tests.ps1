BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Azure scheduled discovery configuration' {
    BeforeEach {
        Invoke-CIEMQuery -Query 'DELETE FROM azure_discovery_schedules' -AsNonQuery | Out-Null
        Mock -ModuleName Devolutions.CIEM Get-PSUScript {
            [pscustomobject]@{ Id = 10; Name = 'Devolutions.CIEM\Start-CIEMAzureDiscovery' }
        }
        Mock -ModuleName Devolutions.CIEM Get-PSUSchedule { @() }
        Mock -ModuleName Devolutions.CIEM New-PSUSchedule {
            [pscustomobject]@{ Id = 9001; Name = $Name; Description = $Description }
        }
        Mock -ModuleName Devolutions.CIEM Remove-PSUSchedule {}
    }

    It 'exports scheduled discovery commands' {
        Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureDiscoverySchedule -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command -Module Devolutions.CIEM -Name Set-CIEMAzureDiscoverySchedule -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command -Module Devolutions.CIEM -Name Update-CIEMAzureDiscoveryScheduleStatus -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'creates the local schedule metadata table during database setup' {
        $tables = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'azure_discovery_schedules'")

        $tables | Should -HaveCount 1
    }

    It 'creates a PSU schedule for the existing Start-CIEMAzureDiscovery command and persists local metadata' {
        $result = Set-CIEMAzureDiscoverySchedule -Scope 'All' -Cron '0 2 * * *' -Enabled $true

        $result.ProviderId | Should -Be 'azure'
        $result.Scope | Should -Be 'All'
        $result.Cron | Should -Be '0 2 * * *'
        $result.Enabled | Should -BeTrue
        $result.PsuScheduleId | Should -Be 9001
        $result.PsuScriptName | Should -Be 'Devolutions.CIEM\Start-CIEMAzureDiscovery'

        Should -Invoke -CommandName New-PSUSchedule -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
            $Name -eq 'CIEM Azure Discovery' -and
            $Cron -eq '0 2 * * *' -and
            $Parameters.Scope -eq 'All' -and
            $Integrated
        }

        $stored = Get-CIEMAzureDiscoverySchedule
        $stored | Should -HaveCount 1
        $stored[0].PsuScheduleName | Should -Be 'CIEM Azure Discovery'
    }

    It 'throws when the discovery PSU script is not registered exactly once' {
        Mock -ModuleName Devolutions.CIEM Get-PSUScript { @() }

        { Set-CIEMAzureDiscoverySchedule -Scope 'All' -Cron '0 2 * * *' -Enabled $true } |
            Should -Throw -ExpectedMessage '*expected one Devolutions.CIEM\Start-CIEMAzureDiscovery PSU script*'
    }

    It 'preserves an existing managed schedule when the discovery PSU script is missing' {
        Mock -ModuleName Devolutions.CIEM Get-PSUSchedule {
            [pscustomobject]@{
                Id          = 9001
                Name        = 'CIEM Azure Discovery'
                Description = 'ManagedBy=Devolutions.CIEM;Purpose=AzureDiscoverySchedule'
            }
        }
        Mock -ModuleName Devolutions.CIEM Get-PSUScript { @() }

        { Set-CIEMAzureDiscoverySchedule -Scope 'All' -Cron '0 2 * * *' -Enabled $true } |
            Should -Throw -ExpectedMessage '*expected one Devolutions.CIEM\Start-CIEMAzureDiscovery PSU script*'

        Should -Invoke -CommandName Remove-PSUSchedule -ModuleName Devolutions.CIEM -Times 0
    }

    It 'preserves an existing managed schedule when replacement schedule creation fails' {
        Mock -ModuleName Devolutions.CIEM Get-PSUSchedule {
            [pscustomobject]@{
                Id          = 9001
                Name        = 'CIEM Azure Discovery'
                Description = 'ManagedBy=Devolutions.CIEM;Purpose=AzureDiscoverySchedule'
            }
        }
        Mock -ModuleName Devolutions.CIEM New-PSUSchedule { throw 'PSU schedule create failed' }

        { Set-CIEMAzureDiscoverySchedule -Scope 'All' -Cron '0 2 * * *' -Enabled $true } |
            Should -Throw -ExpectedMessage '*PSU schedule create failed*'

        Should -Invoke -CommandName Remove-PSUSchedule -ModuleName Devolutions.CIEM -Times 0
    }

    It 'removes an existing CIEM-owned schedule when disabled and persists disabled state' {
        Mock -ModuleName Devolutions.CIEM Get-PSUSchedule {
            [pscustomobject]@{
                Id          = 9001
                Name        = 'CIEM Azure Discovery'
                Description = 'ManagedBy=Devolutions.CIEM;Purpose=AzureDiscoverySchedule'
            }
        }

        $result = Set-CIEMAzureDiscoverySchedule -Scope 'ARM' -Cron '0 2 * * 1' -Enabled $false

        $result.Enabled | Should -BeFalse
        $result.PsuScheduleId | Should -BeNullOrEmpty
        Should -Invoke -CommandName Remove-PSUSchedule -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
            $Schedule.Id -eq 9001 -and $Integrated
        }
    }

    It 'updates the persisted last-run status for scheduled discovery runs' {
        Set-CIEMAzureDiscoverySchedule -Scope 'All' -Cron '0 2 * * *' -Enabled $true | Out-Null

        $result = Update-CIEMAzureDiscoveryScheduleStatus `
            -PsuScheduleId 9001 `
            -LastStatus 'Completed' `
            -LastDiscoveryRunId 42 `
            -LastPsuJobId 5001

        $result.LastStatus | Should -Be 'Completed'
        $result.LastDiscoveryRunId | Should -Be 42
        $result.LastPsuJobId | Should -Be 5001
        $result.LastCheckedAt | Should -Not -BeNullOrEmpty
    }

    It 'rejects invalid cron strings before calling PSU schedule cmdlets' {
        { Set-CIEMAzureDiscoverySchedule -Scope 'All' -Cron 'daily' -Enabled $true } |
            Should -Throw -ExpectedMessage '*Cron must contain exactly 5 fields*'

        Should -Invoke -CommandName New-PSUSchedule -ModuleName Devolutions.CIEM -Times 0
    }

    It 'rejects unsupported five-field cron strings before calling PSU schedule cmdlets' {
        { Set-CIEMAzureDiscoverySchedule -Scope 'All' -Cron '30 5 * * *' -Enabled $true } |
            Should -Throw -ExpectedMessage "*Unsupported scheduled discovery cron '30 5 * * *'.*"

        Should -Invoke -CommandName New-PSUSchedule -ModuleName Devolutions.CIEM -Times 0
        Should -Invoke -CommandName Remove-PSUSchedule -ModuleName Devolutions.CIEM -Times 0
    }
}
