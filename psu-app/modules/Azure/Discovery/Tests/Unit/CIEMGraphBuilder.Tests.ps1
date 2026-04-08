BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    # Create isolated test DB with base + azure + discovery + graph schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    foreach ($schemaPath in @(
        (Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'),
        (Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql'),
        (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.Graph' 'Data' 'graph_schema.sql')
    )) {
        foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            $trimmed = $statement.Trim()
            try {
                Invoke-CIEMQuery -Query $trimmed -AsNonQuery | Out-Null
            }
            catch {
                if ($trimmed -match 'ALTER\s+TABLE' -and $_.Exception.Message -match 'duplicate column') {
                    continue
                }
                throw
            }
        }
    }
}

Describe 'Graph Builder Functions' {

    # =========================================================================
    # ResolveCIEMNodeKind
    # =========================================================================

    Context 'ResolveCIEMNodeKind' {

        It 'Is available as a private function inside the module' {
            InModuleScope Devolutions.CIEM {
                Get-Command ResolveCIEMNodeKind -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
        }

        It 'Maps known ARM type microsoft.compute/virtualmachines to AzureVM' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMNodeKind -Type 'microsoft.compute/virtualmachines' -Source 'ARM'
                $result | Should -Be 'AzureVM'
            }
        }

        It 'Maps known ARM type microsoft.network/networksecuritygroups to AzureNSG' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMNodeKind -Type 'microsoft.network/networksecuritygroups' -Source 'ARM'
                $result | Should -Be 'AzureNSG'
            }
        }

        It 'Maps known ARM type microsoft.authorization/roleassignments to AzureRoleAssignment' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMNodeKind -Type 'microsoft.authorization/roleassignments' -Source 'ARM'
                $result | Should -Be 'AzureRoleAssignment'
            }
        }

        It 'Maps known ARM type microsoft.resources/subscriptions to AzureSubscription' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMNodeKind -Type 'microsoft.resources/subscriptions' -Source 'ARM'
                $result | Should -Be 'AzureSubscription'
            }
        }

        It 'Maps unknown ARM type to AzureResource' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMNodeKind -Type 'microsoft.custom/something' -Source 'ARM'
                $result | Should -Be 'AzureResource'
            }
        }

        It 'Maps Entra user type to EntraUser' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMNodeKind -Type 'user' -Source 'Entra'
                $result | Should -Be 'EntraUser'
            }
        }

        It 'Maps Entra servicePrincipal to EntraServicePrincipal' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMNodeKind -Type 'servicePrincipal' -Source 'Entra'
                $result | Should -Be 'EntraServicePrincipal'
            }
        }

        It 'Maps Entra servicePrincipal with ManagedIdentity type to EntraManagedIdentity' {
            InModuleScope Devolutions.CIEM {
                $propsJson = '{"servicePrincipalType":"ManagedIdentity"}'
                $result = ResolveCIEMNodeKind -Type 'servicePrincipal' -Source 'Entra' -PropertiesJson $propsJson
                $result | Should -Be 'EntraManagedIdentity'
            }
        }

        It 'Maps Entra servicePrincipal without ManagedIdentity type to EntraServicePrincipal' {
            InModuleScope Devolutions.CIEM {
                $propsJson = '{"servicePrincipalType":"Application"}'
                $result = ResolveCIEMNodeKind -Type 'servicePrincipal' -Source 'Entra' -PropertiesJson $propsJson
                $result | Should -Be 'EntraServicePrincipal'
            }
        }

        It 'Maps Entra group to EntraGroup' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMNodeKind -Type 'group' -Source 'Entra'
                $result | Should -Be 'EntraGroup'
            }
        }

        It 'Maps Entra directoryRole to EntraDirectoryRole' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMNodeKind -Type 'directoryRole' -Source 'Entra'
                $result | Should -Be 'EntraDirectoryRole'
            }
        }

        It 'Returns unknown Entra type as-is (no default mapping)' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMNodeKind -Type 'unknownEntraType' -Source 'Entra'
                $result | Should -Be 'unknownEntraType'
            }
        }
    }

    # =========================================================================
    # InvokeCIEMGraphNodeBuild
    # =========================================================================

    Context 'InvokeCIEMGraphNodeBuild' {

        It 'Is available as a private function inside the module' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMGraphNodeBuild -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
        }

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
        }

        It 'Creates graph nodes from ARM resources' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1'
                        Type = 'microsoft.compute/virtualmachines'
                        Name = 'vm1'
                        Location = 'eastus'
                        ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'
                        TenantId = 'tenant1'
                        Kind = $null
                        Sku = $null
                        Identity = $null
                        ManagedBy = $null
                        Plan = $null
                        Zones = $null
                        Tags = '{"env":"test"}'
                        Properties = '{"vmId":"vm-guid"}'
                        CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1'
                        Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'
                        Location = $null
                        ResourceGroup = $null
                        SubscriptionId = 'sub1'
                        TenantId = 'tenant1'
                        Kind = $null
                        Sku = $null
                        Identity = $null
                        ManagedBy = $null
                        Plan = $null
                        Zones = $null
                        Tags = $null
                        Properties = '{"subscriptionId":"sub1","state":"Enabled"}'
                        CollectedAt = $ts
                    }
                )
                $entraResources = @()

                $count = InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $nodes = Get-CIEMGraphNode
                # 2 ARM + Internet + AzureTenant singletons
                $armNodes = $nodes | Where-Object { $_.Kind -in @('AzureVM', 'AzureSubscription') }
                $armNodes | Should -HaveCount 2

                $vmNode = $nodes | Where-Object { $_.Kind -eq 'AzureVM' }
                $vmNode.Id | Should -Be '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1'
                $vmNode.DisplayName | Should -Be 'vm1'
                $vmNode.Provider | Should -Be 'azure'
                $vmNode.SubscriptionId | Should -Be 'sub1'
                $vmNode.ResourceGroup | Should -Be 'rg1'

                $subNode = $nodes | Where-Object { $_.Kind -eq 'AzureSubscription' }
                $subNode.DisplayName | Should -Be 'sub1'
            }
        }

        It 'Creates graph nodes from Entra resources' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $armResources = @(
                    # Need at least one ARM resource for tenant node
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1'
                        Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )
                $entraResources = @(
                    [PSCustomObject]@{
                        Id = 'user-guid-1'
                        Type = 'user'
                        DisplayName = 'Test User'
                        ParentId = $null
                        Properties = '{"accountEnabled":true,"userPrincipalName":"test@example.com"}'
                        CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        Id = 'sp-guid-1'
                        Type = 'servicePrincipal'
                        DisplayName = 'Test SP'
                        ParentId = $null
                        Properties = '{"servicePrincipalType":"Application"}'
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $userNode = Get-CIEMGraphNode -Id 'user-guid-1'
                $userNode | Should -Not -BeNullOrEmpty
                $userNode.Kind | Should -Be 'EntraUser'
                $userNode.DisplayName | Should -Be 'Test User'
                $userNode.Provider | Should -Be 'azure'
                $userNode.SubscriptionId | Should -BeNullOrEmpty
                $userNode.ResourceGroup | Should -BeNullOrEmpty

                $spNode = Get-CIEMGraphNode -Id 'sp-guid-1'
                $spNode | Should -Not -BeNullOrEmpty
                $spNode.Kind | Should -Be 'EntraServicePrincipal'
            }
        }

        It 'Detects managed identity and sets kind to EntraManagedIdentity' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1'
                        Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )
                $entraResources = @(
                    [PSCustomObject]@{
                        Id = 'mi-sp-guid'
                        Type = 'servicePrincipal'
                        DisplayName = 'vm1-managed-identity'
                        ParentId = $null
                        Properties = '{"servicePrincipalType":"ManagedIdentity"}'
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $miNode = Get-CIEMGraphNode -Id 'mi-sp-guid'
                $miNode | Should -Not -BeNullOrEmpty
                $miNode.Kind | Should -Be 'EntraManagedIdentity'
            }
        }

        It 'Creates Internet singleton node' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1'
                        Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )
                $entraResources = @()

                InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $internetNode = Get-CIEMGraphNode -Id '__internet__'
                $internetNode | Should -Not -BeNullOrEmpty
                $internetNode.Kind | Should -Be 'Internet'
                $internetNode.Provider | Should -Be 'global'
            }
        }

        It 'Creates AzureTenant singleton node from ARM TenantId' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1'
                        Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant-id-123'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )
                $entraResources = @()

                InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $tenantNode = Get-CIEMGraphNode -Id 'tenant-id-123'
                $tenantNode | Should -Not -BeNullOrEmpty
                $tenantNode.Kind | Should -Be 'AzureTenant'
            }
        }

        It 'Returns total node count' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1'
                        Type = 'microsoft.compute/virtualmachines'
                        Name = 'vm1'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )
                $entraResources = @(
                    [PSCustomObject]@{
                        Id = 'user-1'
                        Type = 'user'
                        DisplayName = 'User One'
                        ParentId = $null
                        Properties = '{}'
                        CollectedAt = $ts
                    }
                )

                $count = InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                # 1 ARM + 1 Entra + Internet + AzureTenant = 4
                $count | Should -Be 4
            }
        }

        It 'Packs ARM-specific fields into properties JSON' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-props'
                        Type = 'microsoft.compute/virtualmachines'
                        Name = 'vm-props'
                        Location = 'westus2'
                        ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'
                        TenantId = 'tenant1'
                        Kind = 'linux'
                        Sku = '{"name":"Standard_B2s"}'
                        Identity = '{"principalId":"mi-id-1","type":"SystemAssigned"}'
                        ManagedBy = $null
                        Plan = $null
                        Zones = '["1","2"]'
                        Tags = '{"env":"test","team":"ciem"}'
                        Properties = '{"vmId":"vm-guid-props"}'
                        CollectedAt = $ts
                    }
                )
                $entraResources = @()

                InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $node = Get-CIEMGraphNode -Id '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-props'
                $node | Should -Not -BeNullOrEmpty
                $node.Properties | Should -Not -BeNullOrEmpty

                $props = $node.Properties | ConvertFrom-Json
                $props.arm_type | Should -Be 'microsoft.compute/virtualmachines'
                $props.location | Should -Be 'westus2'
                $props.tenant_id | Should -Be 'tenant1'
                $props.tags | Should -Not -BeNullOrEmpty
                $props.identity | Should -Not -BeNullOrEmpty
            }
        }

        It 'Stores Entra Properties as-is when no signInActivity present' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1'
                        Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )
                $entraResources = @(
                    [PSCustomObject]@{
                        Id = 'user-props-test'
                        Type = 'user'
                        DisplayName = 'Props User'
                        ParentId = $null
                        Properties = '{"accountEnabled":true,"userPrincipalName":"props@example.com","jobTitle":"Engineer"}'
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $node = Get-CIEMGraphNode -Id 'user-props-test'
                $node.Properties | Should -Be '{"accountEnabled":true,"userPrincipalName":"props@example.com","jobTitle":"Engineer"}'
            }
        }

        It 'Enriches Entra user properties with daysSinceSignIn from signInActivity' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                # signInActivity with lastSignInDateTime 30 days before the CollectedAt date
                $signInDate = ([datetime]::Parse($ts)).AddDays(-30).ToString('o')
                $propsJson = @{
                    accountEnabled = $true
                    signInActivity = @{
                        lastSignInDateTime = $signInDate
                        lastNonInteractiveSignInDateTime = $null
                    }
                } | ConvertTo-Json -Depth 3 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1'; Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )
                $entraResources = @(
                    [PSCustomObject]@{
                        Id = 'user-signin-test'
                        Type = 'user'
                        DisplayName = 'SignIn User'
                        ParentId = $null
                        Properties = $propsJson
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $node = Get-CIEMGraphNode -Id 'user-signin-test'
                $enrichedProps = $node.Properties | ConvertFrom-Json
                $enrichedProps.daysSinceSignIn | Should -Be 30
            }
        }

        It 'Uses most recent sign-in date between interactive and non-interactive' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $interactiveDate = ([datetime]::Parse($ts)).AddDays(-60).ToString('o')
                $nonInteractiveDate = ([datetime]::Parse($ts)).AddDays(-10).ToString('o')
                $propsJson = @{
                    accountEnabled = $true
                    signInActivity = @{
                        lastSignInDateTime = $interactiveDate
                        lastNonInteractiveSignInDateTime = $nonInteractiveDate
                    }
                } | ConvertTo-Json -Depth 3 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1'; Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )
                $entraResources = @(
                    [PSCustomObject]@{
                        Id = 'user-both-signin'
                        Type = 'user'
                        DisplayName = 'Both SignIn User'
                        ParentId = $null
                        Properties = $propsJson
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $node = Get-CIEMGraphNode -Id 'user-both-signin'
                $enrichedProps = $node.Properties | ConvertFrom-Json
                # Should use the more recent non-interactive date (10 days)
                $enrichedProps.daysSinceSignIn | Should -Be 10
            }
        }

        It 'Does not add daysSinceSignIn when signInActivity has no timestamps' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $propsJson = @{
                    accountEnabled = $true
                    signInActivity = @{
                        lastSignInDateTime = $null
                        lastNonInteractiveSignInDateTime = $null
                    }
                } | ConvertTo-Json -Depth 3 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1'; Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )
                $entraResources = @(
                    [PSCustomObject]@{
                        Id = 'user-no-dates'
                        Type = 'user'
                        DisplayName = 'No Dates User'
                        ParentId = $null
                        Properties = $propsJson
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphNodeBuild -ArmResources $armResources -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $node = Get-CIEMGraphNode -Id 'user-no-dates'
                $enrichedProps = $node.Properties | ConvertFrom-Json
                $enrichedProps.PSObject.Properties.Name | Should -Not -Contain 'daysSinceSignIn'
            }
        }

        It 'Clamps daysSinceSignIn to 0 when sign-in date is in the future relative to CollectedAt' {
            InModuleScope Devolutions.CIEM {
                Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

                $ts = '2026-01-15T00:00:00Z'
                # Sign-in date 5 days AFTER collection date (clock skew or data anomaly)
                $futureSignIn = ([datetime]::Parse($ts)).AddDays(5).ToString('o')
                $entraResources = @([PSCustomObject]@{
                    Id          = 'user-future-signin'
                    Type        = 'user'
                    DisplayName = 'Future User'
                    Properties  = @{ signInActivity = @{ lastSignInDateTime = $futureSignIn } } | ConvertTo-Json -Depth 3 -Compress
                })

                InvokeCIEMGraphNodeBuild -ArmResources @() -EntraResources $entraResources -Connection $null -CollectedAt $ts

                $node = Get-CIEMGraphNode -Id 'user-future-signin'
                $enrichedProps = $node.Properties | ConvertFrom-Json
                $enrichedProps.daysSinceSignIn | Should -Be 0
            }
        }
    }

    # =========================================================================
    # InvokeCIEMGraphEdgeBuild
    # =========================================================================

    Context 'InvokeCIEMGraphEdgeBuild' {

        It 'Is available as a private function inside the module' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMGraphEdgeBuild -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
        }

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
            # Seed prerequisite nodes (FK constraint)
            Save-CIEMGraphNode -Id 'user-1' -Kind 'EntraUser' -DisplayName 'User' -Provider 'azure'
            Save-CIEMGraphNode -Id 'group-1' -Kind 'EntraGroup' -DisplayName 'Group' -Provider 'azure'
            Save-CIEMGraphNode -Id 'role-1' -Kind 'EntraDirectoryRole' -DisplayName 'Admin' -Provider 'azure'
            Save-CIEMGraphNode -Id 'sp-1' -Kind 'EntraServicePrincipal' -DisplayName 'SP' -Provider 'azure'
        }

        It 'Creates MemberOf edges from member_of relationships' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $relationships = @(
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'group-1'; TargetType = 'group'
                        Relationship = 'member_of'; CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphEdgeBuild -Relationships $relationships -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -SourceId 'user-1' -Kind 'MemberOf'
                $edges | Should -HaveCount 1
                $edges[0].TargetId | Should -Be 'group-1'
            }
        }

        It 'Creates OwnerOf edges from owner_of relationships' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $relationships = @(
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'group-1'; TargetType = 'group'
                        Relationship = 'owner_of'; CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphEdgeBuild -Relationships $relationships -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -SourceId 'user-1' -Kind 'OwnerOf'
                $edges | Should -HaveCount 1
                $edges[0].TargetId | Should -Be 'group-1'
            }
        }

        It 'Creates TransitiveMemberOf edges from transitive_member_of relationships' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $relationships = @(
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'group-1'; TargetType = 'group'
                        Relationship = 'transitive_member_of'; CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphEdgeBuild -Relationships $relationships -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -SourceId 'user-1' -Kind 'TransitiveMemberOf'
                $edges | Should -HaveCount 1
            }
        }

        It 'Creates HasRoleMember edges from has_role_member relationships' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $relationships = @(
                    [PSCustomObject]@{
                        SourceId = 'role-1'; SourceType = 'directoryRole'
                        TargetId = 'user-1'; TargetType = 'user'
                        Relationship = 'has_role_member'; CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphEdgeBuild -Relationships $relationships -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -SourceId 'role-1' -Kind 'HasRoleMember'
                $edges | Should -HaveCount 1
                $edges[0].TargetId | Should -Be 'user-1'
            }
        }

        It 'Sets computed = 0 on all collected edges' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $relationships = @(
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'group-1'; TargetType = 'group'
                        Relationship = 'member_of'; CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'role-1'; TargetType = 'directoryRole'
                        Relationship = 'owner_of'; CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphEdgeBuild -Relationships $relationships -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge
                $edges | Should -HaveCount 2
                $edges | ForEach-Object { $_.Computed | Should -Be 0 }
            }
        }

        It 'Returns edge count' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $relationships = @(
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'group-1'; TargetType = 'group'
                        Relationship = 'member_of'; CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'role-1'; TargetType = 'directoryRole'
                        Relationship = 'owner_of'; CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        SourceId = 'role-1'; SourceType = 'directoryRole'
                        TargetId = 'sp-1'; TargetType = 'servicePrincipal'
                        Relationship = 'has_role_member'; CollectedAt = $ts
                    }
                )

                $count = InvokeCIEMGraphEdgeBuild -Relationships $relationships -Connection $null -CollectedAt $ts
                $count | Should -Be 3
            }
        }

        It 'Handles empty relationship array' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $count = InvokeCIEMGraphEdgeBuild -Relationships @() -Connection $null -CollectedAt $ts
                $count | Should -Be 0
                $edges = Get-CIEMGraphEdge
                $edges | Should -BeNullOrEmpty
            }
        }

        It 'Skips edges where source node does not exist but creates edges where both nodes exist' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                # 'missing-node' is NOT in graph_nodes, so this edge should be skipped
                # 'user-1' -> 'group-1' both exist, so this edge should be created
                $relationships = @(
                    [PSCustomObject]@{
                        SourceId = 'missing-node'; SourceType = 'user'
                        TargetId = 'group-1'; TargetType = 'group'
                        Relationship = 'member_of'; CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'group-1'; TargetType = 'group'
                        Relationship = 'member_of'; CollectedAt = $ts
                    }
                )

                $count = InvokeCIEMGraphEdgeBuild -Relationships $relationships -Connection $null -CollectedAt $ts
                $count | Should -Be 1

                $edges = Get-CIEMGraphEdge -SourceId 'user-1' -Kind 'MemberOf'
                $edges | Should -HaveCount 1
            }
        }

        It 'Skips edges where target node does not exist' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $relationships = @(
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'missing-target'; TargetType = 'group'
                        Relationship = 'member_of'; CollectedAt = $ts
                    }
                )

                $count = InvokeCIEMGraphEdgeBuild -Relationships $relationships -Connection $null -CollectedAt $ts
                $count | Should -Be 0

                $edges = Get-CIEMGraphEdge
                $edges | Should -BeNullOrEmpty
            }
        }

        It 'Caches node existence checks across repeated references to the same node' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                # Multiple relationships referencing the same source/target nodes
                # The cache should prevent redundant DB queries
                $relationships = @(
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'group-1'; TargetType = 'group'
                        Relationship = 'member_of'; CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'role-1'; TargetType = 'directoryRole'
                        Relationship = 'owner_of'; CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        SourceId = 'user-1'; SourceType = 'user'
                        TargetId = 'sp-1'; TargetType = 'servicePrincipal'
                        Relationship = 'member_of'; CollectedAt = $ts
                    }
                )

                $count = InvokeCIEMGraphEdgeBuild -Relationships $relationships -Connection $null -CollectedAt $ts
                $count | Should -Be 3

                $edges = Get-CIEMGraphEdge -SourceId 'user-1'
                $edges | Should -HaveCount 3
            }
        }
    }

    # =========================================================================
    # InvokeCIEMGraphComputedEdgeBuild
    # =========================================================================

    Context 'InvokeCIEMGraphComputedEdgeBuild' {

        It 'Is available as a private function inside the module' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMGraphComputedEdgeBuild -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
        }

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
        }

        It 'Creates HasRole edges from role assignments' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                # Seed nodes
                Save-CIEMGraphNode -Id '/subscriptions/sub1' -Kind 'AzureSubscription' -DisplayName 'sub1' -Provider 'azure' -SubscriptionId 'sub1'
                Save-CIEMGraphNode -Id 'user-1' -Kind 'EntraUser' -DisplayName 'Test User' -Provider 'azure'

                $roleDefProps = @{
                    roleName = 'Reader'
                    permissions = @(@{ actions = @('*/read'); notActions = @() })
                } | ConvertTo-Json -Depth 5 -Compress

                $roleDefId = '/subscriptions/sub1/providers/Microsoft.Authorization/roleDefinitions/rd-reader'

                $roleAssignProps = @{
                    principalId = 'user-1'
                    principalType = 'User'
                    roleDefinitionId = $roleDefId
                    scope = '/subscriptions/sub1'
                } | ConvertTo-Json -Depth 5 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $roleDefId
                        Type = 'microsoft.authorization/roledefinitions'
                        Name = 'rd-reader'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $roleDefProps
                        CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1/providers/Microsoft.Authorization/roleAssignments/ra-1'
                        Type = 'microsoft.authorization/roleassignments'
                        Name = 'ra-1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $roleAssignProps
                        CollectedAt = $ts
                    }
                )

                $count = InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -SourceId 'user-1' -Kind 'HasRole'
                $edges | Should -HaveCount 1
                $edges[0].TargetId | Should -Be '/subscriptions/sub1'

                $edgeProps = $edges[0].Properties | ConvertFrom-Json
                $edgeProps.role_name | Should -Be 'Reader'
            }
        }

        It 'Marks HasRole edges as privileged when role is in privileged list' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                Save-CIEMGraphNode -Id '/subscriptions/sub1' -Kind 'AzureSubscription' -DisplayName 'sub1' -Provider 'azure' -SubscriptionId 'sub1'
                Save-CIEMGraphNode -Id 'user-priv' -Kind 'EntraUser' -DisplayName 'Priv User' -Provider 'azure'

                $roleDefProps = @{
                    roleName = 'Owner'
                    permissions = @(@{ actions = @('*'); notActions = @() })
                } | ConvertTo-Json -Depth 5 -Compress

                $roleDefId = '/subscriptions/sub1/providers/Microsoft.Authorization/roleDefinitions/rd-owner'

                $roleAssignProps = @{
                    principalId = 'user-priv'
                    principalType = 'User'
                    roleDefinitionId = $roleDefId
                    scope = '/subscriptions/sub1'
                } | ConvertTo-Json -Depth 5 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $roleDefId
                        Type = 'microsoft.authorization/roledefinitions'
                        Name = 'rd-owner'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $roleDefProps
                        CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1/providers/Microsoft.Authorization/roleAssignments/ra-priv'
                        Type = 'microsoft.authorization/roleassignments'
                        Name = 'ra-priv'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $roleAssignProps
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -SourceId 'user-priv' -Kind 'HasRole'
                $edges | Should -HaveCount 1

                $edgeProps = $edges[0].Properties | ConvertFrom-Json
                $edgeProps.privileged | Should -BeTrue
                $edgeProps.role_name | Should -Be 'Owner'
            }
        }

        It 'Creates InheritedRole edges via group expansion' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                # Seed nodes
                Save-CIEMGraphNode -Id '/subscriptions/sub1' -Kind 'AzureSubscription' -DisplayName 'sub1' -Provider 'azure' -SubscriptionId 'sub1'
                Save-CIEMGraphNode -Id 'group-inherit' -Kind 'EntraGroup' -DisplayName 'Admins Group' -Provider 'azure'
                Save-CIEMGraphNode -Id 'user-member' -Kind 'EntraUser' -DisplayName 'Group Member' -Provider 'azure'

                # Seed TransitiveMemberOf edge (user is transitive member of group)
                Save-CIEMGraphEdge -SourceId 'user-member' -TargetId 'group-inherit' -Kind 'TransitiveMemberOf' -Computed 0 -CollectedAt $ts

                $roleDefProps = @{
                    roleName = 'Contributor'
                    permissions = @(@{ actions = @('*'); notActions = @('Microsoft.Authorization/*/Delete', 'Microsoft.Authorization/*/Write', 'Microsoft.Authorization/elevateAccess/Action') })
                } | ConvertTo-Json -Depth 5 -Compress

                $roleDefId = '/subscriptions/sub1/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'

                $roleAssignProps = @{
                    principalId = 'group-inherit'
                    principalType = 'Group'
                    roleDefinitionId = $roleDefId
                    scope = '/subscriptions/sub1'
                } | ConvertTo-Json -Depth 5 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $roleDefId
                        Type = 'microsoft.authorization/roledefinitions'
                        Name = 'rd-contrib'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $roleDefProps
                        CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1/providers/Microsoft.Authorization/roleAssignments/ra-group'
                        Type = 'microsoft.authorization/roleassignments'
                        Name = 'ra-group'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $roleAssignProps
                        CollectedAt = $ts
                    }
                )

                # EntraResources with the group so displayNameLookup resolves its name
                $entraResources = @(
                    [PSCustomObject]@{ Id = 'group-inherit'; DisplayName = 'Admins Group'; Type = 'group'; Properties = $null }
                )

                # TransitiveMemberOf edges already seeded above
                $relationships = @(
                    [PSCustomObject]@{
                        SourceId = 'user-member'; SourceType = 'user'
                        TargetId = 'group-inherit'; TargetType = 'group'
                        Relationship = 'transitive_member_of'; CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources $entraResources -Relationships $relationships -Connection $null -CollectedAt $ts

                # Group should get HasRole
                $groupEdges = Get-CIEMGraphEdge -SourceId 'group-inherit' -Kind 'HasRole'
                $groupEdges | Should -HaveCount 1

                # User should get InheritedRole
                $inheritedEdges = Get-CIEMGraphEdge -SourceId 'user-member' -Kind 'InheritedRole'
                $inheritedEdges | Should -HaveCount 1
                $inheritedEdges[0].TargetId | Should -Be '/subscriptions/sub1'

                $inhProps = $inheritedEdges[0].Properties | ConvertFrom-Json
                $inhProps.inherited_from | Should -Be 'group-inherit'
                $inhProps.inherited_from_name | Should -Be 'Admins Group'
                $inhProps.role_name | Should -Be 'Contributor'
            }
        }

        It 'Creates HasManagedIdentity edges from VM identity JSON' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                Save-CIEMGraphNode -Id '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-mi' `
                    -Kind 'AzureVM' -DisplayName 'vm-mi' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                Save-CIEMGraphNode -Id 'mi-principal-1' -Kind 'EntraManagedIdentity' -DisplayName 'vm-mi-identity' -Provider 'azure'

                $armResources = @(
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-mi'
                        Type = 'microsoft.compute/virtualmachines'
                        Name = 'vm-mi'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null
                        Identity = '{"principalId":"mi-principal-1","type":"SystemAssigned"}'
                        ManagedBy = $null; Plan = $null; Zones = $null; Tags = $null
                        Properties = '{"vmId":"vm-guid"}'
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -Kind 'HasManagedIdentity'
                $edges | Should -HaveCount 1
                $edges[0].SourceId | Should -Be '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-mi'
                $edges[0].TargetId | Should -Be 'mi-principal-1'
            }
        }

        It 'Creates AttachedTo edges from NIC to VM' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $vmId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm1'
                $nicId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkInterfaces/nic1'

                Save-CIEMGraphNode -Id $vmId -Kind 'AzureVM' -DisplayName 'vm1' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                Save-CIEMGraphNode -Id $nicId -Kind 'AzureNIC' -DisplayName 'nic1' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'

                $nicProps = @{
                    virtualMachine = @{ id = $vmId }
                    ipConfigurations = @(
                        @{ properties = @{} }
                    )
                } | ConvertTo-Json -Depth 10 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $nicId
                        Type = 'microsoft.network/networkinterfaces'
                        Name = 'nic1'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $nicProps
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -Kind 'AttachedTo'
                $edges | Should -HaveCount 1
                $edges[0].SourceId | Should -Be $nicId
                $edges[0].TargetId | Should -Be $vmId
            }
        }

        It 'Creates AttachedTo edges from NSG to VM via NIC networkSecurityGroup reference' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $vmId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-nsg'
                $nicId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkInterfaces/nic-nsg'
                $nsgId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg-test'

                Save-CIEMGraphNode -Id $vmId -Kind 'AzureVM' -DisplayName 'vm-nsg' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                Save-CIEMGraphNode -Id $nicId -Kind 'AzureNIC' -DisplayName 'nic-nsg' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                Save-CIEMGraphNode -Id $nsgId -Kind 'AzureNSG' -DisplayName 'nsg-test' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'

                $nicProps = @{
                    virtualMachine = @{ id = $vmId }
                    networkSecurityGroup = @{ id = $nsgId }
                    ipConfigurations = @(
                        @{ properties = @{} }
                    )
                } | ConvertTo-Json -Depth 10 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $nicId
                        Type = 'microsoft.network/networkinterfaces'
                        Name = 'nic-nsg'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $nicProps
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                # Should create both NIC->VM and NSG->VM AttachedTo edges
                $edges = @(Get-CIEMGraphEdge -Kind 'AttachedTo')
                $nsgToVm = $edges | Where-Object { $_.SourceId -eq $nsgId -and $_.TargetId -eq $vmId }
                $nsgToVm | Should -Not -BeNullOrEmpty -Because 'NSG->VM AttachedTo edge should be derived from NIC properties'
            }
        }

        It 'Creates HasPublicIP edges from NIC to PublicIP' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $nicId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkInterfaces/nic-pip'
                $pipId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/publicIPAddresses/pip1'

                Save-CIEMGraphNode -Id $nicId -Kind 'AzureNIC' -DisplayName 'nic-pip' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                Save-CIEMGraphNode -Id $pipId -Kind 'AzurePublicIP' -DisplayName 'pip1' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'

                $nicProps = @{
                    ipConfigurations = @(
                        @{
                            properties = @{
                                publicIPAddress = @{ id = $pipId }
                            }
                        }
                    )
                } | ConvertTo-Json -Depth 10 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $nicId
                        Type = 'microsoft.network/networkinterfaces'
                        Name = 'nic-pip'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $nicProps
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -Kind 'HasPublicIP'
                $edges | Should -HaveCount 1
                $edges[0].SourceId | Should -Be $nicId
                $edges[0].TargetId | Should -Be $pipId
            }
        }

        It 'Creates one AllowsInbound edge per NSG with aggregated open_ports' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $nsgId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg1'

                Save-CIEMGraphNode -Id '__internet__' -Kind 'Internet' -DisplayName 'Internet' -Provider 'global'
                Save-CIEMGraphNode -Id $nsgId -Kind 'AzureNSG' -DisplayName 'nsg1' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'

                $nsgProps = @{
                    securityRules = @(
                        @{
                            name = 'AllowRDP'
                            properties = @{
                                direction = 'Inbound'
                                access = 'Allow'
                                protocol = 'TCP'
                                destinationPortRange = '3389'
                                sourceAddressPrefix = '*'
                            }
                        },
                        @{
                            name = 'AllowSSH'
                            properties = @{
                                direction = 'Inbound'
                                access = 'Allow'
                                protocol = 'TCP'
                                destinationPortRange = '22'
                                sourceAddressPrefix = '0.0.0.0/0'
                            }
                        }
                    )
                } | ConvertTo-Json -Depth 10 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $nsgId
                        Type = 'microsoft.network/networksecuritygroups'
                        Name = 'nsg1'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $nsgProps
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                # Only 1 edge per NSG (aggregated), not 1 per rule
                $edges = Get-CIEMGraphEdge -Kind 'AllowsInbound'
                $edges | Should -HaveCount 1
                $edges[0].SourceId | Should -Be '__internet__'
                $edges[0].TargetId | Should -Be $nsgId

                $edgeProps = $edges[0].Properties | ConvertFrom-Json
                $edgeProps.open_ports | Should -HaveCount 2
                $edgeProps.open_ports[0].port | Should -Be '3389'
                $edgeProps.open_ports[1].port | Should -Be '22'
            }
        }

        It 'Creates AllowsInbound edge with destinationPortRanges (plural array) ports' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
                Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

                $nsgId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg-plural'

                Save-CIEMGraphNode -Id '__internet__' -Kind 'Internet' -DisplayName 'Internet' -Provider 'global'
                Save-CIEMGraphNode -Id $nsgId -Kind 'AzureNSG' -DisplayName 'nsg-plural' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'

                # Azure uses destinationPortRanges (plural) when multiple ports, setting singular to ''
                $nsgProps = @{
                    securityRules = @(
                        @{
                            name = 'AllowMulti'
                            properties = @{
                                direction = 'Inbound'
                                access = 'Allow'
                                protocol = 'TCP'
                                destinationPortRange = ''
                                destinationPortRanges = @('22', '3389', '5985-5986')
                                sourceAddressPrefix = '*'
                            }
                        }
                    )
                } | ConvertTo-Json -Depth 10 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $nsgId
                        Type = 'microsoft.network/networksecuritygroups'
                        Name = 'nsg-plural'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $nsgProps
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -Kind 'AllowsInbound'
                $edges | Should -HaveCount 1

                $edgeProps = $edges[0].Properties | ConvertFrom-Json
                # Should have 3 port entries from the plural array
                $edgeProps.open_ports | Should -HaveCount 3
                ($edgeProps.open_ports | Where-Object { $_.port -eq '22' }) | Should -Not -BeNullOrEmpty
                ($edgeProps.open_ports | Where-Object { $_.port -eq '3389' }) | Should -Not -BeNullOrEmpty
                ($edgeProps.open_ports | Where-Object { $_.port -eq '5985-5986' }) | Should -Not -BeNullOrEmpty
            }
        }

        It 'Creates InSubnet edges from NIC to VNet' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $nicId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkInterfaces/nic-subnet'
                $vnetId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/virtualNetworks/vnet1'

                Save-CIEMGraphNode -Id $nicId -Kind 'AzureNIC' -DisplayName 'nic-subnet' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                Save-CIEMGraphNode -Id $vnetId -Kind 'AzureVNet' -DisplayName 'vnet1' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'

                $nicProps = @{
                    ipConfigurations = @(
                        @{
                            properties = @{
                                subnet = @{ id = "$vnetId/subnets/default" }
                            }
                        }
                    )
                } | ConvertTo-Json -Depth 10 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $nicId
                        Type = 'microsoft.network/networkinterfaces'
                        Name = 'nic-subnet'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $nicProps
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -Kind 'InSubnet'
                $edges | Should -HaveCount 1
                $edges[0].SourceId | Should -Be $nicId
                $edges[0].TargetId | Should -Be $vnetId

                $edgeProps = $edges[0].Properties | ConvertFrom-Json
                $edgeProps.subnet_id | Should -Be "$vnetId/subnets/default"
            }
        }

        It 'Creates ContainedIn edges from resources to subscriptions' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $subId = '/subscriptions/sub1'
                $vmId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-contain'

                Save-CIEMGraphNode -Id $subId -Kind 'AzureSubscription' -DisplayName 'sub1' -Provider 'azure' -SubscriptionId 'sub1'
                Save-CIEMGraphNode -Id $vmId -Kind 'AzureVM' -DisplayName 'vm-contain' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $subId; Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        Id = $vmId; Type = 'microsoft.compute/virtualmachines'
                        Name = 'vm-contain'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -Kind 'ContainedIn'
                $edges | Should -HaveCount 1
                $edges[0].SourceId | Should -Be $vmId
                $edges[0].TargetId | Should -Be $subId
            }
        }

        It 'Excludes subscription-self and authorization resources from ContainedIn' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $subId = '/subscriptions/sub1'
                $raId = '/subscriptions/sub1/providers/Microsoft.Authorization/roleAssignments/ra-excl'

                Save-CIEMGraphNode -Id $subId -Kind 'AzureSubscription' -DisplayName 'sub1' -Provider 'azure' -SubscriptionId 'sub1'
                Save-CIEMGraphNode -Id $raId -Kind 'AzureRoleAssignment' -DisplayName 'ra-excl' -Provider 'azure' -SubscriptionId 'sub1'

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $subId; Type = 'microsoft.resources/subscriptions'
                        Name = 'sub1'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        Id = $raId; Type = 'microsoft.authorization/roleassignments'
                        Name = 'ra-excl'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null; Properties = $null
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -Kind 'ContainedIn'
                $edges | Should -BeNullOrEmpty
            }
        }

        It 'Sets computed = 1 on all computed edges' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                # Seed nodes for a simple HasManagedIdentity computed edge
                $vmId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-comp'
                Save-CIEMGraphNode -Id $vmId -Kind 'AzureVM' -DisplayName 'vm-comp' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                Save-CIEMGraphNode -Id 'mi-comp-1' -Kind 'EntraManagedIdentity' -DisplayName 'mi-comp' -Provider 'azure'

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $vmId
                        Type = 'microsoft.compute/virtualmachines'
                        Name = 'vm-comp'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null
                        Identity = '{"principalId":"mi-comp-1","type":"SystemAssigned"}'
                        ManagedBy = $null; Plan = $null; Zones = $null; Tags = $null
                        Properties = '{}'
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -Computed 1
                $edges | Should -Not -BeNullOrEmpty
                $edges | ForEach-Object { $_.Computed | Should -Be 1 }
            }
        }

        It 'Returns total computed edge count' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $vmId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-count'
                Save-CIEMGraphNode -Id $vmId -Kind 'AzureVM' -DisplayName 'vm-count' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                Save-CIEMGraphNode -Id 'mi-count-1' -Kind 'EntraManagedIdentity' -DisplayName 'mi-count' -Provider 'azure'

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $vmId
                        Type = 'microsoft.compute/virtualmachines'
                        Name = 'vm-count'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null
                        Identity = '{"principalId":"mi-count-1","type":"SystemAssigned"}'
                        ManagedBy = $null; Plan = $null; Zones = $null; Tags = $null
                        Properties = '{}'
                        CollectedAt = $ts
                    }
                )

                $count = InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $count | Should -BeOfType [int]
                $count | Should -BeGreaterOrEqual 1
            }
        }

        It 'Skips HasRole edges where target node does not exist' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                # Seed user node but NOT the subscription node
                Save-CIEMGraphNode -Id 'user-orphan' -Kind 'EntraUser' -DisplayName 'Orphan User' -Provider 'azure'

                $roleDefProps = @{
                    roleName = 'Reader'
                    permissions = @(@{ actions = @('*/read'); notActions = @() })
                } | ConvertTo-Json -Depth 5 -Compress

                $roleDefId = '/subscriptions/sub-x/providers/Microsoft.Authorization/roleDefinitions/rd-reader-orphan'

                $roleAssignProps = @{
                    principalId = 'user-orphan'
                    principalType = 'User'
                    roleDefinitionId = $roleDefId
                    scope = '/subscriptions/nonexistent-sub'
                } | ConvertTo-Json -Depth 5 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $roleDefId
                        Type = 'microsoft.authorization/roledefinitions'
                        Name = 'rd-reader-orphan'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub-x'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $roleDefProps
                        CollectedAt = $ts
                    },
                    [PSCustomObject]@{
                        Id = '/subscriptions/sub-x/providers/Microsoft.Authorization/roleAssignments/ra-orphan'
                        Type = 'microsoft.authorization/roleassignments'
                        Name = 'ra-orphan'; Location = $null; ResourceGroup = $null
                        SubscriptionId = 'sub-x'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $roleAssignProps
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                # No HasRole edge created because target /subscriptions/nonexistent-sub does not exist
                $edges = Get-CIEMGraphEdge -SourceId 'user-orphan' -Kind 'HasRole'
                $edges | Should -BeNullOrEmpty
            }
        }

        It 'Skips HasManagedIdentity edges where MI node does not exist' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $vmId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-nomi'
                Save-CIEMGraphNode -Id $vmId -Kind 'AzureVM' -DisplayName 'vm-nomi' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                # Deliberately NOT creating the MI node

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $vmId
                        Type = 'microsoft.compute/virtualmachines'
                        Name = 'vm-nomi'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null
                        Identity = '{"principalId":"nonexistent-mi","type":"SystemAssigned"}'
                        ManagedBy = $null; Plan = $null; Zones = $null; Tags = $null
                        Properties = '{}'
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -Kind 'HasManagedIdentity'
                $edges | Should -BeNullOrEmpty
            }
        }

        It 'Does not create AllowsInbound for outbound or deny rules' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $nsgId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg-deny'
                Save-CIEMGraphNode -Id '__internet__' -Kind 'Internet' -DisplayName 'Internet' -Provider 'global'
                Save-CIEMGraphNode -Id $nsgId -Kind 'AzureNSG' -DisplayName 'nsg-deny' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'

                $nsgProps = @{
                    securityRules = @(
                        @{
                            name = 'DenyRDP'
                            properties = @{
                                direction = 'Inbound'
                                access = 'Deny'
                                protocol = 'TCP'
                                destinationPortRange = '3389'
                                sourceAddressPrefix = '*'
                            }
                        },
                        @{
                            name = 'AllowOutbound'
                            properties = @{
                                direction = 'Outbound'
                                access = 'Allow'
                                protocol = 'TCP'
                                destinationPortRange = '443'
                                sourceAddressPrefix = '*'
                            }
                        },
                        @{
                            name = 'AllowInternalInbound'
                            properties = @{
                                direction = 'Inbound'
                                access = 'Allow'
                                protocol = 'TCP'
                                destinationPortRange = '443'
                                sourceAddressPrefix = '10.0.0.0/8'
                            }
                        }
                    )
                } | ConvertTo-Json -Depth 10 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $nsgId
                        Type = 'microsoft.network/networksecuritygroups'
                        Name = 'nsg-deny'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $nsgProps
                        CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                $edges = Get-CIEMGraphEdge -Kind 'AllowsInbound'
                $edges | Should -BeNullOrEmpty
            }
        }

        It 'Handles empty input arrays gracefully' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                $count = InvokeCIEMGraphComputedEdgeBuild -ArmResources @() -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts
                $count | Should -Be 0
            }
        }

        It 'Does NOT create NSG->VM edge when NIC has NSG but no virtualMachine reference' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
                Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

                $nicId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkInterfaces/nic-no-vm'
                $nsgId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg-no-vm'

                Save-CIEMGraphNode -Id $nicId -Kind 'AzureNIC' -DisplayName 'nic-no-vm' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                Save-CIEMGraphNode -Id $nsgId -Kind 'AzureNSG' -DisplayName 'nsg-no-vm' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'

                # NIC has NSG but no virtualMachine property
                $nicProps = @{
                    networkSecurityGroup = @{ id = $nsgId }
                } | ConvertTo-Json -Depth 5 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $nicId; Type = 'microsoft.network/networkinterfaces'
                        Name = 'nic-no-vm'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $nicProps; CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                # No NSG->VM AttachedTo edge since no VM reference exists
                $edges = Get-CIEMGraphEdge -Kind 'AttachedTo' -SourceId $nsgId
                $edges | Should -BeNullOrEmpty
            }
        }

        It 'Skips NSG->VM edge when NSG node does not exist in graph_nodes' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'
                Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
                Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

                $nicId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkInterfaces/nic-missing-nsg'
                $vmId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-missing-nsg'
                $nsgId = '/subscriptions/sub1/resourceGroups/rg1/providers/Microsoft.Network/networkSecurityGroups/nsg-not-seeded'

                Save-CIEMGraphNode -Id $nicId -Kind 'AzureNIC' -DisplayName 'nic' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                Save-CIEMGraphNode -Id $vmId -Kind 'AzureVM' -DisplayName 'vm' -Provider 'azure' -SubscriptionId 'sub1' -ResourceGroup 'rg1'
                # Deliberately NOT creating the NSG node

                $nicProps = @{
                    virtualMachine = @{ id = $vmId }
                    networkSecurityGroup = @{ id = $nsgId }
                } | ConvertTo-Json -Depth 5 -Compress

                $armResources = @(
                    [PSCustomObject]@{
                        Id = $nicId; Type = 'microsoft.network/networkinterfaces'
                        Name = 'nic'; Location = 'eastus'; ResourceGroup = 'rg1'
                        SubscriptionId = 'sub1'; TenantId = 'tenant1'
                        Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                        Plan = $null; Zones = $null; Tags = $null
                        Properties = $nicProps; CollectedAt = $ts
                    }
                )

                InvokeCIEMGraphComputedEdgeBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $null -CollectedAt $ts

                # NSG node doesn't exist so no AttachedTo edge
                $edges = Get-CIEMGraphEdge -Kind 'AttachedTo' -SourceId $nsgId
                $edges | Should -BeNullOrEmpty
            }
        }
    }

    # =========================================================================
    # Transaction-context edge building (reproduces discovery pipeline bug)
    # When nodes are inserted within a transaction, edge builders must use the
    # same connection for FK existence checks, otherwise they see empty tables.
    # =========================================================================

    Context 'InvokeCIEMGraphEdgeBuild with transaction connection' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
        }

        It 'Creates edges when nodes exist only on the transaction connection' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                # Open a transaction connection (same as InvokeCIEMTransaction)
                $conn = Open-PSUSQLiteConnection -Database $script:DatabasePath
                Invoke-PSUSQLiteQuery -Connection $conn -Query "PRAGMA foreign_keys=ON" -AsNonQuery | Out-Null
                Invoke-PSUSQLiteQuery -Connection $conn -Query "BEGIN TRANSACTION" -AsNonQuery | Out-Null

                try {
                    # Insert nodes on the transaction connection (NOT committed yet)
                    Save-CIEMGraphNode -Id 'txn-user-1' -Kind 'EntraUser' -DisplayName 'TxnUser' -Provider 'azure' -Connection $conn
                    Save-CIEMGraphNode -Id 'txn-group-1' -Kind 'EntraGroup' -DisplayName 'TxnGroup' -Provider 'azure' -Connection $conn

                    $relationships = @(
                        [PSCustomObject]@{
                            SourceId = 'txn-user-1'; SourceType = 'user'
                            TargetId = 'txn-group-1'; TargetType = 'group'
                            Relationship = 'member_of'; CollectedAt = $ts
                        }
                    )

                    # Edge builder must find the uncommitted nodes via $conn
                    $count = InvokeCIEMGraphEdgeBuild -Relationships $relationships -Connection $conn -CollectedAt $ts
                    $count | Should -Be 1

                    Invoke-PSUSQLiteQuery -Connection $conn -Query "COMMIT" -AsNonQuery | Out-Null
                }
                catch {
                    Invoke-PSUSQLiteQuery -Connection $conn -Query "ROLLBACK" -AsNonQuery | Out-Null
                    throw
                }
                finally {
                    $conn.Dispose()
                }

                # Verify edge persisted after commit
                $edges = Get-CIEMGraphEdge -SourceId 'txn-user-1' -Kind 'MemberOf'
                $edges | Should -HaveCount 1
                $edges[0].TargetId | Should -Be 'txn-group-1'
            }
        }
    }

    Context 'InvokeCIEMGraphComputedEdgeBuild with transaction connection' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
        }

        It 'Creates HasRole edges when nodes exist only on the transaction connection' {
            InModuleScope Devolutions.CIEM {
                $ts = '2026-03-31T00:00:00Z'

                $conn = Open-PSUSQLiteConnection -Database $script:DatabasePath
                Invoke-PSUSQLiteQuery -Connection $conn -Query "PRAGMA foreign_keys=ON" -AsNonQuery | Out-Null
                Invoke-PSUSQLiteQuery -Connection $conn -Query "BEGIN TRANSACTION" -AsNonQuery | Out-Null

                try {
                    # Insert nodes on the transaction connection (NOT committed yet)
                    Save-CIEMGraphNode -Id '/subscriptions/txn-sub1' -Kind 'AzureSubscription' -DisplayName 'TxnSub' -Provider 'azure' -SubscriptionId 'txn-sub1' -Connection $conn
                    Save-CIEMGraphNode -Id 'txn-principal-1' -Kind 'EntraUser' -DisplayName 'TxnUser' -Provider 'azure' -Connection $conn

                    $raProps = @{
                        principalId      = 'txn-principal-1'
                        principalType    = 'User'
                        roleDefinitionId = '/providers/Microsoft.Authorization/roleDefinitions/txn-roledef-1'
                        scope            = '/subscriptions/txn-sub1'
                    } | ConvertTo-Json -Compress

                    $roleDefProps = @{
                        roleName    = 'Contributor'
                        permissions = @(@{ actions = @('*'); notActions = @() })
                    } | ConvertTo-Json -Depth 5 -Compress

                    $armResources = @(
                        [PSCustomObject]@{
                            Id = '/subscriptions/txn-sub1'; Type = 'microsoft.resources/subscriptions'
                            Name = 'TxnSub'; Location = ''; ResourceGroup = ''
                            SubscriptionId = 'txn-sub1'; TenantId = 'tenant1'
                            Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                            Plan = $null; Zones = $null; Tags = $null
                            Properties = $null; CollectedAt = $ts
                        },
                        [PSCustomObject]@{
                            Id = '/providers/Microsoft.Authorization/roleDefinitions/txn-roledef-1'
                            Type = 'microsoft.authorization/roledefinitions'
                            Name = 'Contributor'; Location = ''; ResourceGroup = ''
                            SubscriptionId = 'txn-sub1'; TenantId = 'tenant1'
                            Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                            Plan = $null; Zones = $null; Tags = $null
                            Properties = $roleDefProps; CollectedAt = $ts
                        },
                        [PSCustomObject]@{
                            Id = '/subscriptions/txn-sub1/providers/Microsoft.Authorization/roleAssignments/txn-ra-1'
                            Type = 'microsoft.authorization/roleassignments'
                            Name = 'txn-ra-1'; Location = ''; ResourceGroup = ''
                            SubscriptionId = 'txn-sub1'; TenantId = 'tenant1'
                            Kind = $null; Sku = $null; Identity = $null; ManagedBy = $null
                            Plan = $null; Zones = $null; Tags = $null
                            Properties = $raProps; CollectedAt = $ts
                        }
                    )

                    # Computed edge builder must find the uncommitted nodes via $conn
                    $count = InvokeCIEMGraphComputedEdgeBuild `
                        -ArmResources $armResources `
                        -EntraResources @() `
                        -Relationships @() `
                        -Connection $conn `
                        -CollectedAt $ts
                    $count | Should -BeGreaterThan 0

                    Invoke-PSUSQLiteQuery -Connection $conn -Query "COMMIT" -AsNonQuery | Out-Null
                }
                catch {
                    Invoke-PSUSQLiteQuery -Connection $conn -Query "ROLLBACK" -AsNonQuery | Out-Null
                    throw
                }
                finally {
                    $conn.Dispose()
                }

                # Verify HasRole edge persisted after commit
                $edges = Get-CIEMGraphEdge -SourceId 'txn-principal-1' -Kind 'HasRole'
                $edges | Should -HaveCount 1
                $edges[0].TargetId | Should -Be '/subscriptions/txn-sub1'
            }
        }
    }
}
