BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Set-CIEMConfig' {

    Context 'when PSU cache has existing config' {

        BeforeAll {
            $cachedConfig = [PSCustomObject]@{
                scan = [PSCustomObject]@{ throttleLimit = 10; continueOnError = $true }
                output = [PSCustomObject]@{ verboseLogging = $false }
            }
            Mock -ModuleName Devolutions.CIEM ReadPSUCache { $cachedConfig }
            Mock -ModuleName Devolutions.CIEM Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' -or $Name -eq 'Set-PSUCache' }
            Mock -ModuleName Devolutions.CIEM Set-PSUCache {}
        }

        It 'applies settings and writes back to cache' {
            Set-CIEMConfig -Settings @{ 'scan.throttleLimit' = 20 }
            Should -Invoke -CommandName Set-PSUCache -ModuleName Devolutions.CIEM -Times 1 -Exactly
        }
    }

    Context 'when PSU cache infrastructure fails on read' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM ReadPSUCache { throw 'Connection refused: PSU server unavailable' }
            Mock -ModuleName Devolutions.CIEM Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' -or $Name -eq 'Set-PSUCache' }
        }

        It 'throws the infrastructure error' {
            { Set-CIEMConfig -Settings @{ 'scan.throttleLimit' = 20 } } | Should -Throw '*Connection refused*'
        }
    }

    Context 'when PSU cache write fails' {

        BeforeAll {
            $cachedConfig = [PSCustomObject]@{
                scan = [PSCustomObject]@{ throttleLimit = 10; continueOnError = $true }
            }
            Mock -ModuleName Devolutions.CIEM ReadPSUCache { $cachedConfig }
            Mock -ModuleName Devolutions.CIEM Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' -or $Name -eq 'Set-PSUCache' }
            Mock -ModuleName Devolutions.CIEM Set-PSUCache { throw 'PSU cache write failed' }
        }

        It 'throws the write error' {
            { Set-CIEMConfig -Settings @{ 'scan.throttleLimit' = 20 } } | Should -Throw '*PSU cache write failed*'
        }
    }

    Context 'when PSU cache commands are absent' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-Command { $null } -ParameterFilter { $Name -eq 'Get-PSUCache' -or $Name -eq 'Set-PSUCache' }
        }

        It 'throws requiring PSU cache access' {
            { Set-CIEMConfig -Settings @{ 'scan.throttleLimit' = 20 } } |
                Should -Throw -ExpectedMessage '*PSU cache*'
        }
    }
}
