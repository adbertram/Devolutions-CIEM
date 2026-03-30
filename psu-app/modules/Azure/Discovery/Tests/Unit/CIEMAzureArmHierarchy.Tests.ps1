BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Get-CIEMAzureArmHierarchy' {

    Context 'No data' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
        }

        It 'Throws terminating error when no ARM resources in DB' {
            { Get-CIEMAzureArmHierarchy } | Should -Throw
        }
    }

    Context 'Full tree — 2 subscriptions, 3 resource groups, 5 resources' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
            # Sub1 / RG-A: 2 VMs
            Save-CIEMAzureArmResource -Id '/subscriptions/sub1/resourceGroups/rg-a/providers/Microsoft.Compute/virtualMachines/vm1' `
                -Type 'microsoft.compute/virtualmachines' -Name 'vm1' -ResourceGroup 'rg-a' -SubscriptionId 'sub1' -TenantId 'tenant1'
            Save-CIEMAzureArmResource -Id '/subscriptions/sub1/resourceGroups/rg-a/providers/Microsoft.Compute/virtualMachines/vm2' `
                -Type 'microsoft.compute/virtualmachines' -Name 'vm2' -ResourceGroup 'rg-a' -SubscriptionId 'sub1' -TenantId 'tenant1'
            # Sub1 / RG-B: 1 NSG
            Save-CIEMAzureArmResource -Id '/subscriptions/sub1/resourceGroups/rg-b/providers/Microsoft.Network/networkSecurityGroups/nsg1' `
                -Type 'microsoft.network/networksecuritygroups' -Name 'nsg1' -ResourceGroup 'rg-b' -SubscriptionId 'sub1' -TenantId 'tenant1'
            # Sub2 / RG-C: 2 storage accounts
            Save-CIEMAzureArmResource -Id '/subscriptions/sub2/resourceGroups/rg-c/providers/Microsoft.Storage/storageAccounts/sa1' `
                -Type 'microsoft.storage/storageaccounts' -Name 'sa1' -ResourceGroup 'rg-c' -SubscriptionId 'sub2' -TenantId 'tenant1'
            Save-CIEMAzureArmResource -Id '/subscriptions/sub2/resourceGroups/rg-c/providers/Microsoft.Storage/storageAccounts/sa2' `
                -Type 'microsoft.storage/storageaccounts' -Name 'sa2' -ResourceGroup 'rg-c' -SubscriptionId 'sub2' -TenantId 'tenant1'
        }

        It 'Returns PSCustomObject array' {
            $result = Get-CIEMAzureArmHierarchy
            $result | Should -Not -BeNullOrEmpty
            $result[0] | Should -BeOfType [PSCustomObject]
        }

        It 'Contains exactly one Tenant node at Depth 0' {
            $result = Get-CIEMAzureArmHierarchy
            $tenants = $result | Where-Object { $_.NodeType -eq 'Tenant' }
            $tenants | Should -HaveCount 1
            $tenants[0].Depth | Should -Be 0
        }

        It 'Contains exactly 2 Subscription nodes at Depth 1' {
            $result = Get-CIEMAzureArmHierarchy
            $subs = $result | Where-Object { $_.NodeType -eq 'Subscription' }
            $subs | Should -HaveCount 2
            $subs | ForEach-Object { $_.Depth | Should -Be 1 }
        }

        It 'Contains exactly 3 ResourceGroup nodes at Depth 3' {
            $result = Get-CIEMAzureArmHierarchy
            $rgs = $result | Where-Object { $_.NodeType -eq 'ResourceGroup' }
            $rgs | Should -HaveCount 3
            $rgs | ForEach-Object { $_.Depth | Should -Be 3 }
        }

        It 'Contains exactly 5 Resource nodes at Depth 5' {
            $result = Get-CIEMAzureArmHierarchy
            $resources = $result | Where-Object { $_.NodeType -eq 'Resource' }
            $resources | Should -HaveCount 5
            $resources | ForEach-Object { $_.Depth | Should -Be 5 }
        }

        It 'Populates .Resource on leaf nodes with CIEMAzureArmResource objects' {
            $result = Get-CIEMAzureArmHierarchy
            $leafNodes = $result | Where-Object { $_.NodeType -eq 'Resource' }
            foreach ($node in $leafNodes) {
                $node.Resource | Should -Not -BeNullOrEmpty
                $node.Resource.GetType().Name | Should -Be 'CIEMAzureArmResource'
            }
        }

        It 'Resource property is null on non-leaf nodes (Tenant, Subscription, ResourceGroup)' {
            $result = Get-CIEMAzureArmHierarchy
            $nonLeaf = $result | Where-Object { $_.NodeType -ne 'Resource' }
            foreach ($node in $nonLeaf) {
                $node.Resource | Should -BeNullOrEmpty
            }
        }

        It 'All non-root nodes have Relationship = CONTAINS' {
            $result = Get-CIEMAzureArmHierarchy
            $nonRoot = $result | Where-Object { $_.NodeType -ne 'Tenant' }
            foreach ($node in $nonRoot) {
                $node.Relationship | Should -Be 'CONTAINS'
            }
        }

        It 'Root Tenant node has null Relationship' {
            $result = Get-CIEMAzureArmHierarchy
            $tenant = $result | Where-Object { $_.NodeType -eq 'Tenant' }
            $tenant.Relationship | Should -BeNullOrEmpty
        }

        It 'Each node has a non-empty Label' {
            $result = Get-CIEMAzureArmHierarchy
            foreach ($node in $result) {
                $node.Label | Should -Not -BeNullOrEmpty
            }
        }

        It 'No duplicate NodeIds' {
            $result = Get-CIEMAzureArmHierarchy
            $ids = $result | Select-Object -ExpandProperty NodeId
            ($ids | Select-Object -Unique).Count | Should -Be $ids.Count
        }

        It 'Each non-root node has a non-empty ParentNodeId' {
            $result = Get-CIEMAzureArmHierarchy
            $nonRoot = $result | Where-Object { $_.NodeType -ne 'Tenant' }
            foreach ($node in $nonRoot) {
                $node.ParentNodeId | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context '-SubscriptionId filter' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
            Save-CIEMAzureArmResource -Id '/subscriptions/subA/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1' `
                -Type 'microsoft.compute/virtualmachines' -Name 'vm1' -ResourceGroup 'rg1' -SubscriptionId 'subA' -TenantId 'tenant1'
            Save-CIEMAzureArmResource -Id '/subscriptions/subB/resourceGroups/rg2/providers/Microsoft.Compute/virtualMachines/vm2' `
                -Type 'microsoft.compute/virtualmachines' -Name 'vm2' -ResourceGroup 'rg2' -SubscriptionId 'subB' -TenantId 'tenant1'
        }

        It 'Scopes tree to one subscription when -SubscriptionId is specified' {
            $result = Get-CIEMAzureArmHierarchy -SubscriptionId 'subA'
            $subs = $result | Where-Object { $_.NodeType -eq 'Subscription' }
            $subs | Should -HaveCount 1
            $subs[0].Label | Should -Be 'subA'
        }

        It 'Only returns resource nodes belonging to the specified subscription' {
            $result = Get-CIEMAzureArmHierarchy -SubscriptionId 'subA'
            $resources = $result | Where-Object { $_.NodeType -eq 'Resource' }
            $resources | Should -HaveCount 1
            $resources[0].Resource.Name | Should -Be 'vm1'
        }
    }
}
