BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

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

    function Add-TestExposureSnapshotItem {
        param(
            [Parameter(Mandatory)][int]$DiscoveryRunId,
            [Parameter(Mandatory)][string]$ExposureKey,
            [Parameter(Mandatory)][string]$Severity,
            [Parameter(Mandatory)][int]$SeverityRank,
            [Parameter(Mandatory)][string]$IdentityName,
            [Parameter()][string]$TargetName = '/subscriptions/test-sub'
        )

        Invoke-CIEMQuery -Query @"
INSERT INTO ciem_exposure_snapshot_items (
    discovery_run_id, exposure_key, exposure_type, severity, severity_rank,
    impacted_identity_id, impacted_identity_name, impacted_identity_type,
    impacted_resource_id, impacted_resource_name, title, state_json, evidence,
    observed_at
)
VALUES (
    @discovery_run_id, @exposure_key, 'IdentityRisk', @severity, @severity_rank,
    @identity_id, @identity_name, 'User',
    @target_name, @target_name, @identity_name, @state_json, @evidence,
    '2026-05-07T00:00:00Z'
)
"@ -Parameters @{
            discovery_run_id = $DiscoveryRunId
            exposure_key     = $ExposureKey
            severity         = $Severity
            severity_rank    = $SeverityRank
            identity_id      = $ExposureKey.Replace('identity:', '')
            identity_name    = $IdentityName
            target_name      = $TargetName
            state_json       = (@{ Severity = $Severity; Identity = $IdentityName; Target = $TargetName } | ConvertTo-Json -Compress)
            evidence         = "$IdentityName exposure is $Severity"
        } -AsNonQuery | Out-Null
    }
}

Describe 'CIEM exposure change detection' {
    BeforeEach {
        Invoke-CIEMQuery -Query 'DELETE FROM ciem_exposure_changes' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM ciem_exposure_snapshot_items' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM attack_paths' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM graph_edges' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM graph_nodes' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM azure_discovery_runs' -AsNonQuery | Out-Null
    }

    It 'exports exposure snapshot and change commands' {
        Get-Command -Module Devolutions.CIEM -Name Save-CIEMExposureSnapshot -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command -Module Devolutions.CIEM -Name Compare-CIEMExposureSnapshot -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command -Module Devolutions.CIEM -Name Get-CIEMExposureChange -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'creates exposure snapshot and change tables during database setup' {
        $tables = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('ciem_exposure_snapshot_items', 'ciem_exposure_changes')")

        $tables | Should -HaveCount 2
    }

    It 'materializes current identity and attack path exposures for a discovery run' {
        $run = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-07T01:00:00Z' -CompletedAt '2026-05-07T01:10:00Z'
        $now = '2026-05-07T01:10:00Z'
        $identityProperties = @{ accountEnabled = $true; daysSinceSignIn = 120 } | ConvertTo-Json -Compress
        $edgeProperties = @{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/test-sub' } | ConvertTo-Json -Compress

        Save-CIEMGraphNode -Id 'user-snapshot' -Kind 'EntraUser' -DisplayName 'Snapshot User' -Provider 'azure' -Properties $identityProperties -CollectedAt $now
        Save-CIEMGraphNode -Id '/subscriptions/test-sub' -Kind 'AzureSubscription' -DisplayName 'Test Subscription' -Provider 'azure' -CollectedAt $now
        Save-CIEMGraphEdge -SourceId 'user-snapshot' -TargetId '/subscriptions/test-sub' -Kind 'HasRole' -Properties $edgeProperties -Computed 1 -CollectedAt $now

        Sync-CIEMAttackPathRuleCatalog | Out-Null
        $rule = @(Invoke-CIEMQuery -Query 'SELECT id, name, remediation, psu_script_name FROM attack_path_rules ORDER BY id LIMIT 1')[0]
        Invoke-CIEMQuery -Query @"
INSERT INTO attack_paths (
    id, rule_id, pattern_name, severity, category, remediation, psu_script_name,
    path_json, edges_json, path_chain, evaluated_at
)
VALUES (
    'attack-snapshot', @rule_id, @pattern_name, 'high', 'Identity', @remediation, @psu_script_name,
    @path_json, '[]', 'Snapshot User -> Test Subscription', @evaluated_at
)
"@ -Parameters @{
            rule_id         = $rule.id
            pattern_name    = $rule.name
            remediation     = $rule.remediation
            psu_script_name = $rule.psu_script_name
            path_json       = @(
                @{ id = 'user-snapshot'; kind = 'EntraUser'; display_name = 'Snapshot User' }
                @{ id = '/subscriptions/test-sub'; kind = 'AzureSubscription'; display_name = 'Test Subscription' }
            ) | ConvertTo-Json -Compress
            evaluated_at    = $now
        } -AsNonQuery | Out-Null

        $result = Save-CIEMExposureSnapshot -DiscoveryRunId $run.Id

        $result | Should -HaveCount 2
        $identityExposure = @($result | Where-Object ExposureKey -eq 'identity:user-snapshot')[0]
        $identityExposure.Severity | Should -Be 'Critical'
        $identityExposure.ImpactedIdentityName | Should -Be 'Snapshot User'
        $identityExposure.ImpactedResourceName | Should -Be '/subscriptions/test-sub'

        $attackPathExposure = @($result | Where-Object ExposureKey -eq 'attack-path:attack-snapshot')[0]
        $attackPathExposure.Severity | Should -Be 'High'
        $attackPathExposure.ImpactedIdentityName | Should -Be 'Snapshot User'
        $attackPathExposure.ImpactedResourceName | Should -Be 'Test Subscription'
    }

    It 'persists deterministic new risk, removed risk, and risk increase records from two snapshots' {
        $previousRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-06T01:00:00Z' -CompletedAt '2026-05-06T01:10:00Z'
        $currentRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-07T01:00:00Z' -CompletedAt '2026-05-07T01:10:00Z'

        Add-TestExposureSnapshotItem -DiscoveryRunId $previousRun.Id -ExposureKey 'identity:stable-risk' -Severity 'Medium' -SeverityRank 3 -IdentityName 'Stable Risk User'
        Add-TestExposureSnapshotItem -DiscoveryRunId $previousRun.Id -ExposureKey 'identity:removed-risk' -Severity 'High' -SeverityRank 2 -IdentityName 'Removed Risk User'
        Add-TestExposureSnapshotItem -DiscoveryRunId $currentRun.Id -ExposureKey 'identity:stable-risk' -Severity 'Critical' -SeverityRank 1 -IdentityName 'Stable Risk User'
        Add-TestExposureSnapshotItem -DiscoveryRunId $currentRun.Id -ExposureKey 'identity:new-risk' -Severity 'High' -SeverityRank 2 -IdentityName 'New Risk User'

        $changes = Compare-CIEMExposureSnapshot -PreviousDiscoveryRunId $previousRun.Id -CurrentDiscoveryRunId $currentRun.Id

        $changes | Should -HaveCount 3
        @($changes | Where-Object ChangeType -eq 'NewRisk')[0].Id | Should -Be "$($currentRun.Id):NewRisk:identity:new-risk"
        @($changes | Where-Object ChangeType -eq 'RemovedRisk')[0].PreviousSeverity | Should -Be 'High'
        @($changes | Where-Object ChangeType -eq 'RiskIncrease')[0].CurrentSeverity | Should -Be 'Critical'

        $stored = @(Get-CIEMExposureChange -CurrentDiscoveryRunId $currentRun.Id)
        $stored | Should -HaveCount 3
    }

    It 'does not create change records for newly observed low-risk exposure' {
        $previousRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-06T01:00:00Z' -CompletedAt '2026-05-06T01:10:00Z'
        $currentRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-07T01:00:00Z' -CompletedAt '2026-05-07T01:10:00Z'

        Add-TestExposureSnapshotItem -DiscoveryRunId $currentRun.Id -ExposureKey 'identity:low-risk' -Severity 'Low' -SeverityRank 4 -IdentityName 'Low Risk User'

        $changes = Compare-CIEMExposureSnapshot -PreviousDiscoveryRunId $previousRun.Id -CurrentDiscoveryRunId $currentRun.Id

        $changes | Should -HaveCount 0
    }
}
