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

Describe 'ARM Resource CRUD' {

    Context 'New-CIEMAzureArmResource' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
        }

        It 'Creates a resource and returns CIEMAzureArmResource object' {
            $result = New-CIEMAzureArmResource -Id '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1' `
                -Type 'microsoft.compute/virtualmachines' `
                -Name 'vm1' `
                -Location 'eastus' `
                -ResourceGroup 'rg1' `
                -SubscriptionId 'sub1' `
                -TenantId 'tenant1'
            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'CIEMAzureArmResource'
            $result.Id | Should -Be '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1'
            $result.Name | Should -Be 'vm1'
        }

        It 'Throws when resource with same Id already exists' {
            New-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-dup' -Type 'microsoft.compute/virtualmachines' -Name 'vm-dup'
            { New-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-dup' -Type 'microsoft.compute/virtualmachines' -Name 'vm-dup' } | Should -Throw
        }

        It 'Accepts -InputObject parameter set' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureArmResource]::new()
                $o.Id = '/subscriptions/sub1/rg/vm-input'
                $o.Type = 'microsoft.compute/virtualmachines'
                $o.Name = 'vm-input'
                $o
            }
            $result = New-CIEMAzureArmResource -InputObject $obj
            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be '/subscriptions/sub1/rg/vm-input'
        }

        It 'Sets CollectedAt to current time when not provided' {
            $before = (Get-Date).ToString('o')
            $result = New-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-time' -Type 'microsoft.compute/virtualmachines' -Name 'vm-time'
            $result.CollectedAt | Should -Not -BeNullOrEmpty
            $result.CollectedAt | Should -BeGreaterOrEqual $before
        }
    }

    Context 'Get-CIEMAzureArmResource' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
            # Seed 3 test resources
            New-CIEMAzureArmResource -Id '/subscriptions/sub1/rg1/vm/get1' -Type 'microsoft.compute/virtualmachines' -Name 'get-vm1' -Location 'eastus' -ResourceGroup 'rg1' -SubscriptionId 'sub1'
            New-CIEMAzureArmResource -Id '/subscriptions/sub1/rg1/nsg/get2' -Type 'microsoft.network/networksecuritygroups' -Name 'get-nsg1' -Location 'westus' -ResourceGroup 'rg1' -SubscriptionId 'sub1'
            New-CIEMAzureArmResource -Id '/subscriptions/sub2/rg2/vm/get3' -Type 'microsoft.compute/virtualmachines' -Name 'get-vm2' -Location 'eastus' -ResourceGroup 'rg2' -SubscriptionId 'sub2'
        }

        It 'Returns all resources when no filter' {
            $results = Get-CIEMAzureArmResource
            $results.Count | Should -Be 3
        }

        It 'Returns CIEMAzureArmResource typed objects (.GetType().Name -eq CIEMAzureArmResource)' {
            $results = Get-CIEMAzureArmResource
            $results | ForEach-Object { $_.GetType().Name | Should -Be 'CIEMAzureArmResource' }
        }

        It 'Filters by -Id' {
            $result = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg1/vm/get1'
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'get-vm1'
        }

        It 'Filters by -Type' {
            $results = Get-CIEMAzureArmResource -Type 'microsoft.compute/virtualmachines'
            $results.Count | Should -Be 2
        }

        It 'Filters by -Name' {
            $result = Get-CIEMAzureArmResource -Name 'get-nsg1'
            $result | Should -Not -BeNullOrEmpty
            $result.Type | Should -Be 'microsoft.network/networksecuritygroups'
        }

        It 'Filters by -SubscriptionId' {
            $results = Get-CIEMAzureArmResource -SubscriptionId 'sub2'
            $results.Count | Should -Be 1
            $results[0].Name | Should -Be 'get-vm2'
        }

        It 'Filters by -ResourceGroup' {
            $results = Get-CIEMAzureArmResource -ResourceGroup 'rg1'
            $results.Count | Should -Be 2
        }

        It 'Returns empty array when no match' {
            $results = Get-CIEMAzureArmResource -Id '/nonexistent'
            $results | Should -BeNullOrEmpty
        }
    }

    Context 'Update-CIEMAzureArmResource' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
            New-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-upd' -Type 'microsoft.compute/virtualmachines' -Name 'vm-update' -Location 'eastus' -Properties '{"vmSize":"Standard_B1s"}'
        }

        It 'Updates Properties field via -Properties parameter' {
            Update-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-upd' -Properties '{"vmSize":"Standard_D2s_v3"}'
            $result = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-upd'
            $result.Properties | Should -Be '{"vmSize":"Standard_D2s_v3"}'
        }

        It 'Does not overwrite unspecified fields (partial update)' {
            Update-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-upd' -Properties '{"updated":true}'
            $result = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-upd'
            $result.Location | Should -Be 'eastus'
            $result.Name | Should -Be 'vm-update'
        }

        It 'Returns nothing without -PassThru' {
            $result = Update-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-upd' -Properties '{"x":1}'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns updated object with -PassThru' {
            $result = Update-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-upd' -Properties '{"passthru":true}' -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'CIEMAzureArmResource'
            $result.Properties | Should -Be '{"passthru":true}'
        }

        It 'Accepts -InputObject for full object update' {
            $obj = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-upd'
            $obj.Location = 'westus2'
            $obj.Tags = '{"env":"test"}'
            Update-CIEMAzureArmResource -InputObject $obj
            $result = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-upd'
            $result.Location | Should -Be 'westus2'
            $result.Tags | Should -Be '{"env":"test"}'
        }
    }

    Context 'Save-CIEMAzureArmResource' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
        }

        It 'Inserts a new resource (upsert)' {
            Save-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-save-new' -Type 'microsoft.compute/virtualmachines' -Name 'vm-save-new'
            $result = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-save-new'
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'vm-save-new'
        }

        It 'Updates existing resource with same Id (upsert)' {
            Save-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-save-up' -Type 'microsoft.compute/virtualmachines' -Name 'vm-original'
            Save-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-save-up' -Type 'microsoft.compute/virtualmachines' -Name 'vm-updated'
            $result = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-save-up'
            $result.Name | Should -Be 'vm-updated'
            # Only 1 row, not 2
            $all = Get-CIEMAzureArmResource
            $all.Count | Should -Be 1
        }

        It 'Accepts -InputObject via pipeline' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureArmResource]::new()
                $o.Id = '/subscriptions/sub1/rg/vm-pipe'
                $o.Type = 'microsoft.compute/virtualmachines'
                $o.Name = 'vm-pipe'
                $o.CollectedAt = (Get-Date).ToString('o')
                $o
            }
            $obj | Save-CIEMAzureArmResource
            $result = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-pipe'
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be 'vm-pipe'
        }
    }

    Context 'Remove-CIEMAzureArmResource' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
            New-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-rm1' -Type 'microsoft.compute/virtualmachines' -Name 'vm-rm1'
            New-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-rm2' -Type 'microsoft.compute/virtualmachines' -Name 'vm-rm2'
            New-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/nsg-rm1' -Type 'microsoft.network/networksecuritygroups' -Name 'nsg-rm1'
        }

        It 'Removes by -Id' {
            Remove-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-rm1' -Confirm:$false
            $result = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/vm-rm1'
            $result | Should -BeNullOrEmpty
            # Other resources still exist
            (Get-CIEMAzureArmResource).Count | Should -Be 2
        }

        It 'Removes all by -Type (bulk delete)' {
            Remove-CIEMAzureArmResource -Type 'microsoft.compute/virtualmachines' -Confirm:$false
            $vms = Get-CIEMAzureArmResource -Type 'microsoft.compute/virtualmachines'
            $vms | Should -BeNullOrEmpty
            # NSG still exists
            $nsgs = Get-CIEMAzureArmResource -Type 'microsoft.network/networksecuritygroups'
            $nsgs.Count | Should -Be 1
        }

        It 'Removes all records with -All switch' {
            Remove-CIEMAzureArmResource -All -Confirm:$false
            $results = Get-CIEMAzureArmResource
            $results | Should -BeNullOrEmpty
        }

        It 'Removes via -InputObject' {
            $obj = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/nsg-rm1'
            Remove-CIEMAzureArmResource -InputObject $obj -Confirm:$false
            $result = Get-CIEMAzureArmResource -Id '/subscriptions/sub1/rg/nsg-rm1'
            $result | Should -BeNullOrEmpty
        }

        It 'No-ops when Id does not exist' {
            { Remove-CIEMAzureArmResource -Id '/nonexistent' -Confirm:$false } | Should -Not -Throw
        }
    }
}
