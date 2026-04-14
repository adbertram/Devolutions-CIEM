BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    # Create isolated test DB
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Connect-CIEM' {

    Context 'when provider connector succeeds' {

        BeforeAll {
            InModuleScope Devolutions.CIEM {
                $script:AuthContext = @{}
            }
            Mock -ModuleName Devolutions.CIEM Get-CIEMProvider { [PSCustomObject]@{ Name = 'Azure'; Enabled = $true } }
            # Mock Connect-CIEMAzure directly — Get-Command will find the mock function
            Mock -ModuleName Devolutions.CIEM Connect-CIEMAzure {
                [PSCustomObject]@{
                    AccountId       = 'test-client-id'
                    AccountType     = 'ServicePrincipal'
                    TenantId        = 'test-tenant'
                    SubscriptionIds = @('sub-1')
                }
            }
        }

        It 'returns Connected status' {
            $result = Connect-CIEM -Provider Azure
            $result.Providers[0].Status | Should -Be 'Connected'
            $result.Providers[0].Account | Should -Be 'test-client-id'
        }
    }

    Context 'when provider connector throws' {

        BeforeAll {
            InModuleScope Devolutions.CIEM {
                $script:AuthContext = @{}
            }
            Mock -ModuleName Devolutions.CIEM Get-CIEMProvider { [PSCustomObject]@{ Name = 'Azure'; Enabled = $true } }
            Mock -ModuleName Devolutions.CIEM Connect-CIEMAzure { throw 'Authentication failed: invalid client secret' }
        }

        It 'throws the connector error' {
            { Connect-CIEM -Provider Azure } | Should -Throw '*Authentication failed*'
        }
    }

    Context 'when already connected without -Force' {

        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-CIEMProvider { [PSCustomObject]@{ Name = 'Azure'; Enabled = $true } }
            InModuleScope Devolutions.CIEM {
                $script:AuthContext = @{
                    'Azure' = [PSCustomObject]@{
                        AccountId       = 'existing-id'
                        TenantId        = 'existing-tenant'
                        SubscriptionIds = @('sub-1')
                    }
                }
            }
        }

        It 'returns AlreadyConnected without re-authenticating' {
            $result = Connect-CIEM -Provider Azure
            $result.Providers[0].Status | Should -Be 'AlreadyConnected'
        }
    }
}
