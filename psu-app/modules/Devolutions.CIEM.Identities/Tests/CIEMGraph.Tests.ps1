BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Devolutions.CIEM.Identities.psd1') -Force
}

Describe 'CIEMGraph class' {

    Context 'Node operations' {
        It 'Can add and retrieve a node' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()
                $node = [CIEMEntraUser]::new()
                $node.Id = 'test-user'
                $node.DisplayName = 'Test User'
                $graph.AddNode($node)

                $retrieved = $graph.GetNode('test-user')
                $retrieved | Should -Not -BeNull
                $retrieved.DisplayName | Should -Be 'Test User'
            }
        }

        It 'Deduplicates nodes by ID' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()
                $node1 = [CIEMEntraUser]::new()
                $node1.Id = 'same-id'
                $node1.DisplayName = 'First'
                $graph.AddNode($node1)

                $node2 = [CIEMEntraUser]::new()
                $node2.Id = 'same-id'
                $node2.DisplayName = 'Second'
                $graph.AddNode($node2)

                $graph.Nodes.Count | Should -Be 1
                $graph.GetNode('same-id').DisplayName | Should -Be 'Second'
            }
        }

        It 'Returns null for missing node' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()
                $graph.GetNode('nonexistent') | Should -BeNull
            }
        }

        It 'Filters nodes by type' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()

                $user = [CIEMEntraUser]::new()
                $user.Id = 'user1'
                $graph.AddNode($user)

                $group = [CIEMEntraGroup]::new()
                $group.Id = 'group1'
                $graph.AddNode($group)

                $users = $graph.GetNodesByType([CIEMGraphNodeType]::EntraUser)
                $users.Count | Should -Be 1
                $users[0].Id | Should -Be 'user1'
            }
        }
    }

    Context 'Edge operations' {
        It 'Can add and query edges from a node' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()

                $user = [CIEMEntraUser]::new(); $user.Id = 'u1'; $graph.AddNode($user)
                $group = [CIEMEntraGroup]::new(); $group.Id = 'g1'; $graph.AddNode($group)

                $graph.AddEdge('u1', 'g1', [CIEMGraphRelationship]::MEMBER_OF)

                $edges = $graph.GetEdgesFrom('u1')
                $edges.Count | Should -Be 1
                $edges[0].TargetId | Should -Be 'g1'
                $edges[0].Relationship | Should -Be ([CIEMGraphRelationship]::MEMBER_OF)
            }
        }

        It 'Can query edges to a node' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()

                $user = [CIEMEntraUser]::new(); $user.Id = 'u1'; $graph.AddNode($user)
                $group = [CIEMEntraGroup]::new(); $group.Id = 'g1'; $graph.AddNode($group)

                $graph.AddEdge('u1', 'g1', [CIEMGraphRelationship]::MEMBER_OF)

                $edges = $graph.GetEdgesTo('g1')
                $edges.Count | Should -Be 1
                $edges[0].SourceId | Should -Be 'u1'
            }
        }

        It 'Can filter edges by relationship' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()

                $user = [CIEMEntraUser]::new(); $user.Id = 'u1'; $graph.AddNode($user)
                $group = [CIEMEntraGroup]::new(); $group.Id = 'g1'; $graph.AddNode($group)

                $graph.AddEdge('u1', 'g1', [CIEMGraphRelationship]::MEMBER_OF)
                $graph.AddEdge('u1', 'g1', [CIEMGraphRelationship]::OWNER_OF)

                $memberEdges = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::MEMBER_OF)
                $memberEdges.Count | Should -Be 1

                $ownerEdges = $graph.GetEdgesByRelationship([CIEMGraphRelationship]::OWNER_OF)
                $ownerEdges.Count | Should -Be 1
            }
        }
    }

    Context 'Traversal' {
        It 'Traverses a single-hop chain' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()

                $user = [CIEMEntraUser]::new(); $user.Id = 'u1'; $graph.AddNode($user)
                $group = [CIEMEntraGroup]::new(); $group.Id = 'g1'; $group.DisplayName = 'Admins'; $graph.AddNode($group)

                $graph.AddEdge('u1', 'g1', [CIEMGraphRelationship]::MEMBER_OF)

                $result = $graph.Traverse('u1', @([CIEMGraphRelationship]::MEMBER_OF))
                $result.Count | Should -Be 1
                $result[0].Id | Should -Be 'g1'
            }
        }

        It 'Traverses a multi-hop chain' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()

                $user = [CIEMEntraUser]::new(); $user.Id = 'u1'; $graph.AddNode($user)
                $ra = [CIEMAzureRoleAssignment]::new(); $ra.Id = 'ra1'; $graph.AddNode($ra)
                $rd = [CIEMAzureRoleDefinition]::new(); $rd.Id = 'rd1'; $rd.RoleName = 'Contributor'; $graph.AddNode($rd)

                $graph.AddEdge('u1', 'ra1', [CIEMGraphRelationship]::HAS_ROLE_ASSIGNMENT)
                $graph.AddEdge('ra1', 'rd1', [CIEMGraphRelationship]::USES_ROLE)

                $result = $graph.Traverse('u1', @([CIEMGraphRelationship]::HAS_ROLE_ASSIGNMENT, [CIEMGraphRelationship]::USES_ROLE))
                $result.Count | Should -Be 1
                $result[0].RoleName | Should -Be 'Contributor'
            }
        }

        It 'Returns empty for broken chain' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()

                $user = [CIEMEntraUser]::new(); $user.Id = 'u1'; $graph.AddNode($user)

                $result = $graph.Traverse('u1', @([CIEMGraphRelationship]::HAS_ROLE_ASSIGNMENT))
                $result.Count | Should -Be 0
            }
        }
    }

    Context 'Serialization round-trip' {
        It 'Serializes and deserializes correctly' {
            InModuleScope Devolutions.CIEM.Identities {
                $graph = [CIEMGraph]::new()
                $graph.TenantId = 'test-tenant'
                $graph.SubscriptionIds = @('sub1', 'sub2')

                $user = [CIEMEntraUser]::new()
                $user.Id = 'u1'
                $user.DisplayName = 'Test User'
                $user.UserPrincipalName = 'test@contoso.com'
                $user.AccountEnabled = $true
                $graph.AddNode($user)

                $group = [CIEMEntraGroup]::new()
                $group.Id = 'g1'
                $group.DisplayName = 'Test Group'
                $group.SecurityEnabled = $true
                $graph.AddNode($group)

                $graph.AddEdge('u1', 'g1', [CIEMGraphRelationship]::MEMBER_OF)

                # Serialize
                $serialized = $graph.ToPSCustomObject()

                # Simulate PSU cache round-trip (ConvertTo-Json -> ConvertFrom-Json)
                $json = $serialized | ConvertTo-Json -Depth 10
                $deserialized = $json | ConvertFrom-Json

                # Reconstruct
                $rebuilt = [CIEMGraph]::FromPSCustomObject($deserialized)

                $rebuilt.TenantId | Should -Be 'test-tenant'
                $rebuilt.SubscriptionIds.Count | Should -Be 2
                $rebuilt.Nodes.Count | Should -Be 2
                $rebuilt.Edges.Count | Should -Be 1

                $rebuiltUser = $rebuilt.GetNode('u1')
                $rebuiltUser | Should -Not -BeNull
                $rebuiltUser.GetType().Name | Should -Be 'CIEMEntraUser'
                $rebuiltUser.DisplayName | Should -Be 'Test User'

                $rebuiltEdge = $rebuilt.GetEdgesFrom('u1')
                $rebuiltEdge.Count | Should -Be 1
                $rebuiltEdge[0].Relationship | Should -Be ([CIEMGraphRelationship]::MEMBER_OF)
            }
        }
    }
}
