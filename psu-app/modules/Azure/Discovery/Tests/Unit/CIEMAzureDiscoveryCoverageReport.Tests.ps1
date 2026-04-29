BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    foreach ($schemaPath in @(
        (Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'),
        (Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql')
    )) {
        foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            Invoke-CIEMQuery -Query $statement.Trim() -AsNonQuery | Out-Null
        }
    }
}

Describe 'Azure Discovery Coverage Report' {
    BeforeEach {
        Invoke-CIEMQuery -Query "DELETE FROM azure_effective_role_assignments"
        Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships"
        Invoke-CIEMQuery -Query "DELETE FROM azure_resource_types"
        Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
    }

    Context 'Invoke-CIEMReport -Id azure.discovery.coverage' {
        It 'Returns a report result with collected coverage rows for the specified discovery run' {
            $run = New-CIEMAzureDiscoveryRun `
                -Scope 'All' `
                -Status 'Completed' `
                -StartedAt '2026-04-27T10:00:00Z' `
                -CompletedAt '2026-04-27T10:05:00Z' `
                -ArmTypeCount 2 `
                -ArmRowCount 3 `
                -EntraTypeCount 2 `
                -EntraRowCount 4

            Invoke-CIEMQuery -Query "INSERT INTO azure_resource_types (type, api_source, graph_table, resource_count, discovered_at, last_collected) VALUES ('microsoft.compute/virtualmachines', 'ARM', 'resources', 2, '2026-04-27T10:01:00Z', '2026-04-27T10:01:00Z')"
            Invoke-CIEMQuery -Query "INSERT INTO azure_resource_types (type, api_source, graph_table, resource_count, discovered_at, last_collected) VALUES ('user', 'Graph', NULL, 4, '2026-04-27T10:02:00Z', '2026-04-27T10:02:00Z')"
            Invoke-CIEMQuery -Query "INSERT INTO azure_resource_relationships (source_id, source_type, target_id, target_type, relationship, collected_at) VALUES ('group-1', 'group', 'user-1', 'user', 'memberOf', '2026-04-27T10:03:00Z')"
            New-CIEMAzureEffectiveRoleAssignment `
                -PrincipalId 'user-1' `
                -PrincipalType 'user' `
                -OriginalPrincipalId 'user-1' `
                -OriginalPrincipalType 'user' `
                -RoleDefinitionId 'role-1' `
                -RoleName 'Reader' `
                -Scope '/subscriptions/sub-1' `
                -ComputedAt '2026-04-27T10:04:00Z' | Out-Null

            $result = Invoke-CIEMReport -Id 'azure.discovery.coverage' -Parameter @{ RunId = $run.Id }
            $results = @($result.Rows)

            $result.GetType().Name | Should -Be 'CIEMReportResult'
            $result.ReportId | Should -Be 'azure.discovery.coverage'
            $result.Title | Should -Be 'Azure Discovery Coverage'
            $result.Columns | Should -Contain 'Area'
            $result.Columns | Should -Contain 'Status'
            $result.Visuals | Should -Contain 'coverage-status-summary'
            $result.Context.RunId | Should -Be $run.Id
            $results | Should -HaveCount 4
            $results | ForEach-Object { $_.GetType().Name | Should -Be 'CIEMAzureDiscoveryCoverageReport' }

            $arm = $results | Where-Object Area -eq 'ARM resources'
            $arm.Provider | Should -Be 'Azure'
            $arm.RunId | Should -Be $run.Id
            $arm.SourceApi | Should -Be 'Azure Resource Graph'
            $arm.Status | Should -Be 'Collected'
            $arm.TypeCount | Should -Be 2
            $arm.RowCount | Should -Be 3
            $arm.MissingReason | Should -BeNullOrEmpty
            $arm.Evidence | Should -Be 'microsoft.compute/virtualmachines=2'

            $relationships = $results | Where-Object Area -eq 'Entra relationships'
            $relationships.Status | Should -Be 'Collected'
            $relationships.RowCount | Should -Be 1
            $relationships.Evidence | Should -Be 'azure_resource_relationships=1'

            $assignments = $results | Where-Object Area -eq 'Effective role assignments'
            $assignments.Status | Should -Be 'Collected'
            $assignments.RowCount | Should -Be 1
            $assignments.Evidence | Should -Be 'azure_effective_role_assignments=1'
        }

        It 'Reports skipped Entra areas for an ARM-only discovery run' {
            $run = New-CIEMAzureDiscoveryRun `
                -Scope 'ARM' `
                -Status 'Completed' `
                -StartedAt '2026-04-27T11:00:00Z' `
                -CompletedAt '2026-04-27T11:05:00Z' `
                -ArmTypeCount 1 `
                -ArmRowCount 2

            $result = Invoke-CIEMReport -Id 'azure.discovery.coverage' -Parameter @{ RunId = $run.Id }
            $results = @($result.Rows)
            $entra = $results | Where-Object Area -eq 'Entra resources'
            $relationships = $results | Where-Object Area -eq 'Entra relationships'

            $entra.Status | Should -Be 'Skipped'
            $entra.MissingReason | Should -Be 'Run scope ARM did not include this area'
            $relationships.Status | Should -Be 'Skipped'
            $relationships.MissingReason | Should -Be 'Run scope ARM did not include this area'
        }

        It 'Reports missing areas with exact discovery failure evidence' {
            $run = New-CIEMAzureDiscoveryRun `
                -Scope 'All' `
                -Status 'Partial' `
                -StartedAt '2026-04-27T12:00:00Z' `
                -CompletedAt '2026-04-27T12:05:00Z' `
                -ArmTypeCount 1 `
                -ArmRowCount 10 `
                -WarningCount 2 `
                -ErrorMessage 'Entra entity collection failed: Access denied loading Graph/users - missing permissions; Entra relationship collection failed: signInActivity unavailable because Microsoft Entra ID P1 is not enabled'

            $result = Invoke-CIEMReport -Id 'azure.discovery.coverage' -Parameter @{ RunId = $run.Id }
            $results = @($result.Rows)
            $entra = $results | Where-Object Area -eq 'Entra resources'
            $relationships = $results | Where-Object Area -eq 'Entra relationships'

            $entra.Status | Should -Be 'Missing'
            $entra.MissingReason | Should -Be 'Entra entity collection failed: Access denied loading Graph/users - missing permissions'
            $relationships.Status | Should -Be 'Missing'
            $relationships.MissingReason | Should -Be 'Entra relationship collection failed: signInActivity unavailable because Microsoft Entra ID P1 is not enabled'
        }

        It 'Uses the latest completed discovery run when RunId is omitted' {
            New-CIEMAzureDiscoveryRun `
                -Scope 'All' `
                -Status 'Completed' `
                -StartedAt '2026-04-27T09:00:00Z' `
                -CompletedAt '2026-04-27T09:05:00Z' `
                -ArmTypeCount 1 `
                -ArmRowCount 1 | Out-Null
            $latest = New-CIEMAzureDiscoveryRun `
                -Scope 'All' `
                -Status 'Partial' `
                -StartedAt '2026-04-27T13:00:00Z' `
                -CompletedAt '2026-04-27T13:05:00Z' `
                -ArmTypeCount 3 `
                -ArmRowCount 30
            New-CIEMAzureDiscoveryRun `
                -Scope 'All' `
                -Status 'Running' `
                -StartedAt '2026-04-27T14:00:00Z' | Out-Null

            $result = Invoke-CIEMReport -Id 'azure.discovery.coverage'
            $results = @($result.Rows)

            $result.Context.RunId | Should -Be $latest.Id
            $results[0].RunId | Should -Be $latest.Id
            ($results | Where-Object Area -eq 'ARM resources').RowCount | Should -Be 30
        }

        It 'Accepts a CIEMReport definition from the pipeline' {
            $run = New-CIEMAzureDiscoveryRun `
                -Scope 'All' `
                -Status 'Completed' `
                -StartedAt '2026-04-27T15:00:00Z' `
                -CompletedAt '2026-04-27T15:05:00Z' `
                -ArmTypeCount 1 `
                -ArmRowCount 7

            $result = Get-CIEMReport -Id 'azure.discovery.coverage' | Invoke-CIEMReport -Parameter @{ RunId = $run.Id }

            $result.ReportId | Should -Be 'azure.discovery.coverage'
            $result.Context.RunId | Should -Be $run.Id
            ($result.Rows | Where-Object Area -eq 'ARM resources').RowCount | Should -Be 7
        }

        It 'Throws when the requested discovery run does not exist' {
            { Invoke-CIEMReport -Id 'azure.discovery.coverage' -Parameter @{ RunId = 404 } } | Should -Throw "Discovery run 404 was not found."
        }
    }
}
