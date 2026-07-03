BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Discovery' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    $script:GraphSchemaPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'graph_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $script:GraphSchemaPath -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    function AddTestExposureSnapshotItem {
        param(
            [Parameter(Mandatory)][int]$DiscoveryRunId,
            [Parameter(Mandatory)][string]$ExposureKey,
            [Parameter(Mandatory)][string]$Severity,
            [Parameter(Mandatory)][int]$SeverityRank,
            [Parameter(Mandatory)][string]$IdentityName,
            [Parameter()][string]$TargetName = '/subscriptions/test-sub'
        )

        $ErrorActionPreference = 'Stop'

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
        $changeColumns = @(Invoke-CIEMQuery -Query "PRAGMA table_info('ciem_exposure_changes')")
        $changeColumns.name | Should -Contain 'title'
        $snapshotColumns = @(Invoke-CIEMQuery -Query "PRAGMA table_info('ciem_exposure_snapshot_items')")
        $snapshotIndexes = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'ciem_exposure_snapshot_items'")

        $snapshotColumns.name | Should -Contain 'progress_key'
        $snapshotIndexes.name | Should -Contain 'idx_ciem_exposure_snapshot_progress_key'
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
        $attackPathExposure.ImpactedIdentityId | Should -Be 'user-snapshot'
        $attackPathExposure.ImpactedIdentityName | Should -Be 'Snapshot User'
        $attackPathExposure.ImpactedIdentityType | Should -Be 'User'
        $attackPathExposure.ImpactedResourceName | Should -Be 'Test Subscription'
        $attackPathExposure.ProgressKey | Should -Match '^attack-path:[a-f0-9]{64}$'

        $storedAttackPath = Invoke-CIEMQuery -Query "SELECT progress_key FROM ciem_exposure_snapshot_items WHERE discovery_run_id = @run_id AND exposure_type = 'AttackPath'" -Parameters @{ run_id = $run.Id }
        $storedAttackPath.progress_key | Should -Be $attackPathExposure.ProgressKey
    }

    It 'builds stable attack path progress keys from semantic path shape' {
        $keys = InModuleScope Devolutions.CIEM {
            $first = [CIEMAttackPath]::new()
            $first.Id = 'volatile-1'
            $first.RuleId = 'rule-1'
            $first.Path = @(
                [pscustomobject]@{ id = 'user-1'; kind = 'EntraUser'; display_name = 'Original User' }
                [pscustomobject]@{ id = 'sub-1'; kind = 'AzureSubscription'; display_name = 'Original Subscription' }
            )
            $first.Edges = @(
                [pscustomobject]@{ id = 1; source_id = 'user-1'; target_id = 'sub-1'; kind = 'HasRole'; properties = '{"role":"Owner"}'; evaluated_at = '2026-01-01T00:00:00Z' }
            )

            $second = [CIEMAttackPath]::new()
            $second.Id = 'volatile-2'
            $second.RuleId = 'rule-1'
            $second.Path = @(
                [pscustomobject]@{ id = 'user-1'; kind = 'EntraUser'; display_name = 'Renamed User' }
                [pscustomobject]@{ id = 'sub-1'; kind = 'AzureSubscription'; display_name = 'Renamed Subscription' }
            )
            $second.Edges = @(
                [pscustomobject]@{ id = 99; source_id = 'user-1'; target_id = 'sub-1'; kind = 'HasRole'; properties = '{"role":"Owner"}'; evaluated_at = '2026-02-01T00:00:00Z' }
            )

            @(
                GetCIEMStableAttackPathProgressKey -AttackPath $first
                GetCIEMStableAttackPathProgressKey -AttackPath $second
            )
        }

        $keys[0] | Should -Be $keys[1]
        $keys[0] | Should -Match '^attack-path:[a-f0-9]{64}$'
    }

    It 'does not create change records when attack path IDs change but progress key is stable' {
        $previousRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-06T01:00:00Z' -CompletedAt '2026-05-06T01:10:00Z'
        $currentRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-07T01:00:00Z' -CompletedAt '2026-05-07T01:10:00Z'
        $progressKey = 'attack-path:stable-semantic-path'

        Invoke-CIEMQuery -Query @"
INSERT INTO ciem_exposure_snapshot_items (
    discovery_run_id, exposure_key, exposure_type, severity, severity_rank,
    impacted_identity_id, impacted_identity_name, impacted_identity_type,
    impacted_resource_id, impacted_resource_name, title, state_json, evidence,
    observed_at, progress_key
)
VALUES
(
    @previous_run_id, 'attack-path:volatile-previous', 'AttackPath', 'High', 2,
    'user-1', 'Stable User', 'User',
    '/subscriptions/test-sub', 'Test Subscription', 'Stable attack path',
    @state_json, 'Stable User -> Test Subscription', '2026-05-06T01:10:00Z',
    @progress_key
),
(
    @current_run_id, 'attack-path:volatile-current', 'AttackPath', 'High', 2,
    'user-1', 'Stable User', 'User',
    '/subscriptions/test-sub', 'Test Subscription', 'Stable attack path',
    @state_json, 'Stable User -> Test Subscription', '2026-05-07T01:10:00Z',
    @progress_key
)
"@ -Parameters @{
            previous_run_id = $previousRun.Id
            current_run_id  = $currentRun.Id
            state_json      = @{ PatternName = 'Stable attack path'; PathChain = 'Stable User -> Test Subscription' } | ConvertTo-Json -Compress
            progress_key    = $progressKey
        } -AsNonQuery | Out-Null

        $changes = @(Compare-CIEMExposureSnapshot -PreviousDiscoveryRunId $previousRun.Id -CurrentDiscoveryRunId $currentRun.Id)

        $changes | Should -HaveCount 0
        @(Get-CIEMExposureChange -CurrentDiscoveryRunId $currentRun.Id) | Should -HaveCount 0
    }

    It 'persists deterministic new risk, removed risk, and risk increase records from two snapshots' {
        $previousRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-06T01:00:00Z' -CompletedAt '2026-05-06T01:10:00Z'
        $currentRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-07T01:00:00Z' -CompletedAt '2026-05-07T01:10:00Z'

        AddTestExposureSnapshotItem -DiscoveryRunId $previousRun.Id -ExposureKey 'identity:stable-risk' -Severity 'Medium' -SeverityRank 3 -IdentityName 'Stable Risk User'
        AddTestExposureSnapshotItem -DiscoveryRunId $previousRun.Id -ExposureKey 'identity:removed-risk' -Severity 'High' -SeverityRank 2 -IdentityName 'Removed Risk User'
        AddTestExposureSnapshotItem -DiscoveryRunId $currentRun.Id -ExposureKey 'identity:stable-risk' -Severity 'Critical' -SeverityRank 1 -IdentityName 'Stable Risk User'
        AddTestExposureSnapshotItem -DiscoveryRunId $currentRun.Id -ExposureKey 'identity:new-risk' -Severity 'High' -SeverityRank 2 -IdentityName 'New Risk User'

        $changes = Compare-CIEMExposureSnapshot -PreviousDiscoveryRunId $previousRun.Id -CurrentDiscoveryRunId $currentRun.Id

        $changes | Should -HaveCount 3
        @($changes | Where-Object ChangeType -eq 'NewRisk')[0].Id | Should -Be "$($currentRun.Id):NewRisk:identity:new-risk"
        @($changes | Where-Object ChangeType -eq 'RemovedRisk')[0].PreviousSeverity | Should -Be 'High'
        @($changes | Where-Object ChangeType -eq 'RiskIncrease')[0].CurrentSeverity | Should -Be 'Critical'

        $stored = @(Get-CIEMExposureChange -CurrentDiscoveryRunId $currentRun.Id)
        $stored | Should -HaveCount 3
    }

    It 'persists attack path exposure-change titles and distinct target identifiers' {
        $previousRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-06T01:00:00Z' -CompletedAt '2026-05-06T01:10:00Z'
        $currentRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-07T01:00:00Z' -CompletedAt '2026-05-07T01:10:00Z'

        Invoke-CIEMQuery -Query @"
INSERT INTO ciem_exposure_snapshot_items (
    discovery_run_id, exposure_key, exposure_type, severity, severity_rank,
    impacted_identity_id, impacted_identity_name, impacted_identity_type,
    impacted_resource_id, impacted_resource_name, title, state_json, evidence,
    observed_at
)
VALUES (
    @run_id, 'attack-path:public-nsg', 'AttackPath', 'High', 2,
    '', '', '',
    '/subscriptions/prod/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg-public',
    'Public NSG', 'Management port open to the internet', '{}', 'Internet -> Public NSG',
    '2026-05-07T01:10:00Z'
)
"@ -Parameters @{ run_id = $currentRun.Id } -AsNonQuery | Out-Null

        $changes = @(Compare-CIEMExposureSnapshot -PreviousDiscoveryRunId $previousRun.Id -CurrentDiscoveryRunId $currentRun.Id)

        $changes | Should -HaveCount 1
        $changes[0].Title | Should -Be 'Management port open to the internet'
        $changes[0].ImpactedResourceId | Should -Be '/subscriptions/prod/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg-public'
        $changes[0].ImpactedResourceName | Should -Be 'Public NSG'

        $stored = @(Get-CIEMExposureChange -CurrentDiscoveryRunId $currentRun.Id)
        $stored | Should -HaveCount 1
        $stored[0].Title | Should -Be 'Management port open to the internet'
        $stored[0].ImpactedResourceId | Should -Be '/subscriptions/prod/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg-public'
        $stored[0].ImpactedResourceName | Should -Be 'Public NSG'
    }

    It 'does not create change records for newly observed low-risk exposure' {
        $previousRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-06T01:00:00Z' -CompletedAt '2026-05-06T01:10:00Z'
        $currentRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-07T01:00:00Z' -CompletedAt '2026-05-07T01:10:00Z'

        AddTestExposureSnapshotItem -DiscoveryRunId $currentRun.Id -ExposureKey 'identity:low-risk' -Severity 'Low' -SeverityRank 4 -IdentityName 'Low Risk User'

        $changes = Compare-CIEMExposureSnapshot -PreviousDiscoveryRunId $previousRun.Id -CurrentDiscoveryRunId $currentRun.Id

        $changes | Should -HaveCount 0
    }

    It 'backfills pre-title attack path change records for connector previews' {
        try {
            Invoke-CIEMQuery -Query 'DROP TABLE ciem_exposure_changes' -AsNonQuery | Out-Null
            Invoke-CIEMQuery -Query @"
CREATE TABLE ciem_exposure_changes (
    id TEXT PRIMARY KEY,
    previous_discovery_run_id INTEGER,
    current_discovery_run_id INTEGER NOT NULL,
    exposure_key TEXT NOT NULL,
    change_type TEXT NOT NULL,
    exposure_type TEXT NOT NULL,
    severity TEXT NOT NULL,
    severity_rank INTEGER NOT NULL,
    previous_severity TEXT,
    current_severity TEXT,
    impacted_identity_id TEXT,
    impacted_identity_name TEXT,
    impacted_identity_type TEXT,
    impacted_resource_id TEXT,
    impacted_resource_name TEXT,
    first_seen_at TEXT NOT NULL,
    previous_state_json TEXT,
    current_state_json TEXT,
    evidence TEXT NOT NULL,
    created_at TEXT NOT NULL
)
"@ -AsNonQuery | Out-Null

            Invoke-CIEMQuery -Query @"
INSERT INTO ciem_exposure_changes (
    id, previous_discovery_run_id, current_discovery_run_id, exposure_key, change_type,
    exposure_type, severity, severity_rank, previous_severity, current_severity,
    impacted_identity_id, impacted_identity_name, impacted_identity_type,
    impacted_resource_id, impacted_resource_name, first_seen_at,
    previous_state_json, current_state_json, evidence, created_at
)
VALUES (
    '99:NewRisk:attack-path:public-nsg', 1, 99, 'attack-path:public-nsg', 'NewRisk',
    'AttackPath', 'High', 2, '', 'High',
    '', '', '',
    '/subscriptions/prod/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg-public',
    'Public NSG', '2026-05-07T01:10:00Z',
    NULL, @current_state_json, 'Internet -> Public NSG', '2026-05-07T01:10:00Z'
)
"@ -Parameters @{
                current_state_json = @{
                    PatternName = 'Management port open to the internet'
                    PathChain   = 'Internet -> Public NSG'
                } | ConvertTo-Json -Compress
            } -AsNonQuery | Out-Null

            InModuleScope Devolutions.CIEM {
                UpdateCIEMExposureChangeStorageSchema
            }

            $stored = @(Get-CIEMExposureChange -CurrentDiscoveryRunId 99)
            $stored | Should -HaveCount 1
            $stored[0].Title | Should -Be 'Management port open to the internet'

            $preview = @(Get-CIEMConnectorPayloadPreview -SignalType ExposureChange -ConnectorType Alert -Limit 1)[0]
            $payload = $preview.PayloadJson | ConvertFrom-Json
            $payload.title | Should -Be 'Management port open to the internet'
            $payload.target.id | Should -Be '/subscriptions/prod/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg-public'
            $payload.target.name | Should -Be 'Public NSG'
        }
        finally {
            Invoke-CIEMQuery -Query 'DROP TABLE IF EXISTS ciem_exposure_changes' -AsNonQuery | Out-Null
            Invoke-CIEMQuery -Query (Get-Content $script:GraphSchemaPath -Raw)
        }
    }
}
