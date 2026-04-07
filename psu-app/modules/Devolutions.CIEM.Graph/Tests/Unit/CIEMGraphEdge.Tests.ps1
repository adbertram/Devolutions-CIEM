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

Describe 'Graph Edge CRUD' {

    Context 'Schema' {
        It 'graph_edges table exists after applying graph_schema.sql' {
            $result = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='graph_edges'"
            $result | Should -Not -BeNullOrEmpty
        }

        It 'All 6 indexes exist' {
            $indexes = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='graph_edges'")
            $indexNames = $indexes.name
            $indexNames | Should -Contain 'idx_graph_edges_source'
            $indexNames | Should -Contain 'idx_graph_edges_target'
            $indexNames | Should -Contain 'idx_graph_edges_kind'
            $indexNames | Should -Contain 'idx_graph_edges_source_kind'
            $indexNames | Should -Contain 'idx_graph_edges_target_kind'
            $indexNames | Should -Contain 'idx_graph_edges_computed'
        }
    }

    Context 'Command structure' {
        It 'Get-CIEMGraphEdge is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMGraphEdge -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMGraphEdge is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Save-CIEMGraphEdge -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Remove-CIEMGraphEdge is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Remove-CIEMGraphEdge -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-CIEMGraphEdge' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
            # Seed prerequisite nodes
            Save-CIEMGraphNode -Id 'node-a' -Kind 'EntraUser' -DisplayName 'User A' -Provider 'azure'
            Save-CIEMGraphNode -Id 'node-b' -Kind 'EntraGroup' -DisplayName 'Group B' -Provider 'azure'
            Save-CIEMGraphNode -Id 'node-c' -Kind 'AzureVM' -DisplayName 'VM C' -Provider 'azure'
            Save-CIEMGraphNode -Id 'node-d' -Kind 'ManagedIdentity' -DisplayName 'MI D' -Provider 'azure'
            $ts = (Get-Date).ToString('o')
            # Seed test edges
            Save-CIEMGraphEdge -SourceId 'node-a' -TargetId 'node-b' -Kind 'MemberOf' -CollectedAt $ts
            Save-CIEMGraphEdge -SourceId 'node-a' -TargetId 'node-c' -Kind 'HasRoleAssignment' -Properties '{"role_name": "Owner", "privileged": true}' -CollectedAt $ts
            Save-CIEMGraphEdge -SourceId 'node-c' -TargetId 'node-d' -Kind 'HasManagedIdentity' -Computed 1 -CollectedAt $ts
            Save-CIEMGraphEdge -SourceId 'node-b' -TargetId 'node-c' -Kind 'HasRoleAssignment' -CollectedAt $ts
        }

        It 'Returns all when no filter' {
            $results = Get-CIEMGraphEdge
            $results | Should -HaveCount 4
        }

        It 'Returns CIEMGraphEdge typed objects' {
            $results = Get-CIEMGraphEdge
            $results | ForEach-Object { $_.GetType().Name | Should -Be 'CIEMGraphEdge' }
        }

        It 'Filters by -Id' {
            $all = Get-CIEMGraphEdge
            $first = $all | Select-Object -First 1
            $result = Get-CIEMGraphEdge -Id $first.Id
            $result | Should -HaveCount 1
            $result[0].Id | Should -Be $first.Id
        }

        It 'Filters by -SourceId' {
            $results = Get-CIEMGraphEdge -SourceId 'node-a'
            $results | Should -HaveCount 2
        }

        It 'Filters by -TargetId' {
            $results = Get-CIEMGraphEdge -TargetId 'node-c'
            $results | Should -HaveCount 2
        }

        It 'Filters by -Kind' {
            $results = Get-CIEMGraphEdge -Kind 'HasRoleAssignment'
            $results | Should -HaveCount 2
        }

        It 'Filters by -Computed' {
            $results = Get-CIEMGraphEdge -Computed 1
            $results | Should -HaveCount 1
            $results[0].Kind | Should -Be 'HasManagedIdentity'
        }

        It 'Returns empty array when no match' {
            $results = Get-CIEMGraphEdge -SourceId 'nonexistent'
            $results | Should -BeNullOrEmpty
        }

        It 'Combines multiple filters' {
            $results = Get-CIEMGraphEdge -SourceId 'node-a' -Kind 'MemberOf'
            $results | Should -HaveCount 1
            $results[0].TargetId | Should -Be 'node-b'
        }
    }

    Context 'Save-CIEMGraphEdge' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
            Save-CIEMGraphNode -Id 'node-a' -Kind 'EntraUser' -DisplayName 'User A' -Provider 'azure'
            Save-CIEMGraphNode -Id 'node-b' -Kind 'EntraGroup' -DisplayName 'Group B' -Provider 'azure'
        }

        It 'Inserts a new edge' {
            $ts = (Get-Date).ToString('o')
            Save-CIEMGraphEdge -SourceId 'node-a' -TargetId 'node-b' -Kind 'MemberOf' -CollectedAt $ts
            $results = Get-CIEMGraphEdge
            $results | Should -HaveCount 1
            $results[0].SourceId | Should -Be 'node-a'
        }

        It 'INSERT OR REPLACE honors UNIQUE constraint (updates on conflict)' {
            $ts = (Get-Date).ToString('o')
            Save-CIEMGraphEdge -SourceId 'node-a' -TargetId 'node-b' -Kind 'MemberOf' -Properties '{"v1": true}' -CollectedAt $ts
            Save-CIEMGraphEdge -SourceId 'node-a' -TargetId 'node-b' -Kind 'MemberOf' -Properties '{"v2": true}' -CollectedAt $ts
            # UNIQUE(source_id, target_id, kind) - should be 1 row, not 2
            $results = Get-CIEMGraphEdge
            $results | Should -HaveCount 1
            $results[0].Properties | Should -Be '{"v2": true}'
        }

        It 'Accepts -InputObject via pipeline' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMGraphEdge]::new()
                $o.SourceId = 'node-a'
                $o.TargetId = 'node-b'
                $o.Kind = 'HasRole'
                $o.Properties = '{"piped": true}'
                $o.Computed = 0
                $o.CollectedAt = (Get-Date).ToString('o')
                $o
            }
            $obj | Save-CIEMGraphEdge
            $result = Get-CIEMGraphEdge -Kind 'HasRole'
            $result | Should -Not -BeNullOrEmpty
            $result[0].Properties | Should -Be '{"piped": true}'
        }
    }

    Context 'Remove-CIEMGraphEdge' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"
            Save-CIEMGraphNode -Id 'node-a' -Kind 'EntraUser' -DisplayName 'User A' -Provider 'azure'
            Save-CIEMGraphNode -Id 'node-b' -Kind 'EntraGroup' -DisplayName 'Group B' -Provider 'azure'
            Save-CIEMGraphNode -Id 'node-c' -Kind 'AzureVM' -DisplayName 'VM C' -Provider 'azure'
            Save-CIEMGraphNode -Id 'node-d' -Kind 'ManagedIdentity' -DisplayName 'MI D' -Provider 'azure'
            $ts = (Get-Date).ToString('o')
            Save-CIEMGraphEdge -SourceId 'node-a' -TargetId 'node-b' -Kind 'MemberOf' -CollectedAt $ts
            Save-CIEMGraphEdge -SourceId 'node-a' -TargetId 'node-c' -Kind 'MemberOf' -CollectedAt $ts
            Save-CIEMGraphEdge -SourceId 'node-c' -TargetId 'node-d' -Kind 'HasManagedIdentity' -Computed 1 -CollectedAt $ts
            $script:rmEdge1 = Get-CIEMGraphEdge -SourceId 'node-a' -TargetId 'node-b' -Kind 'MemberOf' | Select-Object -First 1
        }

        It 'Removes by -Id (integer)' {
            Remove-CIEMGraphEdge -Id $script:rmEdge1.Id -Confirm:$false
            $result = Get-CIEMGraphEdge -Id $script:rmEdge1.Id
            $result | Should -BeNullOrEmpty
            Get-CIEMGraphEdge | Should -HaveCount 2
        }

        It 'Removes by -Kind' {
            Remove-CIEMGraphEdge -Kind 'MemberOf' -Confirm:$false
            $results = Get-CIEMGraphEdge
            $results | Should -HaveCount 1
            $results[0].Kind | Should -Be 'HasManagedIdentity'
        }

        It 'Removes by -Computed flag' {
            Remove-CIEMGraphEdge -Computed 1 -Confirm:$false
            $results = Get-CIEMGraphEdge
            $results | Should -HaveCount 2
            $results | ForEach-Object { $_.Computed | Should -Be 0 }
        }

        It 'Removes all records with -All switch' {
            Remove-CIEMGraphEdge -All -Confirm:$false
            $results = Get-CIEMGraphEdge
            $results | Should -BeNullOrEmpty
        }

        It 'Removes via -InputObject' {
            $obj = Get-CIEMGraphEdge -Kind 'HasManagedIdentity'
            Remove-CIEMGraphEdge -InputObject $obj -Confirm:$false
            $result = Get-CIEMGraphEdge -Kind 'HasManagedIdentity'
            $result | Should -BeNullOrEmpty
            Get-CIEMGraphEdge | Should -HaveCount 2
        }

        It 'No-ops when Id does not exist' {
            { Remove-CIEMGraphEdge -Id 99999 -Confirm:$false } | Should -Not -Throw
        }
    }
}
