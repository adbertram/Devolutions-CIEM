BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSetup.ps1')
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
}

Describe 'InvokeCIEMResourceGraphQuery' {
    BeforeEach {
        Initialize-DiscoveryTestDatabase
        $script:resourceGraphCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
        Mock -ModuleName Devolutions.CIEM Get-CIEMAzureProviderApi {
            [pscustomobject]@{ BaseUrl = 'https://management.azure.com' }
        }
        Mock -ModuleName Devolutions.CIEM Invoke-AzureApi {
            $script:resourceGraphCalls.Add([pscustomobject]@{
                Method = $Method
                SubscriptionCount = @($Body.subscriptions).Count
                ManagementGroupId = if ($Body.managementGroups) { [string]@($Body.managementGroups)[0] } else { $null }
            })
            @(
                [pscustomobject]@{
                    id = '/subscriptions/sub-1/resourceGroups/rg-1/providers/Microsoft.Compute/virtualMachines/vm-1'
                    type = 'microsoft.compute/virtualmachines'
                    name = 'vm-1'
                    location = 'eastus'
                    resourceGroup = 'rg-1'
                    subscriptionId = 'sub-1'
                    tenantId = 'tenant-1'
                    kind = $null
                    sku = $null
                    identity = $null
                    managedBy = $null
                    plan = $null
                    zones = $null
                    tags = $null
                    properties = [pscustomobject]@{ hardwareProfile = [pscustomobject]@{ vmSize = 'Standard_B2s' } }
                }
            )
        }
    }

    It 'Uses one chunk for exactly 1000 subscriptions' {
        $subscriptions = foreach ($index in 1..1000) { "sub-$index" }

        InModuleScope Devolutions.CIEM -Parameters @{ subscriptions = $subscriptions } {
            @(InvokeCIEMResourceGraphQuery -Query Resources -SubscriptionId $subscriptions)
        }

        $script:resourceGraphCalls | Should -HaveCount 1
        $script:resourceGraphCalls[0].Method | Should -Be 'POST'
        $script:resourceGraphCalls[0].SubscriptionCount | Should -Be 1000
    }

    It 'Splits 1001 subscriptions into two chunks' {
        $subscriptions = foreach ($index in 1..1001) { "sub-$index" }

        $result = InModuleScope Devolutions.CIEM -Parameters @{ subscriptions = $subscriptions } {
            @(InvokeCIEMResourceGraphQuery -Query Resources -SubscriptionId $subscriptions)
        }

        $result | Should -HaveCount 2
        $script:resourceGraphCalls | Should -HaveCount 2
        $script:resourceGraphCalls[0].SubscriptionCount | Should -Be 1000
        $script:resourceGraphCalls[1].SubscriptionCount | Should -Be 1
    }

    It 'Passes managementGroups scope when ManagementGroupId is provided' {
        $result = InModuleScope Devolutions.CIEM {
            @(InvokeCIEMResourceGraphQuery -Query Resources -ManagementGroupId 'mg-1')
        }

        $result | Should -HaveCount 1
        $script:resourceGraphCalls | Should -HaveCount 1
        $script:resourceGraphCalls[0].ManagementGroupId | Should -Be 'mg-1'
    }

    It 'Throws when no subscription IDs are provided' {
        InModuleScope Devolutions.CIEM {
            { InvokeCIEMResourceGraphQuery -Query Resources -SubscriptionId @() } | Should -Throw '*at least one subscription ID*'
        }
    }

    It 'Throws when a chunk fails' {
        Mock -ModuleName Devolutions.CIEM Invoke-AzureApi {
            if (@($Body.subscriptions).Count -eq 1) {
                throw 'chunk failed'
            }

            @(
                [pscustomobject]@{
                    id = '/subscriptions/sub-1/resourceGroups/rg-1/providers/Microsoft.Compute/virtualMachines/vm-1'
                    type = 'microsoft.compute/virtualmachines'
                    name = 'vm-1'
                    location = 'eastus'
                    resourceGroup = 'rg-1'
                    subscriptionId = 'sub-1'
                    tenantId = 'tenant-1'
                }
            )
        }

        $subscriptions = foreach ($index in 1..1001) { "sub-$index" }

        InModuleScope Devolutions.CIEM -Parameters @{ subscriptions = $subscriptions } {
            { InvokeCIEMResourceGraphQuery -Query Resources -SubscriptionId $subscriptions } | Should -Throw '*chunk failed*'
        }
    }
}
