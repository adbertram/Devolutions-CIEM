BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    # Create isolated test DB with base + azure + discovery + graph schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Discovery' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    $graphSchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'graph_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $graphSchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Graph Node CRUD' {

    Context 'Get-CIEMGraphNode' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
            # Seed 4 test nodes
            Save-CIEMGraphNode -Id '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/get-vm1' -Kind 'AzureVM' -DisplayName 'get-vm1' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
            Save-CIEMGraphNode -Id '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/get-nsg1' -Kind 'AzureNSG' -DisplayName 'get-nsg1' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
            Save-CIEMGraphNode -Id '/subscriptions/sub2/resourceGroups/rg2/providers/Microsoft.Compute/virtualMachines/get-vm2' -Kind 'AzureVM' -DisplayName 'get-vm2' -Provider 'azure' -SubscriptionId 'sub2' -ResourceGroup 'rg2'
            Save-CIEMGraphNode -Id 'user-guid-1234' -Kind 'EntraUser' -DisplayName 'Test User'
        }

        It 'Returns all nodes when no filter' {
            $results = Get-CIEMGraphNode
            $results | Should -HaveCount 4
        }

        It 'Returns CIEMGraphNode typed objects (.GetType().Name -eq CIEMGraphNode)' {
            $results = Get-CIEMGraphNode
            $results | ForEach-Object { $_.GetType().Name | Should -Be 'CIEMGraphNode' }
        }

        It 'Filters by -Id' {
            $result = Get-CIEMGraphNode -Id 'user-guid-1234'
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be 'Test User'
        }

        It 'Filters by -Kind' {
            $results = Get-CIEMGraphNode -Kind 'AzureVM'
            $results | Should -HaveCount 2
        }

        It 'Filters by -Provider' {
            $results = Get-CIEMGraphNode -Provider 'azure'
            $results | Should -HaveCount 4
        }

        It 'Filters by -SubscriptionId' {
            $results = Get-CIEMGraphNode -SubscriptionId 'sub2'
            $results | Should -HaveCount 1
            $results[0].DisplayName | Should -Be 'get-vm2'
        }

        It 'Filters by -DisplayName' {
            $result = Get-CIEMGraphNode -DisplayName 'get-nsg1'
            $result | Should -Not -BeNullOrEmpty
            $result.Kind | Should -Be 'AzureNSG'
        }

        It 'Returns empty array when no match' {
            $results = Get-CIEMGraphNode -Id '/nonexistent'
            $results | Should -BeNullOrEmpty
        }
    }

    Context 'Save-CIEMGraphNode' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
        }

        It 'Inserts a new node (upsert)' {
            Save-CIEMGraphNode -Id '/subscriptions/sub1/rg/vm-save-new' -Kind 'AzureVM' -DisplayName 'vm-save-new'
            $result = Get-CIEMGraphNode -Id '/subscriptions/sub1/rg/vm-save-new'
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be 'vm-save-new'
        }

        It 'Updates existing node with same Id (upsert)' {
            Save-CIEMGraphNode -Id '/subscriptions/sub1/rg/vm-save-up' -Kind 'AzureVM' -DisplayName 'vm-original'
            Save-CIEMGraphNode -Id '/subscriptions/sub1/rg/vm-save-up' -Kind 'AzureVM' -DisplayName 'vm-updated'
            $result = Get-CIEMGraphNode -Id '/subscriptions/sub1/rg/vm-save-up'
            $result.DisplayName | Should -Be 'vm-updated'
            # Only 1 row, not 2
            $all = Get-CIEMGraphNode
            $all | Should -HaveCount 1
        }

        It 'Accepts -InputObject via pipeline' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMGraphNode]::new()
                $o.Id = '/subscriptions/sub1/rg/vm-pipe'
                $o.Kind = 'AzureVM'
                $o.DisplayName = 'vm-pipe'
                $o.CollectedAt = (Get-Date).ToString('o')
                $o
            }
            $obj | Save-CIEMGraphNode
            $result = Get-CIEMGraphNode -Id '/subscriptions/sub1/rg/vm-pipe'
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be 'vm-pipe'
        }
    }

    Context 'Remove-CIEMGraphNode' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
            Save-CIEMGraphNode -Id '/subscriptions/sub1/rg/vm-rm1' -Kind 'AzureVM' -DisplayName 'vm-rm1' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub1/rg/vm-rm2' -Kind 'AzureVM' -DisplayName 'vm-rm2' -Provider 'azure'
            Save-CIEMGraphNode -Id 'user-guid-rm1' -Kind 'EntraUser' -DisplayName 'user-rm1' -Provider 'azure'
        }

        It 'Removes by -Id' {
            Remove-CIEMGraphNode -Id '/subscriptions/sub1/rg/vm-rm1' -Confirm:$false
            $result = Get-CIEMGraphNode -Id '/subscriptions/sub1/rg/vm-rm1'
            $result | Should -BeNullOrEmpty
            # Other nodes still exist
            Get-CIEMGraphNode | Should -HaveCount 2
        }

        It 'Removes all by -Kind (bulk delete)' {
            Remove-CIEMGraphNode -Kind 'AzureVM' -Confirm:$false
            $vms = Get-CIEMGraphNode -Kind 'AzureVM'
            $vms | Should -BeNullOrEmpty
            # EntraUser still exists
            $users = Get-CIEMGraphNode -Kind 'EntraUser'
            $users | Should -HaveCount 1
        }

        It 'Removes all by -Provider (bulk delete)' {
            Remove-CIEMGraphNode -Provider 'azure' -Confirm:$false
            $results = Get-CIEMGraphNode -Provider 'azure'
            $results | Should -BeNullOrEmpty
        }

        It 'Removes all records with -All switch' {
            Remove-CIEMGraphNode -All -Confirm:$false
            $results = Get-CIEMGraphNode
            $results | Should -BeNullOrEmpty
        }

        It 'Removes via -InputObject' {
            $obj = Get-CIEMGraphNode -Id 'user-guid-rm1'
            Remove-CIEMGraphNode -InputObject $obj -Confirm:$false
            $result = Get-CIEMGraphNode -Id 'user-guid-rm1'
            $result | Should -BeNullOrEmpty
        }

        It 'No-ops when Id does not exist' {
            { Remove-CIEMGraphNode -Id '/nonexistent' -Confirm:$false } | Should -Not -Throw
        }
    }
}
