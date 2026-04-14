Describe 'GetCIEMAzureProviderApi' {
    BeforeAll {
        Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

        # Redirect DB to $TestDrive for isolation
        New-CIEMDatabase -Path "$TestDrive/ciem.db"
        $azureSchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'azure_schema.sql'
        Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)
        InModuleScope Devolutions.CIEM {
            $script:DatabasePath = "$TestDrive/ciem.db"
        }
    }

    Context 'when querying all provider APIs' {
        BeforeAll {
            $script:allApis = InModuleScope Devolutions.CIEM {
                GetCIEMAzureProviderApi
            }
        }

        It 'returns at least the seeded base and scoped endpoint rows' {
            $script:allApis.Count | Should -BeGreaterOrEqual 16
        }

        It 'returns CIEMAzureProviderApi objects' {
            $script:allApis[0].GetType().Name | Should -Be 'CIEMAzureProviderApi'
        }
    }

    Context 'when filtering by -HasPermissions' {
        BeforeAll {
            $script:withPerms = InModuleScope Devolutions.CIEM {
                GetCIEMAzureProviderApi -HasPermissions
            }
        }

        It 'returns only endpoints that have permissions defined' {
            $script:withPerms | Should -HaveCount 13
        }

        It 'excludes base API rows that have no permissions' {
            $baseRows = $script:withPerms | Where-Object { $_.Name -in 'ARM', 'Graph', 'KeyVault', 'GraphBeta' }
            $baseRows | Should -HaveCount 0
        }

        It 'returns objects with non-null Permissions hashtable' {
            foreach ($ep in $script:withPerms) {
                $ep.Permissions | Should -Not -BeNullOrEmpty
            }
        }

        It 'includes Graph endpoints with Graph permission key' {
            $graphEndpoints = $script:withPerms | Where-Object { $_.Permissions.ContainsKey('Graph') }
            $graphEndpoints.Count | Should -BeGreaterOrEqual 11
        }

        It 'includes ARM endpoints with AzureRoles permission key' {
            $armEndpoints = $script:withPerms | Where-Object { $_.Permissions.ContainsKey('AzureRoles') }
            $armEndpoints.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context 'when aggregating discovery permissions into unique sets' {
        BeforeAll {
            InModuleScope Devolutions.CIEM {
                $endpoints = @(GetCIEMAzureProviderApi -HasPermissions)
                $script:graphPerms = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                $script:azureRoles = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                foreach ($ep in $endpoints) {
                    if ($ep.Permissions.Graph) { foreach ($p in $ep.Permissions.Graph) { $null = $script:graphPerms.Add($p) } }
                    if ($ep.Permissions.AzureRoles) { foreach ($r in $ep.Permissions.AzureRoles) { $null = $script:azureRoles.Add($r) } }
                }
            }
        }

        It 'aggregates Graph permissions to exactly 2 unique values' {
            InModuleScope Devolutions.CIEM {
                $script:graphPerms | Should -HaveCount 2
            }
        }

        It 'includes AuditLog.Read.All in Graph permissions' {
            InModuleScope Devolutions.CIEM {
                $script:graphPerms | Should -Contain 'AuditLog.Read.All'
            }
        }

        It 'includes Directory.Read.All in Graph permissions' {
            InModuleScope Devolutions.CIEM {
                $script:graphPerms | Should -Contain 'Directory.Read.All'
            }
        }

        It 'aggregates Azure RBAC roles to exactly 1 unique value' {
            InModuleScope Devolutions.CIEM {
                $script:azureRoles | Should -HaveCount 1
            }
        }

        It 'includes Reader in Azure RBAC roles' {
            InModuleScope Devolutions.CIEM {
                $script:azureRoles | Should -Contain 'Reader'
            }
        }
    }

    Context 'when filtering by -Name' {
        BeforeAll {
            $script:result = InModuleScope Devolutions.CIEM {
                GetCIEMAzureProviderApi -Name 'Graph/users'
            }
        }

        It 'returns the matching endpoint' {
            $script:result | Should -HaveCount 1
        }

        It 'returns the endpoint with correct Name' {
            $script:result[0].Name | Should -Be 'Graph/users'
        }

        It 'returns the endpoint with correct Service' {
            $script:result[0].Service | Should -Be 'Entra'
        }
    }

    Context 'when filtering by -Service' {
        BeforeAll {
            $script:result = InModuleScope Devolutions.CIEM {
                GetCIEMAzureProviderApi -Service 'IAM'
            }
        }

        It 'returns only IAM service endpoints' {
            $script:result | Should -Not -BeNullOrEmpty
            foreach ($ep in $script:result) {
                $ep.Service | Should -Be 'IAM'
            }
        }
    }

    Context 'when filtering by non-existent name' {
        BeforeAll {
            $script:result = InModuleScope Devolutions.CIEM {
                GetCIEMAzureProviderApi -Name 'DoesNotExist'
            }
        }

        It 'returns empty array' {
            $script:result | Should -HaveCount 0
        }
    }
}
