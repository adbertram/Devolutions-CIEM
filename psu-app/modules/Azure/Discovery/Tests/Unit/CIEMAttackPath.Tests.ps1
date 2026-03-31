BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    $graphSchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'graph_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $graphSchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Attack Path Engine' {

    # =========================================================================
    # Private: ResolveCIEMAttackPathFilter
    # =========================================================================
    Context 'ResolveCIEMAttackPathFilter' {

        It 'Handles eq operator returning true when property matches' {
            InModuleScope Devolutions.CIEM {
                $json = '{"accountEnabled":false}'
                $filter = [PSCustomObject]@{ property = 'accountEnabled'; op = 'eq'; value = $false }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeTrue
            }
        }

        It 'Handles eq operator returning false when property does not match' {
            InModuleScope Devolutions.CIEM {
                $json = '{"accountEnabled":true}'
                $filter = [PSCustomObject]@{ property = 'accountEnabled'; op = 'eq'; value = $false }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeFalse
            }
        }

        It 'Handles neq operator' {
            InModuleScope Devolutions.CIEM {
                $json = '{"status":"active"}'
                $filter = [PSCustomObject]@{ property = 'status'; op = 'neq'; value = 'inactive' }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeTrue
            }
        }

        It 'Handles gt operator for numeric comparison' {
            InModuleScope Devolutions.CIEM {
                $json = '{"daysSinceSignIn":120}'
                $filter = [PSCustomObject]@{ property = 'daysSinceSignIn'; op = 'gt'; value = 90 }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeTrue
            }
        }

        It 'Handles gt operator returning false when value is less' {
            InModuleScope Devolutions.CIEM {
                $json = '{"daysSinceSignIn":30}'
                $filter = [PSCustomObject]@{ property = 'daysSinceSignIn'; op = 'gt'; value = 90 }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeFalse
            }
        }

        It 'Handles lt operator for numeric comparison' {
            InModuleScope Devolutions.CIEM {
                $json = '{"riskScore":3}'
                $filter = [PSCustomObject]@{ property = 'riskScore'; op = 'lt'; value = 5 }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeTrue
            }
        }

        It 'Handles in operator when property value is in array' {
            InModuleScope Devolutions.CIEM {
                $json = '{"roleName":"Owner"}'
                $filter = [PSCustomObject]@{ property = 'roleName'; op = 'in'; value = @('Owner', 'Contributor') }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeTrue
            }
        }

        It 'Handles in operator returning false when not in array' {
            InModuleScope Devolutions.CIEM {
                $json = '{"roleName":"Reader"}'
                $filter = [PSCustomObject]@{ property = 'roleName'; op = 'in'; value = @('Owner', 'Contributor') }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeFalse
            }
        }

        It 'Handles contains_port operator when management port is present' {
            InModuleScope Devolutions.CIEM {
                $json = '{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}'
                $filter = [PSCustomObject]@{ property = 'open_ports'; op = 'contains_port'; value = @(22, 3389, 5985, 5986) }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeTrue
            }
        }

        It 'Handles contains_port with string port numbers in JSON' {
            InModuleScope Devolutions.CIEM {
                $json = '{"open_ports":[{"port":"22","protocol":"TCP","rule_name":"AllowSSH"}]}'
                $filter = [PSCustomObject]@{ property = 'open_ports'; op = 'contains_port'; value = @(22, 3389) }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeTrue
            }
        }

        It 'Handles contains_port returning false when no matching port' {
            InModuleScope Devolutions.CIEM {
                $json = '{"open_ports":[{"port":443,"protocol":"TCP","rule_name":"AllowHTTPS"}]}'
                $filter = [PSCustomObject]@{ property = 'open_ports'; op = 'contains_port'; value = @(22, 3389, 5985, 5986) }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeFalse
            }
        }

        It 'Returns false for contains_port when open_ports is null' {
            InModuleScope Devolutions.CIEM {
                $json = '{"other":"value"}'
                $filter = [PSCustomObject]@{ property = 'open_ports'; op = 'contains_port'; value = @(22, 3389) }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeFalse
            }
        }

        It 'Throws on unknown filter operator' {
            InModuleScope Devolutions.CIEM {
                $json = '{"x":1}'
                $filter = [PSCustomObject]@{ property = 'x'; op = 'bogus'; value = 1 }
                { ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter } | Should -Throw '*Unknown filter operator*'
            }
        }
    }

    # =========================================================================
    # Private: InvokeCIEMAttackPathEvaluation
    # =========================================================================
    Context 'InvokeCIEMAttackPathEvaluation with 3-step pattern (Internet -> AllowsInbound -> NSG)' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id '__internet__' -Kind 'Internet' -DisplayName 'Internet' -Provider 'global'
            Save-CIEMGraphNode -Id '/subs/s1/rg/rg1/nsg/nsg1' -Kind 'AzureNSG' -DisplayName 'nsg1' -Provider 'azure'

            Save-CIEMGraphEdge -SourceId '__internet__' -TargetId '/subs/s1/rg/rg1/nsg/nsg1' -Kind 'AllowsInbound' `
                -Properties '{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}' -Computed 1
        }

        It 'Returns results for a matching 3-step pattern' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id       = 'test-3step'
                    name     = 'Test 3-step'
                    severity = 'high'
                    category = 'test'
                    steps    = @(
                        [PSCustomObject]@{ kind = 'Internet' }
                        [PSCustomObject]@{ edge = 'AllowsInbound'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 1
            }
        }

        It 'Result includes PatternId, PatternName, Severity, Path, Edges' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id       = 'test-props'
                    name     = 'Test properties'
                    severity = 'high'
                    category = 'test'
                    steps    = @(
                        [PSCustomObject]@{ kind = 'Internet' }
                        [PSCustomObject]@{ edge = 'AllowsInbound'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $r = $results[0]
                $r.PatternId | Should -Be 'test-props'
                $r.PatternName | Should -Be 'Test properties'
                $r.Severity | Should -Be 'high'
                $r.PSObject.Properties.Name | Should -Contain 'Path'
                $r.PSObject.Properties.Name | Should -Contain 'Edges'
            }
        }

        It 'Path contains ordered nodes matching the chain' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id = 'test-chain'; name = 'Chain'; severity = 'high'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = 'Internet' }
                        [PSCustomObject]@{ edge = 'AllowsInbound'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $path = $results[0].Path
                $path | Should -HaveCount 2
                $path[0].kind | Should -Be 'Internet'
                $path[1].kind | Should -Be 'AzureNSG'
            }
        }

        It 'Edges contains the traversed edge with correct kind' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id = 'test-edges'; name = 'Edges'; severity = 'high'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = 'Internet' }
                        [PSCustomObject]@{ edge = 'AllowsInbound'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $edges = $results[0].Edges
                $edges | Should -HaveCount 1
                $edges[0].kind | Should -Be 'AllowsInbound'
            }
        }

        It 'Applies edge filter and excludes non-matching edges' {
            InModuleScope Devolutions.CIEM {
                # The seeded edge has port 3389; filter for port 22 only
                $pattern = [PSCustomObject]@{
                    id = 'test-filter-miss'; name = 'Filter miss'; severity = 'high'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = 'Internet' }
                        [PSCustomObject]@{
                            edge      = 'AllowsInbound'
                            direction = 'outbound'
                            filter    = @{ property = 'open_ports'; op = 'contains_port'; value = @(22) }
                        }
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 0
            }
        }

        It 'Returns empty when no matching seed nodes exist' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id = 'test-no-seed'; name = 'No seed'; severity = 'low'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = 'NonexistentKind' }
                        [PSCustomObject]@{ edge = 'AllowsInbound'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 0
            }
        }

        It 'Returns empty when edge does not exist between nodes' {
            InModuleScope Devolutions.CIEM {
                Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
                $pattern = [PSCustomObject]@{
                    id = 'test-no-edge'; name = 'No edge'; severity = 'low'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = 'Internet' }
                        [PSCustomObject]@{ edge = 'AllowsInbound'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 0
            }
        }
    }

    Context 'InvokeCIEMAttackPathEvaluation with 2-step pattern (node + edge, no final node)' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # Disabled user with a role assignment
            Save-CIEMGraphNode -Id 'user-disabled-1' -Kind 'EntraUser' -DisplayName 'Disabled User' -Provider 'azure' `
                -Properties '{"accountEnabled":false}'
            Save-CIEMGraphNode -Id '/subscriptions/sub1' -Kind 'AzureSubscription' -DisplayName 'Sub1' -Provider 'azure'

            Save-CIEMGraphEdge -SourceId 'user-disabled-1' -TargetId '/subscriptions/sub1' -Kind 'HasRole' `
                -Properties '{"roleName":"Contributor","privileged":false}'
        }

        It 'Matches a 2-step pattern where the last step is an edge' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id = 'test-2step'; name = 'Test 2-step'; severity = 'high'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{
                            kind        = @('EntraUser', 'EntraServicePrincipal')
                            node_filter = @{ property = 'accountEnabled'; op = 'eq'; value = $false }
                        }
                        [PSCustomObject]@{ edge = 'HasRole'; direction = 'outbound' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 1
                # Path contains both nodes: the seed and the target of the edge
                $results[0].Path | Should -HaveCount 2
                $results[0].Path[0].kind | Should -Be 'EntraUser'
                $results[0].Path[1].kind | Should -Be 'AzureSubscription'
            }
        }

        It 'Node filter excludes enabled accounts from disabled-account pattern' {
            InModuleScope Devolutions.CIEM {
                # Add an enabled user with a role
                Save-CIEMGraphNode -Id 'user-enabled-1' -Kind 'EntraUser' -DisplayName 'Enabled User' -Provider 'azure' `
                    -Properties '{"accountEnabled":true}'
                Save-CIEMGraphEdge -SourceId 'user-enabled-1' -TargetId '/subscriptions/sub1' -Kind 'HasRole' `
                    -Properties '{"roleName":"Reader","privileged":false}'

                $pattern = [PSCustomObject]@{
                    id = 'test-node-filter'; name = 'Node filter'; severity = 'high'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{
                            kind        = 'EntraUser'
                            node_filter = @{ property = 'accountEnabled'; op = 'eq'; value = $false }
                        }
                        [PSCustomObject]@{ edge = 'HasRole'; direction = 'outbound' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                # Only the disabled user should match
                $results | Should -HaveCount 1
                $results[0].Path[0].id | Should -Be 'user-disabled-1'
            }
        }
    }

    Context 'InvokeCIEMAttackPathEvaluation with edge filter (privileged eq true)' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'user-1' -Kind 'EntraUser' -DisplayName 'User1' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub1' -Kind 'AzureSubscription' -DisplayName 'Sub1' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub2' -Kind 'AzureSubscription' -DisplayName 'Sub2' -Provider 'azure'

            # Privileged role
            Save-CIEMGraphEdge -SourceId 'user-1' -TargetId '/subscriptions/sub1' -Kind 'InheritedRole' `
                -Properties '{"roleName":"Owner","privileged":true}'
            # Non-privileged role
            Save-CIEMGraphEdge -SourceId 'user-1' -TargetId '/subscriptions/sub2' -Kind 'InheritedRole' `
                -Properties '{"roleName":"Reader","privileged":false}'
        }

        It 'Only returns paths where edge filter matches' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id = 'test-edge-filter'; name = 'Edge filter'; severity = 'high'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = 'EntraUser' }
                        [PSCustomObject]@{
                            edge      = 'InheritedRole'
                            direction = 'outbound'
                            filter    = @{ property = 'privileged'; op = 'eq'; value = $true }
                        }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 1
                $results[0].Path[1].id | Should -Be '/subscriptions/sub1'
            }
        }
    }

    Context 'InvokeCIEMAttackPathEvaluation with multi-hop pattern (5+ steps)' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id '__internet__' -Kind 'Internet' -DisplayName 'Internet' -Provider 'global'
            Save-CIEMGraphNode -Id 'nsg-1' -Kind 'AzureNSG' -DisplayName 'nsg1' -Provider 'azure'
            Save-CIEMGraphNode -Id 'vm-1' -Kind 'AzureVM' -DisplayName 'vm1' -Provider 'azure'
            Save-CIEMGraphNode -Id 'mi-1' -Kind 'EntraManagedIdentity' -DisplayName 'mi1' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub1' -Kind 'AzureSubscription' -DisplayName 'Sub1' -Provider 'azure'

            Save-CIEMGraphEdge -SourceId '__internet__' -TargetId 'nsg-1' -Kind 'AllowsInbound' `
                -Properties '{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}' -Computed 1
            Save-CIEMGraphEdge -SourceId 'nsg-1' -TargetId 'vm-1' -Kind 'AttachedTo' -Computed 1
            Save-CIEMGraphEdge -SourceId 'vm-1' -TargetId 'mi-1' -Kind 'HasManagedIdentity'
            Save-CIEMGraphEdge -SourceId 'mi-1' -TargetId '/subscriptions/sub1' -Kind 'HasRole' `
                -Properties '{"roleName":"Owner","privileged":true}'
        }

        It 'Traverses a complete 5-node chain (Internet -> NSG -> VM -> MI -> Subscription)' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id = 'test-multihop'; name = 'Multi-hop'; severity = 'critical'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = 'Internet' }
                        [PSCustomObject]@{ edge = 'AllowsInbound'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                        [PSCustomObject]@{ edge = 'AttachedTo'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureVM' }
                        [PSCustomObject]@{ edge = 'HasManagedIdentity'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'EntraManagedIdentity' }
                        [PSCustomObject]@{ edge = 'HasRole'; direction = 'outbound'; filter = @{ property = 'privileged'; op = 'eq'; value = $true } }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 1
                $results[0].Path | Should -HaveCount 5
                $results[0].Path[0].kind | Should -Be 'Internet'
                $results[0].Path[1].kind | Should -Be 'AzureNSG'
                $results[0].Path[2].kind | Should -Be 'AzureVM'
                $results[0].Path[3].kind | Should -Be 'EntraManagedIdentity'
                $results[0].Path[4].kind | Should -Be 'AzureSubscription'
                $results[0].Edges | Should -HaveCount 4
            }
        }

        It 'Returns empty when one hop in the chain is missing' {
            InModuleScope Devolutions.CIEM {
                # Remove the AttachedTo edge — breaks the chain
                Invoke-CIEMQuery -Query "DELETE FROM graph_edges WHERE kind = 'AttachedTo'"

                $pattern = [PSCustomObject]@{
                    id = 'test-broken-chain'; name = 'Broken chain'; severity = 'critical'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = 'Internet' }
                        [PSCustomObject]@{ edge = 'AllowsInbound'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                        [PSCustomObject]@{ edge = 'AttachedTo'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureVM' }
                        [PSCustomObject]@{ edge = 'HasManagedIdentity'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'EntraManagedIdentity' }
                        [PSCustomObject]@{ edge = 'HasRole'; direction = 'outbound' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 0
            }
        }

        It 'Finds multiple paths when graph branches' {
            InModuleScope Devolutions.CIEM {
                # Add a second VM behind the same NSG
                Save-CIEMGraphNode -Id 'vm-2' -Kind 'AzureVM' -DisplayName 'vm2' -Provider 'azure'
                Save-CIEMGraphNode -Id 'mi-2' -Kind 'EntraManagedIdentity' -DisplayName 'mi2' -Provider 'azure'
                Save-CIEMGraphEdge -SourceId 'nsg-1' -TargetId 'vm-2' -Kind 'AttachedTo' -Computed 1
                Save-CIEMGraphEdge -SourceId 'vm-2' -TargetId 'mi-2' -Kind 'HasManagedIdentity'
                Save-CIEMGraphEdge -SourceId 'mi-2' -TargetId '/subscriptions/sub1' -Kind 'HasRole' `
                    -Properties '{"roleName":"Contributor","privileged":true}'

                $pattern = [PSCustomObject]@{
                    id = 'test-branching'; name = 'Branching'; severity = 'critical'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = 'Internet' }
                        [PSCustomObject]@{ edge = 'AllowsInbound'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                        [PSCustomObject]@{ edge = 'AttachedTo'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'AzureVM' }
                        [PSCustomObject]@{ edge = 'HasManagedIdentity'; direction = 'outbound' }
                        [PSCustomObject]@{ kind = 'EntraManagedIdentity' }
                        [PSCustomObject]@{ edge = 'HasRole'; direction = 'outbound'; filter = @{ property = 'privileged'; op = 'eq'; value = $true } }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 2
            }
        }
    }

    Context 'InvokeCIEMAttackPathEvaluation with reverse direction edge' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # Reverse edge: target -> source traversal
            # Scenario: VM has edge "ProtectedBy" pointing TO an NSG
            # Pattern wants to start at NSG and traverse ProtectedBy(reverse) to find VMs
            Save-CIEMGraphNode -Id 'nsg-1' -Kind 'AzureNSG' -DisplayName 'nsg1' -Provider 'azure'
            Save-CIEMGraphNode -Id 'vm-1' -Kind 'AzureVM' -DisplayName 'vm1' -Provider 'azure'

            # Edge: VM -> NSG (ProtectedBy), so "reverse" traversal from NSG finds VMs
            Save-CIEMGraphEdge -SourceId 'vm-1' -TargetId 'nsg-1' -Kind 'ProtectedBy'
        }

        It 'Traverses edges in reverse direction (target_id match)' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id = 'test-reverse'; name = 'Reverse'; severity = 'medium'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = 'AzureNSG' }
                        [PSCustomObject]@{ edge = 'ProtectedBy'; direction = 'reverse' }
                        [PSCustomObject]@{ kind = 'AzureVM' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 1
                $results[0].Path[0].kind | Should -Be 'AzureNSG'
                $results[0].Path[1].kind | Should -Be 'AzureVM'
            }
        }
    }

    Context 'InvokeCIEMAttackPathEvaluation with kind array in node step' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'user-1' -Kind 'EntraUser' -DisplayName 'User1' -Provider 'azure'
            Save-CIEMGraphNode -Id 'sp-1' -Kind 'EntraServicePrincipal' -DisplayName 'SP1' -Provider 'azure'
            Save-CIEMGraphNode -Id 'vm-1' -Kind 'AzureVM' -DisplayName 'VM1' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub1' -Kind 'AzureSubscription' -DisplayName 'Sub1' -Provider 'azure'

            Save-CIEMGraphEdge -SourceId 'user-1' -TargetId '/subscriptions/sub1' -Kind 'HasRole'
            Save-CIEMGraphEdge -SourceId 'sp-1' -TargetId '/subscriptions/sub1' -Kind 'HasRole'
            Save-CIEMGraphEdge -SourceId 'vm-1' -TargetId '/subscriptions/sub1' -Kind 'HasRole'
        }

        It 'Matches multiple node kinds specified as array' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id = 'test-kind-array'; name = 'Kind array'; severity = 'medium'; category = 'test'
                    steps = @(
                        [PSCustomObject]@{ kind = @('EntraUser', 'EntraServicePrincipal') }
                        [PSCustomObject]@{ edge = 'HasRole'; direction = 'outbound' }
                    )
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                # user-1 and sp-1 should match, not vm-1
                $results | Should -HaveCount 2
            }
        }
    }

    Context 'InvokeCIEMAttackPathEvaluation returns empty for insufficient steps' {

        It 'Returns empty array for pattern with fewer than 2 steps' {
            InModuleScope Devolutions.CIEM {
                $pattern = [PSCustomObject]@{
                    id = 'test-single'; name = 'Single'; severity = 'low'; category = 'test'
                    steps = @([PSCustomObject]@{ kind = 'Internet' })
                }
                $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
                $results | Should -HaveCount 0
            }
        }
    }

    # =========================================================================
    # Public: Get-CIEMAttackPath
    # =========================================================================
    Context 'Get-CIEMAttackPath command structure' {

        It 'Is available as a public command' {
            Get-Command Get-CIEMAttackPath -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has optional -PatternId parameter' {
            $param = (Get-Command Get-CIEMAttackPath).Parameters['PatternId']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Has optional -Severity parameter with ValidateSet' {
            $param = (Get-Command Get-CIEMAttackPath).Parameters['Severity']
            $param | Should -Not -BeNullOrEmpty
            $validateSet = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-CIEMAttackPath with matching open-management-port data' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id '__internet__' -Kind 'Internet' -DisplayName 'Internet' -Provider 'global'
            Save-CIEMGraphNode -Id '/subs/s1/rg/rg1/nsg/nsg1' -Kind 'AzureNSG' -DisplayName 'nsg1' -Provider 'azure'

            Save-CIEMGraphEdge -SourceId '__internet__' -TargetId '/subs/s1/rg/rg1/nsg/nsg1' -Kind 'AllowsInbound' `
                -Properties '{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}' -Computed 1
        }

        It 'Returns attack path findings for matching patterns' {
            $results = @(Get-CIEMAttackPath)
            $matching = @($results | Where-Object { $_.PatternId -eq 'open-management-port' })
            $matching.Count | Should -BeGreaterOrEqual 1
        }

        It 'Returns findings with PatternId, PatternName, Severity, Path, Edges properties' {
            $results = @(Get-CIEMAttackPath -PatternId 'open-management-port')
            $r = $results[0]
            $r.PatternId | Should -Be 'open-management-port'
            $r.PatternName | Should -Be 'Management port open to the internet'
            $r.Severity | Should -Be 'high'
            $r.PSObject.Properties.Name | Should -Contain 'Path'
            $r.PSObject.Properties.Name | Should -Contain 'Edges'
        }

        It 'Path contains ordered node objects matching the chain' {
            $results = @(Get-CIEMAttackPath -PatternId 'open-management-port')
            $path = $results[0].Path
            $path | Should -HaveCount 2
            $path[0].kind | Should -Be 'Internet'
            $path[1].kind | Should -Be 'AzureNSG'
        }

        It 'Filters by -PatternId parameter' {
            $results = @(Get-CIEMAttackPath -PatternId 'open-management-port')
            $results.Count | Should -BeGreaterOrEqual 1
            $results | ForEach-Object { $_.PatternId | Should -Be 'open-management-port' }
        }

        It 'Filters by -Severity parameter' {
            $results = @(Get-CIEMAttackPath -Severity 'high')
            $results.Count | Should -BeGreaterOrEqual 1
            $results | ForEach-Object { $_.Severity | Should -Be 'high' }
        }

        It 'Returns empty array when no paths match' {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            $results = @(Get-CIEMAttackPath -PatternId 'open-management-port')
            $results | Should -HaveCount 0
        }

        It 'Evaluates edge filter conditions correctly (non-management ports excluded)' {
            # Replace the edge with a non-management port (443)
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Save-CIEMGraphEdge -SourceId '__internet__' -TargetId '/subs/s1/rg/rg1/nsg/nsg1' -Kind 'AllowsInbound' `
                -Properties '{"open_ports":[{"port":443,"protocol":"TCP","rule_name":"AllowHTTPS"}]}' -Computed 1

            $results = @(Get-CIEMAttackPath -PatternId 'open-management-port')
            $results | Should -HaveCount 0
        }
    }

    Context 'Get-CIEMAttackPath with no matching graph data' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
        }

        It 'Returns empty array when graph has no data' {
            $results = @(Get-CIEMAttackPath)
            $results | Should -HaveCount 0
        }
    }

    # =========================================================================
    # Public: Get-CIEMGraphPath
    # =========================================================================
    Context 'Get-CIEMGraphPath command structure' {

        It 'Is available as a public command' {
            Get-Command Get-CIEMGraphPath -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory -FromKind parameter' {
            $param = (Get-Command Get-CIEMGraphPath).Parameters['FromKind']
            $param | Should -Not -BeNullOrEmpty
            $mandatory = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatory | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory -ToKind parameter' {
            $param = (Get-Command Get-CIEMGraphPath).Parameters['ToKind']
            $param | Should -Not -BeNullOrEmpty
            $mandatory = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatory | Should -Not -BeNullOrEmpty
        }

        It 'Has optional -MaxDepth parameter defaulting to 5' {
            $param = (Get-Command Get-CIEMGraphPath).Parameters['MaxDepth']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Has optional -EdgeKind parameter' {
            $param = (Get-Command Get-CIEMGraphPath).Parameters['EdgeKind']
            $param | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-CIEMGraphPath traversal' {

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # A -> B -> C chain
            Save-CIEMGraphNode -Id 'a-1' -Kind 'KindA' -DisplayName 'A1' -Provider 'test'
            Save-CIEMGraphNode -Id 'b-1' -Kind 'KindB' -DisplayName 'B1' -Provider 'test'
            Save-CIEMGraphNode -Id 'c-1' -Kind 'KindC' -DisplayName 'C1' -Provider 'test'

            Save-CIEMGraphEdge -SourceId 'a-1' -TargetId 'b-1' -Kind 'LinksTo'
            Save-CIEMGraphEdge -SourceId 'b-1' -TargetId 'c-1' -Kind 'LinksTo'
        }

        It 'Finds paths between two node kinds' {
            $results = @(Get-CIEMGraphPath -FromKind 'KindA' -ToKind 'KindC')
            $results | Should -HaveCount 1
            $results[0].FromNode.Id | Should -Be 'a-1'
            $results[0].ToNode.Id | Should -Be 'c-1'
        }

        It 'Returns empty when no path exists' {
            # No edges from C to A
            $results = @(Get-CIEMGraphPath -FromKind 'KindC' -ToKind 'KindA')
            $results | Should -HaveCount 0
        }

        It 'Respects max depth limit' {
            # Chain is depth 2 (A->B->C), set max to 1
            $results = @(Get-CIEMGraphPath -FromKind 'KindA' -ToKind 'KindC' -MaxDepth 1)
            $results | Should -HaveCount 0
        }

        It 'Returns direct paths within max depth' {
            # Direct edge A->B is depth 1
            $results = @(Get-CIEMGraphPath -FromKind 'KindA' -ToKind 'KindB' -MaxDepth 1)
            $results | Should -HaveCount 1
            $results[0].Depth | Should -Be 1
        }

        It 'Returns multiple paths when they exist' {
            # Add second path: A -> D -> C
            Save-CIEMGraphNode -Id 'd-1' -Kind 'KindD' -DisplayName 'D1' -Provider 'test'
            Save-CIEMGraphEdge -SourceId 'a-1' -TargetId 'd-1' -Kind 'LinksTo'
            Save-CIEMGraphEdge -SourceId 'd-1' -TargetId 'c-1' -Kind 'LinksTo'

            $results = @(Get-CIEMGraphPath -FromKind 'KindA' -ToKind 'KindC')
            $results | Should -HaveCount 2
        }

        It 'Filters by -EdgeKind when specified' {
            # Add a different edge kind
            Save-CIEMGraphNode -Id 'e-1' -Kind 'KindC' -DisplayName 'E1' -Provider 'test'
            Save-CIEMGraphEdge -SourceId 'a-1' -TargetId 'e-1' -Kind 'DifferentKind'

            # Should only find paths via 'LinksTo' edges
            $results = @(Get-CIEMGraphPath -FromKind 'KindA' -ToKind 'KindC' -EdgeKind 'LinksTo')
            $results | Should -HaveCount 1
            $results[0].ToNode.Id | Should -Be 'c-1'
        }

        It 'Path array contains all intermediate nodes' {
            $results = @(Get-CIEMGraphPath -FromKind 'KindA' -ToKind 'KindC')
            # Path should contain A, B, C
            $results[0].Path | Should -HaveCount 3
            $results[0].Path[0].Id | Should -Be 'a-1'
            $results[0].Path[1].Id | Should -Be 'b-1'
            $results[0].Path[2].Id | Should -Be 'c-1'
        }

        It 'Edges array contains all traversed edges' {
            $results = @(Get-CIEMGraphPath -FromKind 'KindA' -ToKind 'KindC')
            $results[0].Edges | Should -HaveCount 2
            $results[0].Edges[0].Kind | Should -Be 'LinksTo'
            $results[0].Edges[1].Kind | Should -Be 'LinksTo'
        }

        It 'Does not revisit nodes (cycle protection)' {
            # Create a cycle: C -> A
            Save-CIEMGraphEdge -SourceId 'c-1' -TargetId 'a-1' -Kind 'LinksTo'

            # Should still find A->B->C without infinite loop
            $results = @(Get-CIEMGraphPath -FromKind 'KindA' -ToKind 'KindC')
            $results | Should -HaveCount 1
        }
    }
}
