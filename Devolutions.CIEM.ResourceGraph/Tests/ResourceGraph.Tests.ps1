#Requires -Modules Pester

BeforeAll {
    Import-Module "$PSScriptRoot/../Devolutions.CIEM.ResourceGraph.psd1" -Force

    # Shared ARM ID helpers
    $script:subId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
    $script:rg = 'test-rg'
    $script:baseId = "/subscriptions/$script:subId/resourceGroups/$script:rg/providers"
}

Describe 'ResourceType class' {
    It 'creates from schema entry with dependency paths' {
        InModuleScope 'Devolutions.CIEM.ResourceGraph' {
            $json = [PSCustomObject]@{
                category        = 'compute'
                displayName     = 'Virtual Machine'
                dependencyPaths = [PSCustomObject]@{
                    networkInterfaces = [PSCustomObject]@{
                        path = 'properties.networkProfile.networkInterfaces[].id'
                    }
                    osDisk = [PSCustomObject]@{
                        path = 'properties.storageProfile.osDisk.managedDisk.id'
                    }
                }
            }
            $rt = [ResourceType]::FromSchemaEntry('Microsoft.Compute/virtualMachines', $json)
            $rt.ArmType | Should -Be 'Microsoft.Compute/virtualMachines'
            $rt.Category | Should -Be 'compute'
            $rt.DisplayName | Should -Be 'Virtual Machine'
            $rt.DependencyPaths.Count | Should -Be 2
            $rt.DependencyPaths['networkInterfaces'].Path | Should -Be 'properties.networkProfile.networkInterfaces[].id'
            $rt.DependencyPaths['osDisk'].Path | Should -Be 'properties.storageProfile.osDisk.managedDisk.id'
        }
    }

    It 'creates from schema entry with empty dependency paths' {
        InModuleScope 'Devolutions.CIEM.ResourceGraph' {
            $json = [PSCustomObject]@{
                category        = 'compute'
                displayName     = 'Host Group'
                dependencyPaths = [PSCustomObject]@{}
            }
            $rt = [ResourceType]::FromSchemaEntry('Microsoft.Compute/hostGroups', $json)
            $rt.ArmType | Should -Be 'Microsoft.Compute/hostGroups'
            $rt.DependencyPaths.Count | Should -Be 0
        }
    }

    It 'round-trips via ToSchemaEntry' {
        InModuleScope 'Devolutions.CIEM.ResourceGraph' {
            $json = [PSCustomObject]@{
                category        = 'network'
                displayName     = 'Network Interface'
                dependencyPaths = [PSCustomObject]@{
                    subnet = [PSCustomObject]@{
                        path = 'properties.ipConfigurations[].properties.subnet.id'
                    }
                }
            }
            $rt = [ResourceType]::FromSchemaEntry('Microsoft.Network/networkInterfaces', $json)
            $entry = $rt.ToSchemaEntry()
            $entry.category | Should -Be 'network'
            $entry.displayName | Should -Be 'Network Interface'
            $entry.dependencyPaths.subnet.path | Should -Be 'properties.ipConfigurations[].properties.subnet.id'
        }
    }
}

Describe 'Read-ResourceTypeSchema' {
    It 'returns a hashtable of ResourceType objects' {
        $schema = InModuleScope 'Devolutions.CIEM.ResourceGraph' { Read-ResourceTypeSchema }
        $schema | Should -BeOfType [hashtable]
        $schema.Count | Should -Be 16
    }

    It 'parses VM entry with correct path count' {
        $schema = InModuleScope 'Devolutions.CIEM.ResourceGraph' { Read-ResourceTypeSchema }
        $vm = $schema['Microsoft.Compute/virtualMachines']
        $vm.GetType().Name | Should -Be 'ResourceType'
        $vm.DependencyPaths.Count | Should -Be 7
        $vm.DependencyPaths['networkInterfaces'].Path | Should -Be 'properties.networkProfile.networkInterfaces[].id'
        $vm.DependencyPaths['osDisk'].Path | Should -Be 'properties.storageProfile.osDisk.managedDisk.id'
    }

    It 'parses leaf entries with no dependency paths' {
        $schema = InModuleScope 'Devolutions.CIEM.ResourceGraph' { Read-ResourceTypeSchema }
        $hg = $schema['Microsoft.Compute/hostGroups']
        $hg.GetType().Name | Should -Be 'ResourceType'
        $hg.DependencyPaths.Count | Should -Be 0
    }
}

Describe 'New-CIEMResourceType' {
    BeforeAll {
        $script:schemaPath = Join-Path $PSScriptRoot '..' 'Schemas' 'azure.resource-types.json'
        $script:schemaBackup = Get-Content -Path $script:schemaPath -Raw
    }

    AfterEach {
        # Restore original schema after each test
        Set-Content -Path $script:schemaPath -Value $script:schemaBackup -Encoding utf8
    }

    It 'adds a leaf resource type with no dependency paths' {
        InModuleScope 'Devolutions.CIEM.ResourceGraph' {
            $result = New-CIEMResourceType -ArmType 'Microsoft.Web/sites' -DisplayName 'App Service' -Category compute
            $result.GetType().Name | Should -Be 'ResourceType'
            $result.ArmType | Should -Be 'Microsoft.Web/sites'
            $result.DependencyPaths.Count | Should -Be 0
        }

        # Verify it's in the schema file
        $schema = Get-Content -Path $script:schemaPath -Raw | ConvertFrom-Json
        $schema.resourceTypes.'Microsoft.Web/sites' | Should -Not -BeNullOrEmpty
        $schema.resourceTypes.'Microsoft.Web/sites'.category | Should -Be 'compute'
    }

    It 'adds a resource type with dependency paths' {
        InModuleScope 'Devolutions.CIEM.ResourceGraph' {
            $paths = @{
                identity = @{ Path = 'identity.userAssignedIdentities' }
            }
            $result = New-CIEMResourceType -ArmType 'Microsoft.Sql/servers' -DisplayName 'SQL Server' -Category database -DependencyPaths $paths
            $result.DependencyPaths.Count | Should -Be 1
            $result.DependencyPaths['identity'].Path | Should -Be 'identity.userAssignedIdentities'
        }
    }

    It 'errors on duplicate ArmType' {
        { New-CIEMResourceType -ArmType 'Microsoft.Compute/virtualMachines' -DisplayName 'Dupe' -Category compute } |
            Should -Throw "*already exists*"
    }

    It 'errors when Path key is missing' {
        $paths = @{
            bad = @{ Foo = 'bar' }
        }
        { New-CIEMResourceType -ArmType 'Microsoft.Test/test' -DisplayName 'Test' -Category compute -DependencyPaths $paths } |
            Should -Throw "*missing*Path*"
    }
}

Describe 'ConvertTo-MermaidDiagram' {
    BeforeAll {
        # Reuse shared ARM ID helpers from top-level BeforeAll
        $script:mVmId     = "$script:baseId/Microsoft.Compute/virtualMachines/vm1"
        $script:mNicId    = "$script:baseId/Microsoft.Network/networkInterfaces/nic1"
        $script:mSubnetId = "$script:baseId/Microsoft.Network/virtualNetworks/vnet1/subnets/subnet1"

        $script:mVm = [PSCustomObject]@{
            id = $script:mVmId; name = 'vm1'; type = 'Microsoft.Compute/virtualMachines'; location = 'westus2'
            identity = $null
            properties = [PSCustomObject]@{
                networkProfile = [PSCustomObject]@{
                    networkInterfaces = @([PSCustomObject]@{ id = $script:mNicId })
                }
                storageProfile = [PSCustomObject]@{ osDisk = $null; dataDisks = @() }
                availabilitySet = $null; proximityPlacementGroup = $null
                virtualMachineScaleSet = $null; hostGroup = $null
            }
        }
        $script:mNic = [PSCustomObject]@{
            id = $script:mNicId; name = 'nic1'; type = 'Microsoft.Network/networkInterfaces'; location = 'westus2'
            properties = [PSCustomObject]@{
                ipConfigurations = @(
                    [PSCustomObject]@{
                        properties = [PSCustomObject]@{
                            subnet          = [PSCustomObject]@{ id = $script:mSubnetId }
                            publicIPAddress = $null
                        }
                    }
                )
                networkSecurityGroup = $null
            }
        }
        $script:mSubnet = [PSCustomObject]@{
            id = $script:mSubnetId; name = 'subnet1'; type = 'Microsoft.Network/virtualNetworks/subnets'; location = 'westus2'
            properties = [PSCustomObject]@{
                addressPrefix = '10.0.0.0/24'
                networkSecurityGroup = $null; routeTable = $null; natGateway = $null
            }
        }

        $script:mGraph = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ vm = $script:mVm; nic = $script:mNic; subnet = $script:mSubnet } {
            New-ResourceDependencyGraph -Resources @($vm, $nic, $subnet)
        }
    }

    It 'starts with graph direction header' {
        $diagram = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ g = $script:mGraph } {
            ConvertTo-MermaidDiagram -Graph $g
        }
        $diagram | Should -Match '^graph TD'
    }

    It 'respects -Direction parameter' {
        $diagram = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ g = $script:mGraph } {
            ConvertTo-MermaidDiagram -Graph $g -Direction LR
        }
        $diagram | Should -Match '^graph LR'
    }

    It 'includes a node definition for each graph node' {
        $diagram = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ g = $script:mGraph } {
            ConvertTo-MermaidDiagram -Graph $g
        }
        $diagram | Should -Match 'Virtual Machine'
        $diagram | Should -Match 'Network Interface'
        $diagram | Should -Match 'Subnet'
        $diagram | Should -Match 'vm1'
        $diagram | Should -Match 'nic1'
        $diagram | Should -Match 'subnet1'
    }

    It 'includes edge definitions with cardinality labels' {
        $diagram = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ g = $script:mGraph } {
            ConvertTo-MermaidDiagram -Graph $g
        }
        $diagram | Should -Match '1:N'
    }

    It 'includes classDef styles for categories' {
        $diagram = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ g = $script:mGraph } {
            ConvertTo-MermaidDiagram -Graph $g
        }
        $diagram | Should -Match 'classDef compute'
        $diagram | Should -Match 'classDef network'
    }

    It 'assigns class styles to nodes' {
        $diagram = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ g = $script:mGraph } {
            ConvertTo-MermaidDiagram -Graph $g
        }
        $diagram | Should -Match 'class .+ compute'
        $diagram | Should -Match 'class .+ network'
    }
}

Describe 'Resolve-DependencyPath' {
    It 'resolves a simple dotted path' {
        $obj = [PSCustomObject]@{
            properties = [PSCustomObject]@{
                availabilitySet = [PSCustomObject]@{
                    id = "$script:baseId/Microsoft.Compute/availabilitySets/as1"
                }
            }
        }
        $result = @(InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ obj = $obj } {
            Resolve-DependencyPath -Resource $obj -Path 'properties.availabilitySet.id'
        })
        $result | Should -HaveCount 1
        $result[0] | Should -BeLike '*/availabilitySets/as1'
    }

    It 'expands arrays with [] notation' {
        $obj = [PSCustomObject]@{
            properties = [PSCustomObject]@{
                networkProfile = [PSCustomObject]@{
                    networkInterfaces = @(
                        [PSCustomObject]@{ id = "$script:baseId/Microsoft.Network/networkInterfaces/nic1" },
                        [PSCustomObject]@{ id = "$script:baseId/Microsoft.Network/networkInterfaces/nic2" }
                    )
                }
            }
        }
        $result = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ obj = $obj } {
            Resolve-DependencyPath -Resource $obj -Path 'properties.networkProfile.networkInterfaces[].id'
        }
        $result | Should -HaveCount 2
        $result[0] | Should -BeLike '*/nic1'
        $result[1] | Should -BeLike '*/nic2'
    }

    It 'handles nested array + property paths' {
        $obj = [PSCustomObject]@{
            properties = [PSCustomObject]@{
                ipConfigurations = @(
                    [PSCustomObject]@{
                        properties = [PSCustomObject]@{
                            subnet = [PSCustomObject]@{
                                id = "$script:baseId/Microsoft.Network/virtualNetworks/vnet1/subnets/subnet1"
                            }
                        }
                    }
                )
            }
        }
        $result = @(InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ obj = $obj } {
            Resolve-DependencyPath -Resource $obj -Path 'properties.ipConfigurations[].properties.subnet.id'
        })
        $result | Should -HaveCount 1
        $result[0] | Should -BeLike '*/subnets/subnet1'
    }

    It 'returns empty array for null at any level' {
        $obj = [PSCustomObject]@{
            properties = [PSCustomObject]@{
                networkSecurityGroup = $null
            }
        }
        $result = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ obj = $obj } {
            Resolve-DependencyPath -Resource $obj -Path 'properties.networkSecurityGroup.id'
        }
        $result | Should -HaveCount 0
    }

    It 'returns empty array for missing property' {
        $obj = [PSCustomObject]@{
            properties = [PSCustomObject]@{}
        }
        $result = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ obj = $obj } {
            Resolve-DependencyPath -Resource $obj -Path 'properties.nonExistent.id'
        }
        $result | Should -HaveCount 0
    }

    It 'resolves top-level property without nesting' {
        $obj = [PSCustomObject]@{
            managedBy = "$script:baseId/Microsoft.Compute/virtualMachines/vm1"
        }
        $result = @(InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ obj = $obj } {
            Resolve-DependencyPath -Resource $obj -Path 'managedBy'
        })
        $result | Should -HaveCount 1
        $result[0] | Should -BeLike '*/virtualMachines/vm1'
    }
}

Describe 'New-ResourceDependencyGraph' {
    BeforeAll {
        # ---- Resource IDs ----
        $script:subnetId = "$script:baseId/Microsoft.Network/virtualNetworks/vnet1/subnets/subnet1"
        $script:nicId    = "$script:baseId/Microsoft.Network/networkInterfaces/nic1"
        $script:vmId     = "$script:baseId/Microsoft.Compute/virtualMachines/vm1"
        $script:diskId   = "$script:baseId/Microsoft.Compute/disks/vm1-osdisk"
        $script:pipId    = "$script:baseId/Microsoft.Network/publicIPAddresses/pip1"
        $script:nsgId    = "$script:baseId/Microsoft.Network/networkSecurityGroups/nsg1"
        $script:rtId     = "$script:baseId/Microsoft.Network/routeTables/rt1"
        $script:asId     = "$script:baseId/Microsoft.Compute/availabilitySets/as1"
        $script:vnetId   = "$script:baseId/Microsoft.Network/virtualNetworks/vnet1"
        $script:desId    = "$script:baseId/Microsoft.Compute/diskEncryptionSets/des1"

        # ---- Mock ARM resources ----
        $script:subnet = [PSCustomObject]@{
            id = $script:subnetId; name = 'subnet1'; type = 'Microsoft.Network/virtualNetworks/subnets'; location = 'westus2'
            properties = [PSCustomObject]@{
                addressPrefix        = '10.0.0.0/24'
                networkSecurityGroup = [PSCustomObject]@{ id = $script:nsgId }
                routeTable           = [PSCustomObject]@{ id = $script:rtId }
                natGateway           = $null
            }
        }
        $script:nic = [PSCustomObject]@{
            id = $script:nicId; name = 'nic1'; type = 'Microsoft.Network/networkInterfaces'; location = 'westus2'
            properties = [PSCustomObject]@{
                ipConfigurations = @(
                    [PSCustomObject]@{
                        properties = [PSCustomObject]@{
                            subnet          = [PSCustomObject]@{ id = $script:subnetId }
                            publicIPAddress = [PSCustomObject]@{ id = $script:pipId }
                        }
                    }
                )
                networkSecurityGroup = [PSCustomObject]@{ id = $script:nsgId }
            }
        }
        $script:vm = [PSCustomObject]@{
            id = $script:vmId; name = 'vm1'; type = 'Microsoft.Compute/virtualMachines'; location = 'westus2'
            identity = $null
            properties = [PSCustomObject]@{
                networkProfile = [PSCustomObject]@{
                    networkInterfaces = @([PSCustomObject]@{ id = $script:nicId })
                }
                storageProfile = [PSCustomObject]@{
                    osDisk    = [PSCustomObject]@{ managedDisk = [PSCustomObject]@{ id = $script:diskId } }
                    dataDisks = @()
                }
                availabilitySet        = [PSCustomObject]@{ id = $script:asId }
                proximityPlacementGroup = $null
                virtualMachineScaleSet  = $null
                hostGroup               = $null
            }
        }
        $script:disk = [PSCustomObject]@{
            id = $script:diskId; name = 'vm1-osdisk'; type = 'Microsoft.Compute/disks'; location = 'westus2'
            managedBy = $script:vmId
            properties = [PSCustomObject]@{
                encryption = [PSCustomObject]@{ diskEncryptionSetId = $script:desId }
            }
        }
        $script:pip = [PSCustomObject]@{
            id = $script:pipId; name = 'pip1'; type = 'Microsoft.Network/publicIPAddresses'; location = 'westus2'
            properties = [PSCustomObject]@{
                ipConfiguration = [PSCustomObject]@{
                    id = "$script:nicId/ipConfigurations/ipconfig1"
                }
            }
        }
        $script:nsg = [PSCustomObject]@{
            id = $script:nsgId; name = 'nsg1'; type = 'Microsoft.Network/networkSecurityGroups'; location = 'westus2'
            properties = [PSCustomObject]@{
                subnets           = @([PSCustomObject]@{ id = $script:subnetId })
                networkInterfaces = @([PSCustomObject]@{ id = $script:nicId })
            }
        }
        $script:rt = [PSCustomObject]@{
            id = $script:rtId; name = 'rt1'; type = 'Microsoft.Network/routeTables'; location = 'westus2'
            properties = [PSCustomObject]@{
                subnets = @([PSCustomObject]@{ id = $script:subnetId })
            }
        }
        $script:as = [PSCustomObject]@{
            id = $script:asId; name = 'as1'; type = 'Microsoft.Compute/availabilitySets'; location = 'westus2'
            properties = [PSCustomObject]@{
                virtualMachines       = @([PSCustomObject]@{ id = $script:vmId })
                proximityPlacementGroup = $null
            }
        }
        $script:vnet = [PSCustomObject]@{
            id = $script:vnetId; name = 'vnet1'; type = 'Microsoft.Network/virtualNetworks'; location = 'westus2'
            properties = [PSCustomObject]@{
                subnets                   = @([PSCustomObject]@{ id = $script:subnetId })
                virtualNetworkPeerings    = @()
                ddosProtectionPlan        = $null
            }
        }
        $script:des = [PSCustomObject]@{
            id = $script:desId; name = 'des1'; type = 'Microsoft.Compute/diskEncryptionSets'; location = 'westus2'
            identity = $null
            properties = [PSCustomObject]@{
                activeKey = [PSCustomObject]@{
                    sourceVault = $null
                }
            }
        }
        # Full resource set
        $script:allResources = @(
            $script:vm, $script:nic, $script:subnet, $script:disk, $script:pip,
            $script:nsg, $script:rt, $script:as, $script:vnet, $script:des
        )
    }

    Context 'Core VM chain: VM + NIC + Subnet' {
        BeforeAll {
            $script:graph = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ r = @($script:vm, $script:nic, $script:subnet) } {
                New-ResourceDependencyGraph -Resources $r
            }
        }

        It 'creates 3 nodes' {
            $script:graph.Nodes.Count | Should -Be 3
        }

        It 'creates VM -> NIC edge (1:N via array path)' {
            $edge = $script:graph.GetOutgoingEdges($script:vmId) | Where-Object { $_.TargetId -eq $script:nicId }
            $edge | Should -Not -BeNullOrEmpty
            $edge.Cardinality | Should -Be 'OneToMany'
            $edge.DiscoveredVia | Should -Be 'networkInterfaces'
        }

        It 'creates NIC -> Subnet edge (1:N via array path)' {
            $edge = $script:graph.GetOutgoingEdges($script:nicId) | Where-Object { $_.TargetId -eq $script:subnetId }
            $edge | Should -Not -BeNullOrEmpty
            $edge.Cardinality | Should -Be 'OneToMany'
            $edge.DiscoveredVia | Should -Be 'subnet'
        }
    }

    Context 'VM -> Managed Disk (1:1 via scalar path)' {
        BeforeAll {
            $script:graph = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ r = @($script:vm, $script:disk) } {
                New-ResourceDependencyGraph -Resources $r
            }
        }

        It 'creates VM -> Disk edge via osDisk (1:1)' {
            $edge = $script:graph.GetOutgoingEdges($script:vmId) | Where-Object { $_.DiscoveredVia -eq 'osDisk' }
            $edge | Should -Not -BeNullOrEmpty
            $edge.TargetId | Should -Be $script:diskId
            $edge.Cardinality | Should -Be 'OneToOne'
        }

        It 'creates Disk -> VM back-reference via managedBy (1:1)' {
            $edge = $script:graph.GetOutgoingEdges($script:diskId) | Where-Object { $_.DiscoveredVia -eq 'managedBy' }
            $edge | Should -Not -BeNullOrEmpty
            $edge.TargetId | Should -Be $script:vmId
            $edge.Cardinality | Should -Be 'OneToOne'
        }
    }

    Context 'VM -> Availability Set (1:1 via scalar path)' {
        BeforeAll {
            $script:graph = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ r = @($script:vm, $script:as) } {
                New-ResourceDependencyGraph -Resources $r
            }
        }

        It 'creates VM -> Availability Set edge (1:1)' {
            $edge = $script:graph.GetOutgoingEdges($script:vmId) | Where-Object { $_.DiscoveredVia -eq 'availabilitySet' }
            $edge | Should -Not -BeNullOrEmpty
            $edge.TargetId | Should -Be $script:asId
            $edge.Cardinality | Should -Be 'OneToOne'
        }

        It 'creates Availability Set -> VM back-reference (1:N)' {
            $edge = $script:graph.GetOutgoingEdges($script:asId) | Where-Object { $_.DiscoveredVia -eq 'virtualMachines' }
            $edge | Should -Not -BeNullOrEmpty
            $edge.TargetId | Should -Be $script:vmId
            $edge.Cardinality | Should -Be 'OneToMany'
        }
    }

    Context 'NIC -> Public IP + NSG' {
        BeforeAll {
            $script:graph = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ r = @($script:nic, $script:pip, $script:nsg) } {
                New-ResourceDependencyGraph -Resources $r
            }
        }

        It 'creates NIC -> Public IP edge (1:N via array path)' {
            $edge = $script:graph.GetOutgoingEdges($script:nicId) | Where-Object { $_.DiscoveredVia -eq 'publicIPAddress' }
            $edge | Should -Not -BeNullOrEmpty
            $edge.TargetId | Should -Be $script:pipId
            $edge.Cardinality | Should -Be 'OneToMany'
        }

        It 'creates NIC -> NSG edge (1:1 via scalar path)' {
            $edge = $script:graph.GetOutgoingEdges($script:nicId) | Where-Object { $_.DiscoveredVia -eq 'networkSecurityGroup' }
            $edge | Should -Not -BeNullOrEmpty
            $edge.TargetId | Should -Be $script:nsgId
            $edge.Cardinality | Should -Be 'OneToOne'
        }
    }

    Context 'Subnet -> NSG + Route Table' {
        BeforeAll {
            $script:graph = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ r = @($script:subnet, $script:nsg, $script:rt) } {
                New-ResourceDependencyGraph -Resources $r
            }
        }

        It 'creates Subnet -> NSG edge (1:1 via scalar path)' {
            $edge = $script:graph.GetOutgoingEdges($script:subnetId) | Where-Object { $_.DiscoveredVia -eq 'networkSecurityGroup' }
            $edge | Should -Not -BeNullOrEmpty
            $edge.TargetId | Should -Be $script:nsgId
            $edge.Cardinality | Should -Be 'OneToOne'
        }

        It 'creates Subnet -> Route Table edge (1:1 via scalar path)' {
            $edge = $script:graph.GetOutgoingEdges($script:subnetId) | Where-Object { $_.DiscoveredVia -eq 'routeTable' }
            $edge | Should -Not -BeNullOrEmpty
            $edge.TargetId | Should -Be $script:rtId
            $edge.Cardinality | Should -Be 'OneToOne'
        }
    }

    Context 'VNet -> Subnet (1:N via array path)' {
        BeforeAll {
            $script:graph = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ r = @($script:vnet, $script:subnet) } {
                New-ResourceDependencyGraph -Resources $r
            }
        }

        It 'creates VNet -> Subnet edge (1:N)' {
            $edge = $script:graph.GetOutgoingEdges($script:vnetId) | Where-Object { $_.DiscoveredVia -eq 'subnets' }
            $edge | Should -Not -BeNullOrEmpty
            $edge.TargetId | Should -Be $script:subnetId
            $edge.Cardinality | Should -Be 'OneToMany'
        }
    }

    Context 'Disk -> Disk Encryption Set (1:1 via scalar path)' {
        BeforeAll {
            $script:graph = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ r = @($script:disk, $script:des) } {
                New-ResourceDependencyGraph -Resources $r
            }
        }

        It 'creates Disk -> DES edge (1:1)' {
            $edge = $script:graph.GetOutgoingEdges($script:diskId) | Where-Object { $_.DiscoveredVia -eq 'diskEncryptionSet' }
            $edge | Should -Not -BeNullOrEmpty
            $edge.TargetId | Should -Be $script:desId
            $edge.Cardinality | Should -Be 'OneToOne'
        }
    }

    Context 'Full graph: all 11 resources' {
        BeforeAll {
            $script:graph = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ r = $script:allResources } {
                New-ResourceDependencyGraph -Resources $r
            }
        }

        It 'creates 10 nodes' {
            $script:graph.Nodes.Count | Should -Be 10
        }

        It 'creates at least 10 edges' {
            $script:graph.Edges.Count | Should -BeGreaterOrEqual 10
        }

        It 'produces valid JSON serialization' {
            $json = $script:graph.ToPSCustomObject() | ConvertTo-Json -Depth 10
            { $json | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context 'Dangling reference (VM only, no NIC in input)' {
        BeforeAll {
            $script:graph = InModuleScope 'Devolutions.CIEM.ResourceGraph' -Parameters @{ r = @($script:vm) } {
                New-ResourceDependencyGraph -Resources $r
            }
        }

        It 'creates 1 node' {
            $script:graph.Nodes.Count | Should -Be 1
        }

        It 'creates 0 edges (dangling references ignored)' {
            $script:graph.Edges.Count | Should -Be 0
        }
    }
}
