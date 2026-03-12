BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    # Create isolated test DB with base + azure + discovery schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'
    if (Test-Path $azureSchema) {
        Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)
    }

    $discoverySchema = Join-Path $PSScriptRoot '..' 'Data' 'discovery_schema.sql'
    if (Test-Path $discoverySchema) {
        Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)
    }

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Resource Type' {

    Context 'Get-CIEMAzureResourceType (Public)' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_resource_types"
            # Seed test data directly via SQL (private CRUD may not exist yet)
            $now = (Get-Date).ToString('o')
            Invoke-CIEMQuery -Query "INSERT INTO azure_resource_types (type, api_source, graph_table, resource_count, discovered_at) VALUES ('microsoft.compute/virtualmachines', 'ARM', 'resources', 150, '$now')"
            Invoke-CIEMQuery -Query "INSERT INTO azure_resource_types (type, api_source, graph_table, resource_count, discovered_at) VALUES ('microsoft.network/networksecuritygroups', 'ARM', 'resources', 30, '$now')"
            Invoke-CIEMQuery -Query "INSERT INTO azure_resource_types (type, api_source, graph_table, resource_count, discovered_at) VALUES ('User', 'Graph', NULL, 500, '$now')"
        }

        It 'Returns all resource types when no filter' {
            $results = Get-CIEMAzureResourceType
            $results.Count | Should -Be 3
        }

        It 'Returns CIEMAzureResourceType typed objects (.GetType().Name -eq CIEMAzureResourceType)' {
            $results = Get-CIEMAzureResourceType
            $results | ForEach-Object { $_.GetType().Name | Should -Be 'CIEMAzureResourceType' }
        }

        It 'Filters by -Type' {
            $result = Get-CIEMAzureResourceType -Type 'microsoft.compute/virtualmachines'
            $result | Should -Not -BeNullOrEmpty
            $result.ResourceCount | Should -Be 150
        }

        It 'Filters by -ApiSource' {
            $results = Get-CIEMAzureResourceType -ApiSource 'ARM'
            $results.Count | Should -Be 2
        }

        It 'Returns empty array when no match' {
            $results = Get-CIEMAzureResourceType -Type 'nonexistent.type'
            $results | Should -BeNullOrEmpty
        }
    }

    Context 'Private CRUD functions exist and work' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_resource_types"
        }

        It 'NewCIEMAzureResourceType creates a resource type and returns object with generated values' {
            $result = InModuleScope Devolutions.CIEM {
                NewCIEMAzureResourceType -Type 'microsoft.storage/storageaccounts' -ApiSource 'ARM' -ResourceCount 25
            }
            $result | Should -Not -BeNullOrEmpty
            $result.Type | Should -Be 'microsoft.storage/storageaccounts'
            $result.DiscoveredAt | Should -Not -BeNullOrEmpty
        }

        It 'UpdateCIEMAzureResourceType updates ResourceCount on existing type' {
            InModuleScope Devolutions.CIEM {
                NewCIEMAzureResourceType -Type 'microsoft.web/sites' -ApiSource 'ARM' -ResourceCount 10
                UpdateCIEMAzureResourceType -Type 'microsoft.web/sites' -ResourceCount 50
            }
            $result = Get-CIEMAzureResourceType -Type 'microsoft.web/sites'
            $result.ResourceCount | Should -Be 50
        }

        It 'SaveCIEMAzureResourceType upserts a resource type' {
            InModuleScope Devolutions.CIEM {
                SaveCIEMAzureResourceType -Type 'Group' -ApiSource 'Graph' -ResourceCount 100
                SaveCIEMAzureResourceType -Type 'Group' -ApiSource 'Graph' -ResourceCount 200
            }
            $result = Get-CIEMAzureResourceType -Type 'Group'
            $result.ResourceCount | Should -Be 200
            # Only 1 row
            $all = Get-CIEMAzureResourceType
            $all.Count | Should -Be 1
        }

        It 'RemoveCIEMAzureResourceType removes by -Type' {
            InModuleScope Devolutions.CIEM {
                NewCIEMAzureResourceType -Type 'ServicePrincipal' -ApiSource 'Graph' -ResourceCount 75
                RemoveCIEMAzureResourceType -Type 'ServicePrincipal'
            }
            $result = Get-CIEMAzureResourceType -Type 'ServicePrincipal'
            $result | Should -BeNullOrEmpty
        }
    }
}
