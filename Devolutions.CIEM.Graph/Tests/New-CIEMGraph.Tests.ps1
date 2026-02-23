BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Devolutions.CIEM.Graph.psd1') -Force
}

Describe 'New-CIEMGraph' {

    BeforeAll {
        # Mock Entra data simulating service cache output
        $script:mockEntraData = @{
            Users = @(
                @{ id = 'user1'; displayName = 'Alice Admin'; userPrincipalName = 'alice@contoso.com'; accountEnabled = $true; userType = 'Member'; department = 'IT'; jobTitle = 'Admin'; manager = @{ id = 'user2' } }
                @{ id = 'user2'; displayName = 'Bob Boss'; userPrincipalName = 'bob@contoso.com'; accountEnabled = $true; userType = 'Member'; department = 'IT'; jobTitle = 'Manager'; manager = $null }
            )
            Groups = @(
                @{ id = 'group1'; displayName = 'IT Admins'; securityEnabled = $true; isAssignableToRole = $true; groupTypes = @(); visibility = 'Private' }
            )
            GroupMembers = @{
                'group1' = @(
                    @{ id = 'user1'; displayName = 'Alice Admin'; '@odata.type' = '#microsoft.graph.user' }
                )
            }
            GroupOwners = @{
                'group1' = @(
                    @{ id = 'user2'; displayName = 'Bob Boss'; '@odata.type' = '#microsoft.graph.user' }
                )
            }
            ServicePrincipals = @(
                @{ id = 'sp1'; appId = 'app1-id'; displayName = 'MyApp SP'; servicePrincipalType = 'Application'; accountEnabled = $true; signInAudience = 'AzureADMyOrg'; tags = @() }
            )
            Applications = @(
                @{ id = 'app1'; appId = 'app1-id'; displayName = 'MyApp'; publisherDomain = 'contoso.com'; signInAudience = 'AzureADMyOrg' }
            )
            AppRoleAssignments = @{
                'sp1' = @(
                    @{ id = 'ara1'; appRoleId = 'role1'; principalId = 'user1'; principalType = 'User'; principalDisplayName = 'Alice Admin'; resourceId = 'sp1'; resourceDisplayName = 'MyApp SP'; createdDateTime = '2024-01-01T00:00:00Z' }
                )
            }
        }

        # Mock IAM data simulating per-subscription cache
        $script:mockIAMData = @{
            'sub-001' = @{
                RoleAssignments = @(
                    @{
                        id = '/subscriptions/sub-001/providers/Microsoft.Authorization/roleAssignments/ra1'
                        properties = @{
                            principalId = 'user1'
                            principalType = 'User'
                            roleDefinitionId = '/subscriptions/sub-001/providers/Microsoft.Authorization/roleDefinitions/rd1'
                            scope = '/subscriptions/sub-001'
                            condition = $null
                            createdBy = 'system'
                            updatedBy = 'system'
                        }
                    }
                )
                RoleDefinitions = @(
                    @{
                        id = '/subscriptions/sub-001/providers/Microsoft.Authorization/roleDefinitions/rd1'
                        properties = @{
                            roleName = 'Contributor'
                            description = 'Lets you manage everything except access'
                            assignableScopes = @('/')
                            type = 'BuiltInRole'
                            permissions = @(
                                @{
                                    actions = @('*')
                                    notActions = @('Microsoft.Authorization/*/Delete', 'Microsoft.Authorization/*/Write', 'Microsoft.Authorization/elevateAccess/Action')
                                    dataActions = @()
                                    notDataActions = @()
                                }
                            )
                        }
                    }
                )
            }
        }
    }

    Context 'Node creation' {
        It 'Creates user nodes from Entra data' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                $users = $graph.GetNodesByType([CIEMGraphNodeType]::EntraUser)
                $users.Count | Should -Be 2
            }
        }

        It 'Creates group nodes' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                $groups = $graph.GetNodesByType([CIEMGraphNodeType]::EntraGroup)
                $groups.Count | Should -Be 1
                $groups[0].DisplayName | Should -Be 'IT Admins'
            }
        }

        It 'Creates service principal and application nodes' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                ($graph.GetNodesByType([CIEMGraphNodeType]::EntraServicePrincipal)).Count | Should -Be 1
                ($graph.GetNodesByType([CIEMGraphNodeType]::EntraApplication)).Count | Should -Be 1
            }
        }

        It 'Creates role assignment and definition nodes from IAM data' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData; IAMData = $script:mockIAMData } {
                param($EntraData, $IAMData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData $IAMData -TenantId 'tenant1'
                ($graph.GetNodesByType([CIEMGraphNodeType]::AzureRoleAssignment)).Count | Should -Be 1
                ($graph.GetNodesByType([CIEMGraphNodeType]::AzureRoleDefinition)).Count | Should -Be 1
            }
        }

        It 'Creates permission nodes from role definitions' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData; IAMData = $script:mockIAMData } {
                param($EntraData, $IAMData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData $IAMData -TenantId 'tenant1'
                ($graph.GetNodesByType([CIEMGraphNodeType]::AzurePermissions)).Count | Should -Be 1
            }
        }

        It 'Handles empty Entra data gracefully' {
            InModuleScope Devolutions.CIEM.Graph {
                $emptyData = @{ Users = @(); Groups = @(); ServicePrincipals = @(); Applications = @() }
                $graph = New-CIEMGraph -EntraData $emptyData -IAMData @{} -TenantId 'tenant1'
                $graph.Nodes.Count | Should -Be 0
            }
        }

        It 'Handles null Entra data fields gracefully' {
            InModuleScope Devolutions.CIEM.Graph {
                $nullData = @{ Users = $null; Groups = $null; ServicePrincipals = $null; Applications = $null }
                $graph = New-CIEMGraph -EntraData $nullData -IAMData @{} -TenantId 'tenant1'
                $graph.Nodes.Count | Should -Be 0
            }
        }
    }

    Context 'Identity edges' {
        It 'Creates REPORTS_TO edge for user with manager' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                $reportsTo = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::REPORTS_TO)
                $reportsTo.Count | Should -Be 1
                $reportsTo[0].SourceId | Should -Be 'user1'
                $reportsTo[0].TargetId | Should -Be 'user2'
            }
        }

        It 'Creates MEMBER_OF edge for group membership' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                $memberOf = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::MEMBER_OF)
                $memberOf.Count | Should -Be 1
                $memberOf[0].SourceId | Should -Be 'user1'
                $memberOf[0].TargetId | Should -Be 'group1'
            }
        }

        It 'Creates OWNER_OF edge for group ownership' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                $ownerOf = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::OWNER_OF)
                $ownerOf.Count | Should -Be 1
                $ownerOf[0].SourceId | Should -Be 'user2'
                $ownerOf[0].TargetId | Should -Be 'group1'
            }
        }

        It 'Creates HAS_SERVICE_PRINCIPAL edge linking app to SP' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                $hasSP = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::HAS_SERVICE_PRINCIPAL)
                $hasSP.Count | Should -Be 1
                $hasSP[0].SourceId | Should -Be 'app1'
                $hasSP[0].TargetId | Should -Be 'sp1'
            }
        }
    }

    Context 'RBAC edges' {
        It 'Creates HAS_ROLE_ASSIGNMENT edge from identity to role assignment' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData; IAMData = $script:mockIAMData } {
                param($EntraData, $IAMData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData $IAMData -TenantId 'tenant1'
                $hasRA = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::HAS_ROLE_ASSIGNMENT)
                $hasRA.Count | Should -Be 1
                $hasRA[0].SourceId | Should -Be 'user1'
            }
        }

        It 'Creates USES_ROLE edge from role assignment to role definition' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData; IAMData = $script:mockIAMData } {
                param($EntraData, $IAMData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData $IAMData -TenantId 'tenant1'
                $usesRole = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::USES_ROLE)
                $usesRole.Count | Should -Be 1
            }
        }

        It 'Creates HAS_PERMISSIONS edge from role definition to permissions' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData; IAMData = $script:mockIAMData } {
                param($EntraData, $IAMData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData $IAMData -TenantId 'tenant1'
                $hasPerms = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::HAS_PERMISSIONS)
                $hasPerms.Count | Should -Be 1
            }
        }
    }

    Context 'App role edges' {
        It 'Creates HAS_APP_ROLE edge from resource SP to assignment' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                $hasAppRole = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::HAS_APP_ROLE)
                $hasAppRole.Count | Should -Be 1
                $hasAppRole[0].SourceId | Should -Be 'sp1'
            }
        }

        It 'Creates ASSIGNED_TO edge from assignment to principal' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                $assignedTo = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::ASSIGNED_TO)
                $assignedTo.Count | Should -Be 1
                $assignedTo[0].TargetId | Should -Be 'user1'
            }
        }
    }

    Context 'Graph metadata' {
        It 'Sets TenantId' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                $graph.TenantId | Should -Be 'tenant1'
            }
        }

        It 'Sets SubscriptionIds from IAM data keys' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData; IAMData = $script:mockIAMData } {
                param($EntraData, $IAMData)
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData $IAMData -TenantId 'tenant1'
                $graph.SubscriptionIds | Should -Contain 'sub-001'
            }
        }

        It 'Sets BuildTime' {
            InModuleScope Devolutions.CIEM.Graph -Parameters @{ EntraData = $script:mockEntraData } {
                param($EntraData)
                $before = [datetime]::UtcNow
                $graph = New-CIEMGraph -EntraData $EntraData -IAMData @{} -TenantId 'tenant1'
                $after = [datetime]::UtcNow
                $graph.BuildTime | Should -BeGreaterOrEqual $before
                $graph.BuildTime | Should -BeLessOrEqual $after
            }
        }
    }
}
