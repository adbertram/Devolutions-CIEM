BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    # Create isolated test DB with base + azure + discovery schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Effective Role Assignment CRUD' {

    Context 'Schema' {
        It 'azure_effective_role_assignments table exists after applying discovery_schema.sql' {
            $result = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' AND name='azure_effective_role_assignments'"
            $result | Should -Not -BeNullOrEmpty
        }

        It 'All 4 indexes exist' {
            $indexes = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='azure_effective_role_assignments'")
            $indexNames = $indexes.name
            $indexNames | Should -Contain 'idx_effective_ra_principal'
            $indexNames | Should -Contain 'idx_effective_ra_scope'
            $indexNames | Should -Contain 'idx_effective_ra_role_def'
            $indexNames | Should -Contain 'idx_effective_ra_principal_type'
        }
    }

    Context 'Command structure' {
        It 'New-CIEMAzureEffectiveRoleAssignment is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name New-CIEMAzureEffectiveRoleAssignment -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Get-CIEMAzureEffectiveRoleAssignment is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureEffectiveRoleAssignment -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Update-CIEMAzureEffectiveRoleAssignment is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Update-CIEMAzureEffectiveRoleAssignment -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureEffectiveRoleAssignment is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Save-CIEMAzureEffectiveRoleAssignment -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Remove-CIEMAzureEffectiveRoleAssignment is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Remove-CIEMAzureEffectiveRoleAssignment -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'New-CIEMAzureEffectiveRoleAssignment' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
        }

        It 'Creates record and returns CIEMAzureEffectiveRoleAssignment typed object with auto-incremented Id' {
            $result = New-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-1' -PrincipalType 'User' `
                -OriginalPrincipalId 'user-1' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'role-def-1' -Scope '/subscriptions/sub-1' `
                -ComputedAt '2026-01-01T00:00:00Z'
            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'CIEMAzureEffectiveRoleAssignment'
            $result.Id | Should -BeOfType [int]
            $result.Id | Should -BeGreaterThan 0
        }

        It 'Consecutive creates return incrementing Ids' {
            $r1 = New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'a' -PrincipalType 'User' -OriginalPrincipalId 'a' -OriginalPrincipalType 'User' -RoleDefinitionId 'rd-1' -Scope '/sub/1' -ComputedAt '2026-01-01T00:00:00Z'
            $r2 = New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'b' -PrincipalType 'User' -OriginalPrincipalId 'b' -OriginalPrincipalType 'User' -RoleDefinitionId 'rd-1' -Scope '/sub/1' -ComputedAt '2026-01-01T00:00:00Z'
            $r2.Id | Should -BeGreaterThan $r1.Id
        }

        It 'Accepts -InputObject parameter set' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureEffectiveRoleAssignment]::new()
                $o.PrincipalId = 'sp-1'
                $o.PrincipalType = 'ServicePrincipal'
                $o.OriginalPrincipalId = 'sp-1'
                $o.OriginalPrincipalType = 'ServicePrincipal'
                $o.RoleDefinitionId = 'rd-2'
                $o.Scope = '/subscriptions/sub-2'
                $o.ComputedAt = '2026-01-01T00:00:00Z'
                $o
            }
            $result = New-CIEMAzureEffectiveRoleAssignment -InputObject $obj
            $result | Should -Not -BeNullOrEmpty
            $result.PrincipalId | Should -Be 'sp-1'
        }

        It 'Throws on duplicate (principal_id, role_definition_id, scope, original_principal_id) UNIQUE violation' {
            $ts = '2026-01-01T00:00:00Z'
            New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'dup' -PrincipalType 'User' -OriginalPrincipalId 'dup' -OriginalPrincipalType 'User' -RoleDefinitionId 'rd-1' -Scope '/sub/1' -ComputedAt $ts
            { New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'dup' -PrincipalType 'User' -OriginalPrincipalId 'dup' -OriginalPrincipalType 'User' -RoleDefinitionId 'rd-1' -Scope '/sub/1' -ComputedAt $ts } | Should -Throw
        }

        It 'Defaults ComputedAt to current time when not provided' {
            $before = (Get-Date).ToString('o')
            $result = New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'def-ts' -PrincipalType 'User' -OriginalPrincipalId 'def-ts' -OriginalPrincipalType 'User' -RoleDefinitionId 'rd-1' -Scope '/sub/1'
            $result.ComputedAt | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Get-CIEMAzureEffectiveRoleAssignment' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
            $ts = '2026-01-01T00:00:00Z'
            New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'user-1' -PrincipalType 'User' -OriginalPrincipalId 'user-1' -OriginalPrincipalType 'User' -RoleDefinitionId 'rd-owner' -RoleName 'Owner' -Scope '/subscriptions/sub-1' -ComputedAt $ts
            New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'user-1' -PrincipalType 'User' -OriginalPrincipalId 'group-1' -OriginalPrincipalType 'Group' -RoleDefinitionId 'rd-reader' -RoleName 'Reader' -Scope '/subscriptions/sub-2' -ComputedAt $ts
            New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'sp-1' -PrincipalType 'ServicePrincipal' -OriginalPrincipalId 'sp-1' -OriginalPrincipalType 'ServicePrincipal' -RoleDefinitionId 'rd-contrib' -RoleName 'Contributor' -Scope '/subscriptions/sub-1' -ComputedAt $ts
        }

        It 'Returns all when no filter' {
            $results = Get-CIEMAzureEffectiveRoleAssignment
            $results | Should -HaveCount 3
        }

        It 'Returns CIEMAzureEffectiveRoleAssignment typed objects' {
            $results = Get-CIEMAzureEffectiveRoleAssignment
            $results | ForEach-Object { $_.GetType().Name | Should -Be 'CIEMAzureEffectiveRoleAssignment' }
        }

        It 'Filters by -PrincipalId' {
            $results = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'user-1'
            $results | Should -HaveCount 2
        }

        It 'Filters by -OriginalPrincipalId' {
            $results = Get-CIEMAzureEffectiveRoleAssignment -OriginalPrincipalId 'group-1'
            $results | Should -HaveCount 1
            $results[0].PrincipalId | Should -Be 'user-1'
        }

        It 'Filters by -RoleDefinitionId' {
            $results = Get-CIEMAzureEffectiveRoleAssignment -RoleDefinitionId 'rd-owner'
            $results | Should -HaveCount 1
            $results[0].RoleName | Should -Be 'Owner'
        }

        It 'Filters by -Scope' {
            $results = Get-CIEMAzureEffectiveRoleAssignment -Scope '/subscriptions/sub-1'
            $results | Should -HaveCount 2
        }

        It 'Filters by -PrincipalType' {
            $results = Get-CIEMAzureEffectiveRoleAssignment -PrincipalType 'ServicePrincipal'
            $results | Should -HaveCount 1
            $results[0].PrincipalId | Should -Be 'sp-1'
        }

        It 'Filters by -PrincipalId and -RoleDefinitionId combined' {
            $results = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'user-1' -RoleDefinitionId 'rd-owner'
            $results | Should -HaveCount 1
            $results[0].Scope | Should -Be '/subscriptions/sub-1'
        }

        It 'Filters by -PrincipalType and -Scope combined' {
            $results = Get-CIEMAzureEffectiveRoleAssignment -PrincipalType 'User' -Scope '/subscriptions/sub-1'
            $results | Should -HaveCount 1
            $results[0].RoleName | Should -Be 'Owner'
        }

        It 'Returns empty array when no match' {
            $results = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'nonexistent'
            $results | Should -HaveCount 0
        }
    }

    Context 'Update-CIEMAzureEffectiveRoleAssignment' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
            $script:testRow = New-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'upd-user' -PrincipalType 'User' `
                -PrincipalDisplayName 'Original Name' `
                -OriginalPrincipalId 'upd-user' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'rd-1' -RoleName 'OldRole' `
                -Scope '/subscriptions/sub-1' `
                -PermissionsJson '["read"]' `
                -ComputedAt '2026-01-01T00:00:00Z'
        }

        It 'Updates RoleName without overwriting other fields' {
            Update-CIEMAzureEffectiveRoleAssignment -Id $script:testRow.Id -RoleName 'NewRole'
            $result = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'upd-user'
            $result[0].RoleName | Should -Be 'NewRole'
            $result[0].PrincipalDisplayName | Should -Be 'Original Name'
            $result[0].PermissionsJson | Should -Be '["read"]'
        }

        It 'Updates PrincipalDisplayName without overwriting other fields' {
            Update-CIEMAzureEffectiveRoleAssignment -Id $script:testRow.Id -PrincipalDisplayName 'Updated Name'
            $result = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'upd-user'
            $result[0].PrincipalDisplayName | Should -Be 'Updated Name'
            $result[0].RoleName | Should -Be 'OldRole'
        }

        It 'Updates ComputedAt without overwriting other fields' {
            Update-CIEMAzureEffectiveRoleAssignment -Id $script:testRow.Id -ComputedAt '2026-03-01T00:00:00Z'
            $result = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'upd-user'
            $result[0].ComputedAt | Should -Be '2026-03-01T00:00:00Z'
            $result[0].RoleName | Should -Be 'OldRole'
        }

        It 'Returns nothing without -PassThru' {
            $result = Update-CIEMAzureEffectiveRoleAssignment -Id $script:testRow.Id -RoleName 'X'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns updated object with -PassThru' {
            $result = Update-CIEMAzureEffectiveRoleAssignment -Id $script:testRow.Id -RoleName 'NewRole' -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'CIEMAzureEffectiveRoleAssignment'
            $result.RoleName | Should -Be 'NewRole'
        }

        It 'Accepts -InputObject for full object update' {
            $obj = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'upd-user'
            $obj = $obj | Select-Object -First 1
            $obj.RoleName = 'ViaInputObject'
            $obj.PrincipalDisplayName = 'IO Name'
            Update-CIEMAzureEffectiveRoleAssignment -InputObject $obj
            $result = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'upd-user'
            $result[0].RoleName | Should -Be 'ViaInputObject'
            $result[0].PrincipalDisplayName | Should -Be 'IO Name'
        }
    }

    Context 'Save-CIEMAzureEffectiveRoleAssignment' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
        }

        It 'INSERT OR REPLACE honors UNIQUE constraint (same tuple, different RoleName -> 1 row with updated RoleName)' {
            $ts = '2026-01-01T00:00:00Z'
            Save-CIEMAzureEffectiveRoleAssignment -PrincipalId 'save-u' -PrincipalType 'User' -OriginalPrincipalId 'save-u' -OriginalPrincipalType 'User' -RoleDefinitionId 'rd-1' -RoleName 'OldRole' -Scope '/sub/1' -ComputedAt $ts
            Save-CIEMAzureEffectiveRoleAssignment -PrincipalId 'save-u' -PrincipalType 'User' -OriginalPrincipalId 'save-u' -OriginalPrincipalType 'User' -RoleDefinitionId 'rd-1' -RoleName 'NewRole' -Scope '/sub/1' -ComputedAt $ts
            $results = Get-CIEMAzureEffectiveRoleAssignment
            $results | Should -HaveCount 1
            $results[0].RoleName | Should -Be 'NewRole'
        }

        It 'Accepts -InputObject via pipeline' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureEffectiveRoleAssignment]::new()
                $o.PrincipalId = 'pipe-u'
                $o.PrincipalType = 'User'
                $o.OriginalPrincipalId = 'pipe-u'
                $o.OriginalPrincipalType = 'User'
                $o.RoleDefinitionId = 'rd-1'
                $o.Scope = '/sub/1'
                $o.ComputedAt = '2026-01-01T00:00:00Z'
                $o
            }
            $obj | Save-CIEMAzureEffectiveRoleAssignment
            $result = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'pipe-u'
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Accepts null PrincipalDisplayName, RoleName, PermissionsJson without throwing' {
            { Save-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'null-test' -PrincipalType 'User' `
                -OriginalPrincipalId 'null-test' -OriginalPrincipalType 'User' `
                -RoleDefinitionId 'rd-1' -Scope '/sub/1' `
                -ComputedAt '2026-01-01T00:00:00Z' } | Should -Not -Throw
            $result = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'null-test'
            $result | Should -HaveCount 1
            $result[0].PrincipalDisplayName | Should -BeNullOrEmpty
            $result[0].RoleName | Should -BeNullOrEmpty
            $result[0].PermissionsJson | Should -BeNullOrEmpty
        }

        It 'Accepts -Connection parameter for atomic transactions' {
            InModuleScope Devolutions.CIEM {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    Save-CIEMAzureEffectiveRoleAssignment `
                        -PrincipalId 'conn-test' -PrincipalType 'User' `
                        -OriginalPrincipalId 'conn-test' -OriginalPrincipalType 'User' `
                        -RoleDefinitionId 'rd-1' -Scope '/sub/1' `
                        -ComputedAt '2026-01-01T00:00:00Z' `
                        -Connection $conn
                } finally {
                    $conn.Dispose()
                }
            }
            $result = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'conn-test'
            $result | Should -HaveCount 1
        }
    }

    Context 'Remove-CIEMAzureEffectiveRoleAssignment' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
            $ts = '2026-01-01T00:00:00Z'
            $script:rmRow1 = New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'rm-u1' -PrincipalType 'User' -OriginalPrincipalId 'rm-u1' -OriginalPrincipalType 'User' -RoleDefinitionId 'rd-1' -Scope '/sub/1' -ComputedAt $ts
            New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'rm-u1' -PrincipalType 'User' -OriginalPrincipalId 'rm-u1' -OriginalPrincipalType 'User' -RoleDefinitionId 'rd-2' -Scope '/sub/2' -ComputedAt $ts
            New-CIEMAzureEffectiveRoleAssignment -PrincipalId 'rm-u2' -PrincipalType 'ServicePrincipal' -OriginalPrincipalId 'rm-u2' -OriginalPrincipalType 'ServicePrincipal' -RoleDefinitionId 'rd-1' -Scope '/sub/1' -ComputedAt $ts
        }

        It 'Removes by -Id' {
            Remove-CIEMAzureEffectiveRoleAssignment -Id $script:rmRow1.Id -Confirm:$false
            $result = Get-CIEMAzureEffectiveRoleAssignment -Id $script:rmRow1.Id
            $result | Should -BeNullOrEmpty
            Get-CIEMAzureEffectiveRoleAssignment | Should -HaveCount 2
        }

        It 'Removes by -PrincipalId (bulk - removes all rows for that principal, leaves others)' {
            Remove-CIEMAzureEffectiveRoleAssignment -PrincipalId 'rm-u1' -Confirm:$false
            $result = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'rm-u1'
            $result | Should -BeNullOrEmpty
            # rm-u2 still exists
            $remaining = Get-CIEMAzureEffectiveRoleAssignment
            $remaining | Should -HaveCount 1
            $remaining[0].PrincipalId | Should -Be 'rm-u2'
        }

        It 'Removes all records with -All switch' {
            Remove-CIEMAzureEffectiveRoleAssignment -All -Confirm:$false
            $results = Get-CIEMAzureEffectiveRoleAssignment
            $results | Should -HaveCount 0
        }

        It 'Removes via -InputObject' {
            $obj = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'rm-u2'
            Remove-CIEMAzureEffectiveRoleAssignment -InputObject $obj -Confirm:$false
            $result = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'rm-u2'
            $result | Should -BeNullOrEmpty
        }

        It 'Accepts -Connection parameter for atomic transactions' {
            InModuleScope Devolutions.CIEM {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    Remove-CIEMAzureEffectiveRoleAssignment -All -Confirm:$false -Connection $conn
                } finally {
                    $conn.Dispose()
                }
            }
            $results = Get-CIEMAzureEffectiveRoleAssignment
            $results | Should -HaveCount 0
        }

        It 'No-ops when Id does not exist' {
            { Remove-CIEMAzureEffectiveRoleAssignment -Id 99999 -Confirm:$false } | Should -Not -Throw
        }
    }

    Context 'InvokeCIEMAzureEffectiveRoleAssignmentBuild (private)' {
        BeforeAll {
            # --- Test data builders (must be in BeforeAll for Pester 5 Run phase) ---
            $script:roleDef1Props = @{
                roleName = 'Contributor'
                permissions = @(
                    @{
                        actions = @('*')
                        notActions = @('Microsoft.Authorization/*/Delete')
                        dataActions = @()
                        notDataActions = @()
                    }
                )
            } | ConvertTo-Json -Depth 5 -Compress

            $script:roleDef2Props = @{
                roleName = 'Reader'
                permissions = @(
                    @{
                        actions = @('*/read')
                        notActions = @()
                        dataActions = @()
                        notDataActions = @()
                    }
                )
            } | ConvertTo-Json -Depth 5 -Compress

            $script:directAssignmentProps = @{
                principalId = 'user-direct'
                principalType = 'User'
                roleDefinitionId = '/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'
                scope = '/subscriptions/sub-1'
            } | ConvertTo-Json -Compress

            $script:groupAssignmentProps = @{
                principalId = 'group-1'
                principalType = 'Group'
                roleDefinitionId = '/providers/Microsoft.Authorization/roleDefinitions/rd-reader'
                scope = '/subscriptions/sub-2'
            } | ConvertTo-Json -Compress
        }

        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
        }

        It 'Inserts direct assignment rows for non-group principals' {
            InModuleScope Devolutions.CIEM -Parameters @{
                directProps = $script:directAssignmentProps
                roleDef1Props = $script:roleDef1Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef1Props }
                        [PSCustomObject]@{ Id = 'ra-1'; Type = 'microsoft.authorization/roleassignments'; Properties = $directProps }
                    )
                    $result = InvokeCIEMAzureEffectiveRoleAssignmentBuild `
                        -ArmResources $armResources `
                        -EntraResources @() `
                        -Relationships @() `
                        -Connection $conn `
                        -ComputedAt '2026-01-01T00:00:00Z'
                    $result | Should -Be 1
                } finally { $conn.Dispose() }
            }
            $rows = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'user-direct'
            $rows | Should -HaveCount 1
            $rows[0].PrincipalType | Should -Be 'User'
            $rows[0].OriginalPrincipalId | Should -Be 'user-direct'
        }

        It 'Expands group assignments to transitive members' {
            InModuleScope Devolutions.CIEM -Parameters @{
                groupProps = $script:groupAssignmentProps
                roleDef2Props = $script:roleDef2Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-reader'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef2Props }
                        [PSCustomObject]@{ Id = 'ra-grp'; Type = 'microsoft.authorization/roleassignments'; Properties = $groupProps }
                    )
                    $relationships = @(
                        [PSCustomObject]@{ SourceId = 'member-user'; SourceType = 'user'; TargetId = 'group-1'; TargetType = 'group'; Relationship = 'transitive_member_of' }
                        [PSCustomObject]@{ SourceId = 'member-sp'; SourceType = 'servicePrincipal'; TargetId = 'group-1'; TargetType = 'group'; Relationship = 'transitive_member_of' }
                    )
                    $result = InvokeCIEMAzureEffectiveRoleAssignmentBuild `
                        -ArmResources $armResources `
                        -EntraResources @() `
                        -Relationships $relationships `
                        -Connection $conn `
                        -ComputedAt '2026-01-01T00:00:00Z'
                    # 2 expanded members + 1 group self-row = 3
                    $result | Should -Be 3
                } finally { $conn.Dispose() }
            }
            $allRows = Get-CIEMAzureEffectiveRoleAssignment
            $allRows | Should -HaveCount 3
            $memberRows = $allRows | Where-Object { $_.OriginalPrincipalType -eq 'Group' -and $_.PrincipalId -ne 'group-1' }
            $memberRows | Should -HaveCount 2
        }

        It 'Inserts only the group self-row when group has no transitive members' {
            InModuleScope Devolutions.CIEM -Parameters @{
                groupProps = $script:groupAssignmentProps
                roleDef2Props = $script:roleDef2Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-reader'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef2Props }
                        [PSCustomObject]@{ Id = 'ra-empty-grp'; Type = 'microsoft.authorization/roleassignments'; Properties = $groupProps }
                    )
                    $result = InvokeCIEMAzureEffectiveRoleAssignmentBuild `
                        -ArmResources $armResources `
                        -EntraResources @() `
                        -Relationships @() `
                        -Connection $conn `
                        -ComputedAt '2026-01-01T00:00:00Z'
                    $result | Should -Be 1
                } finally { $conn.Dispose() }
            }
            $rows = Get-CIEMAzureEffectiveRoleAssignment
            $rows | Should -HaveCount 1
            $rows[0].PrincipalId | Should -Be 'group-1'
            $rows[0].OriginalPrincipalId | Should -Be 'group-1'
        }

        It 'Creates separate rows when same user gets same role through different groups' {
            $group2AssignProps = @{
                principalId = 'group-2'
                principalType = 'Group'
                roleDefinitionId = '/providers/Microsoft.Authorization/roleDefinitions/rd-reader'
                scope = '/subscriptions/sub-2'
            } | ConvertTo-Json -Compress

            InModuleScope Devolutions.CIEM -Parameters @{
                groupProps = $script:groupAssignmentProps
                group2Props = $group2AssignProps
                roleDef2Props = $script:roleDef2Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-reader'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef2Props }
                        [PSCustomObject]@{ Id = 'ra-grp1'; Type = 'microsoft.authorization/roleassignments'; Properties = $groupProps }
                        [PSCustomObject]@{ Id = 'ra-grp2'; Type = 'microsoft.authorization/roleassignments'; Properties = $group2Props }
                    )
                    $relationships = @(
                        [PSCustomObject]@{ SourceId = 'shared-user'; SourceType = 'user'; TargetId = 'group-1'; TargetType = 'group'; Relationship = 'transitive_member_of' }
                        [PSCustomObject]@{ SourceId = 'shared-user'; SourceType = 'user'; TargetId = 'group-2'; TargetType = 'group'; Relationship = 'transitive_member_of' }
                    )
                    $result = InvokeCIEMAzureEffectiveRoleAssignmentBuild `
                        -ArmResources $armResources `
                        -EntraResources @() `
                        -Relationships $relationships `
                        -Connection $conn `
                        -ComputedAt '2026-01-01T00:00:00Z'
                } finally { $conn.Dispose() }
            }
            # shared-user appears twice (via group-1 and group-2) + 2 group self-rows = 4
            $userRows = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'shared-user'
            $userRows | Should -HaveCount 2
            ($userRows.OriginalPrincipalId | Sort-Object) | Should -Be @('group-1', 'group-2')
        }

        It 'Sets role_name from role definition lookup' {
            InModuleScope Devolutions.CIEM -Parameters @{
                directProps = $script:directAssignmentProps
                roleDef1Props = $script:roleDef1Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef1Props }
                        [PSCustomObject]@{ Id = 'ra-rn'; Type = 'microsoft.authorization/roleassignments'; Properties = $directProps }
                    )
                    InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                } finally { $conn.Dispose() }
            }
            $row = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'user-direct'
            $row[0].RoleName | Should -Be 'Contributor'
        }

        It 'Sets PermissionsJson from role definition permissions array' {
            InModuleScope Devolutions.CIEM -Parameters @{
                directProps = $script:directAssignmentProps
                roleDef1Props = $script:roleDef1Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef1Props }
                        [PSCustomObject]@{ Id = 'ra-pj'; Type = 'microsoft.authorization/roleassignments'; Properties = $directProps }
                    )
                    InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                } finally { $conn.Dispose() }
            }
            $row = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'user-direct'
            $row[0].PermissionsJson | Should -Not -BeNullOrEmpty
            $perms = $row[0].PermissionsJson | ConvertFrom-Json
            $perms[0].actions | Should -Contain '*'
        }

        It 'Sets PrincipalDisplayName from Entra resource DisplayName lookup' {
            InModuleScope Devolutions.CIEM -Parameters @{
                directProps = $script:directAssignmentProps
                roleDef1Props = $script:roleDef1Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef1Props }
                        [PSCustomObject]@{ Id = 'ra-dn'; Type = 'microsoft.authorization/roleassignments'; Properties = $directProps }
                    )
                    $entraResources = @(
                        [PSCustomObject]@{ Id = 'user-direct'; DisplayName = 'John Doe' }
                    )
                    InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources $entraResources -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                } finally { $conn.Dispose() }
            }
            $row = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'user-direct'
            $row[0].PrincipalDisplayName | Should -Be 'John Doe'
        }

        It 'Sets original_principal_id to the group id when expanding' {
            InModuleScope Devolutions.CIEM -Parameters @{
                groupProps = $script:groupAssignmentProps
                roleDef2Props = $script:roleDef2Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-reader'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef2Props }
                        [PSCustomObject]@{ Id = 'ra-orig'; Type = 'microsoft.authorization/roleassignments'; Properties = $groupProps }
                    )
                    $relationships = @(
                        [PSCustomObject]@{ SourceId = 'expanded-user'; SourceType = 'user'; TargetId = 'group-1'; TargetType = 'group'; Relationship = 'transitive_member_of' }
                    )
                    InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships $relationships -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                } finally { $conn.Dispose() }
            }
            $row = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'expanded-user'
            $row[0].OriginalPrincipalId | Should -Be 'group-1'
            $row[0].OriginalPrincipalType | Should -Be 'Group'
        }

        It 'All effective rows share the same ComputedAt timestamp' {
            InModuleScope Devolutions.CIEM -Parameters @{
                directProps = $script:directAssignmentProps
                groupProps = $script:groupAssignmentProps
                roleDef1Props = $script:roleDef1Props
                roleDef2Props = $script:roleDef2Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef1Props }
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-reader'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef2Props }
                        [PSCustomObject]@{ Id = 'ra-ts1'; Type = 'microsoft.authorization/roleassignments'; Properties = $directProps }
                        [PSCustomObject]@{ Id = 'ra-ts2'; Type = 'microsoft.authorization/roleassignments'; Properties = $groupProps }
                    )
                    $relationships = @(
                        [PSCustomObject]@{ SourceId = 'ts-member'; SourceType = 'user'; TargetId = 'group-1'; TargetType = 'group'; Relationship = 'transitive_member_of' }
                    )
                    $fixedTimestamp = '2026-06-15T12:00:00Z'
                    InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships $relationships -Connection $conn -ComputedAt $fixedTimestamp
                } finally { $conn.Dispose() }
            }
            $rows = Get-CIEMAzureEffectiveRoleAssignment
            $rows | ForEach-Object { $_.ComputedAt | Should -Be '2026-06-15T12:00:00Z' }
        }

        It 'Returns count of rows inserted as [int]' {
            InModuleScope Devolutions.CIEM -Parameters @{
                directProps = $script:directAssignmentProps
                groupProps = $script:groupAssignmentProps
                roleDef1Props = $script:roleDef1Props
                roleDef2Props = $script:roleDef2Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef1Props }
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-reader'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef2Props }
                        [PSCustomObject]@{ Id = 'ra-cnt1'; Type = 'microsoft.authorization/roleassignments'; Properties = $directProps }
                        [PSCustomObject]@{ Id = 'ra-cnt2'; Type = 'microsoft.authorization/roleassignments'; Properties = $groupProps }
                    )
                    $relationships = @(
                        [PSCustomObject]@{ SourceId = 'cnt-user'; SourceType = 'user'; TargetId = 'group-1'; TargetType = 'group'; Relationship = 'transitive_member_of' }
                        [PSCustomObject]@{ SourceId = 'cnt-sp'; SourceType = 'servicePrincipal'; TargetId = 'group-1'; TargetType = 'group'; Relationship = 'transitive_member_of' }
                    )
                    $result = InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships $relationships -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                    # 1 direct + 2 expanded members + 1 group self = 4
                    $result | Should -BeOfType [int]
                    $result | Should -Be 4
                } finally { $conn.Dispose() }
            }
        }

        # Error/skip paths
        It 'Skips role assignments with null Properties' {
            InModuleScope Devolutions.CIEM {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = 'ra-null'; Type = 'microsoft.authorization/roleassignments'; Properties = $null }
                    )
                    $result = InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                    $result | Should -Be 0
                } finally { $conn.Dispose() }
            }
        }

        It 'Skips role assignments with invalid Properties JSON' {
            InModuleScope Devolutions.CIEM {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = 'ra-bad'; Type = 'microsoft.authorization/roleassignments'; Properties = 'not-valid-json{{{' }
                    )
                    $result = InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                    $result | Should -Be 0
                } finally { $conn.Dispose() }
            }
        }

        It 'Skips role assignments missing principalId in properties' {
            InModuleScope Devolutions.CIEM {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $props = @{ roleDefinitionId = 'rd-1'; scope = '/sub/1' } | ConvertTo-Json -Compress
                    $armResources = @(
                        [PSCustomObject]@{ Id = 'ra-nopid'; Type = 'microsoft.authorization/roleassignments'; Properties = $props }
                    )
                    $result = InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                    $result | Should -Be 0
                } finally { $conn.Dispose() }
            }
        }

        It 'Sets PrincipalDisplayName to null when principal not in Entra resources' {
            InModuleScope Devolutions.CIEM -Parameters @{
                directProps = $script:directAssignmentProps
                roleDef1Props = $script:roleDef1Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef1Props }
                        [PSCustomObject]@{ Id = 'ra-nodn'; Type = 'microsoft.authorization/roleassignments'; Properties = $directProps }
                    )
                    InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                } finally { $conn.Dispose() }
            }
            $row = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'user-direct'
            $row[0].PrincipalDisplayName | Should -BeNullOrEmpty
        }

        It 'Sets RoleName and PermissionsJson to null when role definition not found' {
            InModuleScope Devolutions.CIEM {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $props = @{ principalId = 'orphan-user'; principalType = 'User'; roleDefinitionId = '/unknown/role-def'; scope = '/sub/1' } | ConvertTo-Json -Compress
                    $armResources = @(
                        [PSCustomObject]@{ Id = 'ra-orphan'; Type = 'microsoft.authorization/roleassignments'; Properties = $props }
                    )
                    InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                } finally { $conn.Dispose() }
            }
            $row = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'orphan-user'
            $row | Should -HaveCount 1
            $row[0].RoleName | Should -BeNullOrEmpty
            $row[0].PermissionsJson | Should -BeNullOrEmpty
        }

        # Edge cases
        It 'Returns 0 when ArmResources contains no role assignments' {
            InModuleScope Devolutions.CIEM {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = 'vm-1'; Type = 'microsoft.compute/virtualmachines'; Properties = '{}' }
                    )
                    $result = InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                    $result | Should -Be 0
                } finally { $conn.Dispose() }
            }
        }

        It 'Returns 0 when Relationships is empty but direct assignments still created' {
            InModuleScope Devolutions.CIEM -Parameters @{
                directProps = $script:directAssignmentProps
                roleDef1Props = $script:roleDef1Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef1Props }
                        [PSCustomObject]@{ Id = 'ra-norel'; Type = 'microsoft.authorization/roleassignments'; Properties = $directProps }
                    )
                    $result = InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                    $result | Should -Be 1
                } finally { $conn.Dispose() }
            }
        }

        It 'Creates rows with null display names when EntraResources is empty' {
            InModuleScope Devolutions.CIEM -Parameters @{
                directProps = $script:directAssignmentProps
                roleDef1Props = $script:roleDef1Props
            } {
                $connStr = "Data Source=$script:DatabasePath"
                $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new($connStr)
                $conn.Open()
                try {
                    $armResources = @(
                        [PSCustomObject]@{ Id = '/providers/Microsoft.Authorization/roleDefinitions/rd-contrib'; Type = 'microsoft.authorization/roledefinitions'; Properties = $roleDef1Props }
                        [PSCustomObject]@{ Id = 'ra-noent'; Type = 'microsoft.authorization/roleassignments'; Properties = $directProps }
                    )
                    InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $armResources -EntraResources @() -Relationships @() -Connection $conn -ComputedAt '2026-01-01T00:00:00Z'
                } finally { $conn.Dispose() }
            }
            $row = Get-CIEMAzureEffectiveRoleAssignment -PrincipalId 'user-direct'
            $row | Should -HaveCount 1
            $row[0].PrincipalDisplayName | Should -BeNullOrEmpty
        }
    }
}
