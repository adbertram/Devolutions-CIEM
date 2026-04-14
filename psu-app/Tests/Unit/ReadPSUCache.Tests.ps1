BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'ReadPSUCache' {

    Context 'when Get-PSUCache command does not exist (not in PSU context)' {

        BeforeAll {
            InModuleScope Devolutions.CIEM {
                Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Get-PSUCache' }
                $script:testResult = ReadPSUCache -Key 'CIEM:TestKey'
            }
        }

        It 'returns $null' {
            InModuleScope Devolutions.CIEM {
                $script:testResult | Should -BeNullOrEmpty
            }
        }
    }

    Context 'when cache key exists and has a value' {

        BeforeAll {
            InModuleScope Devolutions.CIEM {
                Mock Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' }
                Mock Get-PSUCache { @{ Setting1 = 'Value1' } }
                $script:testResult = ReadPSUCache -Key 'CIEM:TestKey'
            }
        }

        It 'returns the cached value' {
            InModuleScope Devolutions.CIEM {
                $script:testResult | Should -Not -BeNullOrEmpty
                $script:testResult.Setting1 | Should -Be 'Value1'
            }
        }
    }

    Context 'when cache key does not exist (null-valued expression error)' {

        BeforeAll {
            InModuleScope Devolutions.CIEM {
                Mock Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' }
                Mock Get-PSUCache { throw 'You cannot call a method on a null-valued expression.' }
                $script:testResult = ReadPSUCache -Key 'CIEM:MissingKey'
            }
        }

        It 'returns $null for missing key' {
            InModuleScope Devolutions.CIEM {
                $script:testResult | Should -BeNullOrEmpty
            }
        }
    }

    Context 'when cache infrastructure fails (non-key-missing error)' {

        BeforeAll {
            InModuleScope Devolutions.CIEM {
                Mock Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' }
                Mock Get-PSUCache { throw 'Connection refused: PSU server unavailable' }
            }
        }

        It 'throws the infrastructure error' {
            InModuleScope Devolutions.CIEM {
                { ReadPSUCache -Key 'CIEM:TestKey' } | Should -Throw '*Connection refused*'
            }
        }
    }
}
