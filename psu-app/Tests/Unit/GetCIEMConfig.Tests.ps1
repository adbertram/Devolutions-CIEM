BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Get-CIEMConfig' {

    Context 'when PSU cache has existing config' {

        BeforeAll {
            $cachedConfig = [PSCustomObject]@{
                scan = [PSCustomObject]@{ throttleLimit = 20; continueOnError = $true }
                output = [PSCustomObject]@{ verboseLogging = $false }
                azure = [PSCustomObject]@{ endpoints = [PSCustomObject]@{ graphApi = 'https://graph.microsoft.com/v1.0' } }
                pam = [PSCustomObject]@{ enabled = $false }
            }
            # Mock ReadPSUCache to return cached config
            Mock -ModuleName Devolutions.CIEM ReadPSUCache { $cachedConfig }
            # Mock Get-Command so the function takes the PSU path
            Mock -ModuleName Devolutions.CIEM Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' }
            # Mock Set-PSUCache in case backfill triggers
            Mock -ModuleName Devolutions.CIEM Set-PSUCache {}
        }

        It 'returns the cached config' {
            $result = Get-CIEMConfig
            $result.scan.throttleLimit | Should -Be 20
        }
    }

    Context 'when PSU cache key is empty (first run)' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM ReadPSUCache { $null }
            Mock -ModuleName Devolutions.CIEM Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' }
            Mock -ModuleName Devolutions.CIEM Set-PSUCache {}
        }

        It 'returns default config and initializes cache' {
            $result = Get-CIEMConfig
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Set-PSUCache -ModuleName Devolutions.CIEM -Times 1 -Exactly
        }

        It 'disables continueOnError in the default scan config' {
            $result = Get-CIEMConfig
            $result.scan.continueOnError | Should -BeFalse
        }
    }

    Context 'when PSU cache infrastructure fails' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM ReadPSUCache { throw 'Connection refused: PSU server unavailable' }
            Mock -ModuleName Devolutions.CIEM Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' }
        }

        It 'throws the infrastructure error' {
            { Get-CIEMConfig } | Should -Throw '*Connection refused*'
        }
    }

    Context 'when not in PSU context (Get-PSUCache command absent)' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-Command { $null } -ParameterFilter { $Name -eq 'Get-PSUCache' }
        }

        It 'throws requiring PSU cache access' {
            { Get-CIEMConfig } | Should -Throw -ExpectedMessage '*Get-PSUCache*'
        }
    }
}
