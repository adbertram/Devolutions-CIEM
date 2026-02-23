BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Devolutions.CIEM.Graph.psd1') -Force
}

Describe 'ConvertTo-CIEMGraphMermaid' {

    BeforeAll {
        # Build a graph with known identities and permissions via InModuleScope
        # so we can use module-scoped classes (CIEMGraph, CIEMEntraUser, etc.)
        $script:testGraphData = InModuleScope Devolutions.CIEM.Graph {
            $graph = [CIEMGraph]::new()
            $graph.TenantId = 'test-tenant'

            # Users
            $alice = [CIEMEntraUser]::new()
            $alice.Id = 'user1'
            $alice.DisplayName = 'Alice Admin'
            $alice.UserPrincipalName = 'alice@corp.com'
            $graph.AddNode($alice)

            $bob = [CIEMEntraUser]::new()
            $bob.Id = 'user2'
            $bob.DisplayName = 'Bob Reader'
            $bob.UserPrincipalName = 'bob@corp.com'
            $graph.AddNode($bob)

            $charlie = [CIEMEntraUser]::new()
            $charlie.Id = 'user3'
            $charlie.DisplayName = 'Charlie Member'
            $charlie.UserPrincipalName = 'charlie@corp.com'
            $graph.AddNode($charlie)

            # Group
            $itAdmins = [CIEMEntraGroup]::new()
            $itAdmins.Id = 'group1'
            $itAdmins.DisplayName = 'IT-Admins'
            $graph.AddNode($itAdmins)

            # Service Principal
            $deploySP = [CIEMEntraServicePrincipal]::new()
            $deploySP.Id = 'sp1'
            $deploySP.DisplayName = 'Deploy-SP'
            $graph.AddNode($deploySP)

            # Group membership: charlie is MEMBER_OF IT-Admins
            $graph.AddEdge('user3', 'group1', [CIEMGraphRelationship]::MEMBER_OF)

            # Permission edges to KeyVault
            $manageEdge1 = [CIEMGraphEdge]::new('user1', 'type:KeyVault', [CIEMGraphRelationship]::CAN_MANAGE)
            $manageEdge1.Properties['scopes'] = @('/subscriptions/sub1')
            $graph.AddEdge($manageEdge1)

            $manageEdge2 = [CIEMGraphEdge]::new('group1', 'type:KeyVault', [CIEMGraphRelationship]::CAN_MANAGE)
            $manageEdge2.Properties['scopes'] = @('/subscriptions/sub1')
            $graph.AddEdge($manageEdge2)

            $writeEdge = [CIEMGraphEdge]::new('sp1', 'type:KeyVault', [CIEMGraphRelationship]::CAN_WRITE)
            $writeEdge.Properties['scopes'] = @('/subscriptions/sub1')
            $graph.AddEdge($writeEdge)

            $readEdge = [CIEMGraphEdge]::new('user2', 'type:KeyVault', [CIEMGraphRelationship]::CAN_READ)
            $readEdge.Properties['scopes'] = @('/subscriptions/sub1')
            $graph.AddEdge($readEdge)

            # Also add alice as direct CAN_MANAGE to test dedup (she appears both directly and won't be via group, but charlie is via group)
            # Permission edge to SqlServer (for testing different target type)
            $sqlEdge = [CIEMGraphEdge]::new('user1', 'type:SqlServer', [CIEMGraphRelationship]::CAN_READ)
            $sqlEdge.Properties['scopes'] = @('/subscriptions/sub1')
            $graph.AddEdge($sqlEdge)

            $graph.ToPSCustomObject()
        }
    }

    Context 'Diagram header' {
        It 'Renders correct graph TD header by default' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match '^graph TD'
        }

        It 'Renders correct direction when specified' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault' -Direction 'LR'
            $result | Should -Match '^graph LR'
        }
    }

    Context 'Root node' {
        It 'Creates root node for resource type' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'R\["KeyVault"\]'
        }

        It 'Applies resource classDef style' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'classDef resource fill:#DE3618'
        }

        It 'Assigns resource class to root node' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'class R[\s,].*resource'
        }
    }

    Context 'Identity nodes' {
        It 'Creates user node with DisplayName label' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'User: Alice Admin'
        }

        It 'Creates group node with DisplayName label' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'Group: IT-Admins'
        }

        It 'Creates service principal node with display name prefix' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'Service Principal: Deploy-SP'
        }
    }

    Context 'Permission edges' {
        It 'Creates CAN_MANAGE edges with label' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'R -->|CAN_MANAGE|'
        }

        It 'Creates CAN_WRITE edge with label' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'R -->|CAN_WRITE|'
        }

        It 'Creates CAN_READ edge with label' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'R -->|CAN_READ|'
        }
    }

    Context 'Group membership expansion' {
        It 'Expands group membership with dashed MEMBER_OF edges' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match '-.->|MEMBER_OF|'
        }

        It 'Creates member node for group member (Charlie)' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'User: Charlie Member'
        }
    }

    Context 'Category styles' {
        It 'Applies entrauser classDef style' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'classDef entrauser fill:#4A90D9'
        }

        It 'Applies entragroup classDef style' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'classDef entragroup fill:#50B83C'
        }

        It 'Applies entraserviceprincipal classDef style' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'KeyVault'
            $result | Should -Match 'classDef entraserviceprincipal fill:#F49342'
        }
    }

    Context 'Empty results' {
        It 'Handles resource type with no identities' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:testGraphData -TargetType 'CosmosDB'
            $result | Should -Match '^graph TD'
            $result | Should -Match 'R\["CosmosDB"\]'
            $result | Should -Not -Match '-->'
        }
    }

    Context 'Node deduplication' {
        BeforeAll {
            # Build a graph where alice appears both directly AND via group membership
            $script:dedupGraphData = InModuleScope Devolutions.CIEM.Graph {
                $graph = [CIEMGraph]::new()
                $graph.TenantId = 'test-tenant'

                $alice = [CIEMEntraUser]::new()
                $alice.Id = 'user1'
                $alice.DisplayName = 'Alice Admin'
                $alice.UserPrincipalName = 'alice@corp.com'
                $graph.AddNode($alice)

                $grp = [CIEMEntraGroup]::new()
                $grp.Id = 'group1'
                $grp.DisplayName = 'Admins'
                $graph.AddNode($grp)

                # Alice is a member of Admins
                $graph.AddEdge('user1', 'group1', [CIEMGraphRelationship]::MEMBER_OF)

                # Alice has direct CAN_MANAGE on KeyVault
                $directEdge = [CIEMGraphEdge]::new('user1', 'type:KeyVault', [CIEMGraphRelationship]::CAN_MANAGE)
                $directEdge.Properties['scopes'] = @('/sub1')
                $graph.AddEdge($directEdge)

                # Admins group also has CAN_MANAGE on KeyVault
                $groupEdge = [CIEMGraphEdge]::new('group1', 'type:KeyVault', [CIEMGraphRelationship]::CAN_MANAGE)
                $groupEdge.Properties['scopes'] = @('/sub1')
                $graph.AddEdge($groupEdge)

                $graph.ToPSCustomObject()
            }
        }

        It 'Shows both direct and inherited paths but renders user node only once' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:dedupGraphData -TargetType 'KeyVault'
            # Alice should appear as a node definition exactly once
            $aliceMatches = [regex]::Matches($result, 'User: Alice Admin')
            $aliceMatches.Count | Should -Be 1

            # But both paths should exist: direct (R-->alice) and inherited (group-.->alice)
            $result | Should -Match 'R -->|CAN_MANAGE|'
            $result | Should -Match '-.->|MEMBER_OF|'
        }
    }

    Context 'Label sanitization' {
        BeforeAll {
            $script:specialCharData = InModuleScope Devolutions.CIEM.Graph {
                $graph = [CIEMGraph]::new()
                $graph.TenantId = 'test-tenant'

                $user = [CIEMEntraUser]::new()
                $user.Id = 'user1'
                $user.DisplayName = 'User "Test" <Admin>'
                $user.UserPrincipalName = 'test@corp.com'
                $graph.AddNode($user)

                $edge = [CIEMGraphEdge]::new('user1', 'type:KeyVault', [CIEMGraphRelationship]::CAN_READ)
                $edge.Properties['scopes'] = @('/sub1')
                $graph.AddEdge($edge)

                $graph.ToPSCustomObject()
            }
        }

        It 'Sanitizes special characters in node labels' {
            $result = ConvertTo-CIEMGraphMermaid -Data $script:specialCharData -TargetType 'KeyVault'
            # Should not contain raw quotes or angle brackets
            $result | Should -Not -Match 'User "Test"'
            $result | Should -Not -Match '<Admin>'
            # Should contain sanitized version
            $result | Should -Match 'User _Test_ _Admin_'
        }
    }
}
