BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'CIEM Azure authentication profile cache operations' {

    Context 'when PSU cache is unavailable' {
        BeforeAll {
            InModuleScope Devolutions.CIEM {
                Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Get-PSUCache' }
            }
        }

        It 'throws when reading profiles' {
            InModuleScope Devolutions.CIEM {
                { Get-CIEMAzureAuthenticationProfile } | Should -Throw '*Cannot access PSU Cache*'
            }
        }

        It 'throws when saving a profile' {
            InModuleScope Devolutions.CIEM {
                {
                    Save-CIEMAzureAuthenticationProfile `
                        -Id 'profile-unavailable' `
                        -ProviderId 'Azure' `
                        -Name 'Unavailable Cache' `
                        -Method 'ManagedIdentity' `
                        -TenantId 'tenant-unavailable'
                } | Should -Throw '*Cannot access PSU Cache*'
            }
        }

        It 'throws when removing a profile' {
            InModuleScope Devolutions.CIEM {
                { Remove-CIEMAzureAuthenticationProfile -Id 'profile-unavailable' -Confirm:$false } |
                    Should -Throw '*Cannot access PSU Cache*'
            }
        }
    }

    Context 'when PSU cache read fails' {
        BeforeAll {
            InModuleScope Devolutions.CIEM {
                Mock Get-Command { [PSCustomObject]@{ Name = 'Get-PSUCache' } } -ParameterFilter { $Name -eq 'Get-PSUCache' }
                Mock Get-PSUCache { throw 'PSU cache read failed' }
            }
        }

        It 'throws the cache read error while reading profiles' {
            InModuleScope Devolutions.CIEM {
                { Get-CIEMAzureAuthenticationProfile } | Should -Throw '*PSU cache read failed*'
            }
        }

        It 'throws the cache read error while saving a profile' {
            InModuleScope Devolutions.CIEM {
                {
                    Save-CIEMAzureAuthenticationProfile `
                        -Id 'profile-read-fails' `
                        -ProviderId 'Azure' `
                        -Name 'Read Fails' `
                        -Method 'ManagedIdentity' `
                        -TenantId 'tenant-read-fails'
                } | Should -Throw '*PSU cache read failed*'
            }
        }
    }
}
