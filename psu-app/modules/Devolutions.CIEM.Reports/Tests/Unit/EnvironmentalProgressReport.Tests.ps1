BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'CIEM environmental progress report' {
    BeforeEach {
        $script:TestDatabasePath = Join-Path $TestDrive ("ciem-" + [guid]::NewGuid().ToString('N') + '.db')
        New-CIEMDatabase -Path $script:TestDatabasePath

        InModuleScope Devolutions.CIEM -Parameters @{ DatabasePath = $script:TestDatabasePath } {
            param([string]$DatabasePath)
            $script:DatabasePath = $DatabasePath
        }
    }

    function script:Add-ProgressDiscoveryRun {
        param(
            [Parameter(Mandatory)][int]$Id,
            [Parameter(Mandatory)][string]$CompletedAt,
            [string]$Status = 'Completed',
            [string]$Scope = 'All',
            [string]$StartedAt = '2026-05-01T00:00:00Z',
            [string]$AttackPathScopeHash = 'attack-scope',
            [string]$DiscoveryScopeHash = 'discovery-scope',
            [string]$ExposureSnapshotCompletedAt = $CompletedAt
        )

        Invoke-CIEMQuery -Query @"
INSERT INTO azure_discovery_runs (
    id, psu_job_id, scope, status, started_at, completed_at,
    attack_path_scope_hash, discovery_scope_hash, exposure_snapshot_completed_at
)
VALUES (
    @id, @psu_job_id, @scope, @status, @started_at, @completed_at,
    @attack_path_scope_hash, @discovery_scope_hash, @exposure_snapshot_completed_at
)
"@ -Parameters @{
            id                             = $Id
            psu_job_id                     = -$Id
            scope                          = $Scope
            status                         = $Status
            started_at                     = $StartedAt
            completed_at                   = $CompletedAt
            attack_path_scope_hash         = $AttackPathScopeHash
            discovery_scope_hash           = $DiscoveryScopeHash
            exposure_snapshot_completed_at = $ExposureSnapshotCompletedAt
        } -AsNonQuery | Out-Null
    }

    function script:Add-ProgressScanRun {
        param(
            [Parameter(Mandatory)][string]$Id,
            [Parameter(Mandatory)][int]$DiscoveryRunId,
            [Parameter(Mandatory)][string]$StartedAt,
            [Parameter(Mandatory)][string]$CompletedAt,
            [string]$ProgressScopeHash = 'same-scope',
            [string]$Status = 'Completed',
            [int]$ProgressEligible = 1,
            [string[]]$Providers = @('Azure')
        )

        $primaryProviderId = if ($Providers[0] -eq 'AWS') { 'aws' } else { 'azure' }
        Invoke-CIEMQuery -Query @"
INSERT INTO scan_runs (
    id, provider_id, scan_type, status, resource_providers, include_passed,
    started_at, completed_at, duration_seconds, total_results, failed_results,
    passed_results, skipped_results, manual_results, discovery_run_id,
    provider_explicit, progress_eligible, progress_scope_hash
)
VALUES (
    @id, @provider_id, 'checks', @status, NULL, 1,
    @started_at, @completed_at, 60, 0, 0, 0, 0, 0, @discovery_run_id,
    1, @progress_eligible, @progress_scope_hash
)
"@ -Parameters @{
            id                  = $Id
            provider_id         = $primaryProviderId
            status              = $Status
            started_at          = $StartedAt
            completed_at        = $CompletedAt
            discovery_run_id    = $DiscoveryRunId
            progress_eligible   = $ProgressEligible
            progress_scope_hash = $ProgressScopeHash
        } -AsNonQuery | Out-Null

        foreach ($provider in $Providers) {
            Invoke-CIEMQuery -Query "INSERT INTO scan_run_providers (scan_run_id, provider) VALUES (@scan_run_id, @provider)" -Parameters @{
                scan_run_id = $Id
                provider    = $provider
            } -AsNonQuery | Out-Null
        }
    }

    function script:Add-AttackPathSnapshotItem {
        param(
            [Parameter(Mandatory)][int]$DiscoveryRunId,
            [Parameter(Mandatory)][string]$ProgressKey,
            [Parameter(Mandatory)][string]$Title,
            [string]$Severity = 'High',
            [int]$SeverityRank = 2,
            [string]$Identity = 'Privileged identity',
            [string]$Resource = 'Privileged resource'
        )

        Invoke-CIEMQuery -Query @"
INSERT INTO ciem_exposure_snapshot_items (
    discovery_run_id, exposure_key, exposure_type, severity, severity_rank,
    impacted_identity_id, impacted_identity_name, impacted_identity_type,
    impacted_resource_id, impacted_resource_name, title, state_json, evidence,
    observed_at, progress_key
)
VALUES (
    @discovery_run_id, @exposure_key, 'AttackPath', @severity, @severity_rank,
    @identity_id, @identity, 'User', @resource_id, @resource, @title, '{}',
    @evidence, '2026-05-01T00:00:00Z', @progress_key
)
"@ -Parameters @{
            discovery_run_id = $DiscoveryRunId
            exposure_key     = "attack-path:$([guid]::NewGuid().ToString('N'))"
            severity         = $Severity
            severity_rank    = $SeverityRank
            identity_id      = "identity-$ProgressKey"
            identity         = $Identity
            resource_id      = "resource-$ProgressKey"
            resource         = $Resource
            title            = $Title
            evidence         = "Attack path evidence for $Title"
            progress_key     = $ProgressKey
        } -AsNonQuery | Out-Null
    }

    function script:Add-FailedScanResult {
        param(
            [Parameter(Mandatory)][string]$ScanRunId,
            [Parameter(Mandatory)][string]$CheckId,
            [Parameter(Mandatory)][string]$ResourceId,
            [string]$Title = 'Failed check title',
            [string]$Severity = 'High',
            [string]$ResourceName = 'Failed resource'
        )

        $snapshot = @{
            id          = $CheckId
            provider    = 'Azure'
            service     = 'Entra'
            title       = $Title
            description = 'Historical description'
            risk        = 'Historical risk'
            severity    = $Severity
            remediation = @{ text = 'Historical remediation'; url = 'https://example.invalid/remediation' }
            relatedUrl  = 'https://example.invalid/related'
        } | ConvertTo-Json -Compress -Depth 10

        Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO scan_run_check_snapshots (scan_run_id, check_id, snapshot_json) VALUES (@scan_run_id, @check_id, @snapshot_json)" -Parameters @{
            scan_run_id   = $ScanRunId
            check_id      = $CheckId
            snapshot_json = $snapshot
        } -AsNonQuery | Out-Null

        Invoke-CIEMQuery -Query @"
INSERT INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name, location)
VALUES (@scan_run_id, @check_id, 'FAIL', 'failed evidence', @resource_id, @resource_name, 'Global')
"@ -Parameters @{
            scan_run_id   = $ScanRunId
            check_id      = $CheckId
            resource_id   = $ResourceId
            resource_name = $ResourceName
        } -AsNonQuery | Out-Null
    }

    function script:Add-ComparableEvidencePair {
        Add-ProgressDiscoveryRun -Id 101 -StartedAt '2026-05-01T00:00:00Z' -CompletedAt '2026-05-01T00:10:00Z'
        Add-ProgressScanRun -Id 'baseline-scan' -DiscoveryRunId 101 -StartedAt '2026-05-01T00:10:00Z' -CompletedAt '2026-05-01T00:20:00Z'
        Add-ProgressDiscoveryRun -Id 202 -StartedAt '2026-05-02T00:00:00Z' -CompletedAt '2026-05-02T00:10:00Z'
        Add-ProgressScanRun -Id 'current-scan' -DiscoveryRunId 202 -StartedAt '2026-05-02T00:10:00Z' -CompletedAt '2026-05-02T00:20:00Z'
    }

    It 'selects the latest eligible scan per completed discovery' {
        Add-ProgressDiscoveryRun -Id 1 -StartedAt '2026-05-01T00:00:00Z' -CompletedAt '2026-05-01T00:10:00Z'
        Add-ProgressScanRun -Id 'older-scan' -DiscoveryRunId 1 -StartedAt '2026-05-01T00:10:00Z' -CompletedAt '2026-05-01T00:20:00Z'
        Add-ProgressScanRun -Id 'newer-scan' -DiscoveryRunId 1 -StartedAt '2026-05-01T00:21:00Z' -CompletedAt '2026-05-01T00:30:00Z'
        Add-ProgressDiscoveryRun -Id 2 -Scope ARM -StartedAt '2026-05-02T00:00:00Z' -CompletedAt '2026-05-02T00:10:00Z'
        Add-ProgressScanRun -Id 'scope-limited-scan' -DiscoveryRunId 2 -StartedAt '2026-05-02T00:10:00Z' -CompletedAt '2026-05-02T00:20:00Z'

        $points = InModuleScope Devolutions.CIEM { @(GetCIEMEnvironmentalProgressEvidencePoint) }

        $points | Should -HaveCount 1
        $points[0].DiscoveryRunId | Should -Be 1
        $points[0].ScanRunId | Should -Be 'newer-scan'
    }

    It 'returns status objects for no evidence, one evidence point, and comparable evidence pairs' {
        $none = InModuleScope Devolutions.CIEM { GetCIEMEnvironmentalProgressEvidencePair }
        $none.Status | Should -Be 'NoProgressData'

        Add-ProgressDiscoveryRun -Id 11 -StartedAt '2026-05-01T00:00:00Z' -CompletedAt '2026-05-01T00:10:00Z'
        Add-ProgressScanRun -Id 'single-scan' -DiscoveryRunId 11 -StartedAt '2026-05-01T00:10:00Z' -CompletedAt '2026-05-01T00:20:00Z'
        $single = InModuleScope Devolutions.CIEM { GetCIEMEnvironmentalProgressEvidencePair }
        $single.Status | Should -Be 'BaselineReady'
        $single.CurrentDiscoveryRunId | Should -Be 11

        Add-ProgressDiscoveryRun -Id 12 -StartedAt '2026-05-02T00:00:00Z' -CompletedAt '2026-05-02T00:10:00Z'
        Add-ProgressScanRun -Id 'current-scan' -DiscoveryRunId 12 -StartedAt '2026-05-02T00:10:00Z' -CompletedAt '2026-05-02T00:20:00Z'
        $pair = InModuleScope Devolutions.CIEM { GetCIEMEnvironmentalProgressEvidencePair }
        $pair.Status | Should -Be 'ProgressTracked'
        $pair.BaselineDiscoveryRunId | Should -Be 11
        $pair.CurrentDiscoveryRunId | Should -Be 12
        $pair.EvidencePairId | Should -Be 'baselineDiscovery:11|baselineScan:single-scan|currentDiscovery:12|currentScan:current-scan'
    }

    It 'reports fixed, remaining, and new attack-path and failed-check signals with burn-down context' {
        Add-ComparableEvidencePair
        Add-AttackPathSnapshotItem -DiscoveryRunId 101 -ProgressKey 'attack-fixed' -Title 'Fixed attack path'
        Add-AttackPathSnapshotItem -DiscoveryRunId 101 -ProgressKey 'attack-remaining' -Title 'Remaining attack path'
        Add-AttackPathSnapshotItem -DiscoveryRunId 202 -ProgressKey 'attack-remaining' -Title 'Remaining attack path'
        Add-AttackPathSnapshotItem -DiscoveryRunId 202 -ProgressKey 'attack-new' -Title 'New attack path'
        Add-FailedScanResult -ScanRunId 'baseline-scan' -CheckId 'check-fixed' -ResourceId 'resource-fixed' -Title 'Fixed failed check'
        Add-FailedScanResult -ScanRunId 'baseline-scan' -CheckId 'check-remaining' -ResourceId 'resource-remaining' -Title 'Remaining failed check'
        Add-FailedScanResult -ScanRunId 'current-scan' -CheckId 'check-remaining' -ResourceId 'resource-remaining' -Title 'Remaining failed check'

        $result = Invoke-CIEMReport -Id 'azure.environmental.progress'

        $result.Context.Status | Should -Be 'ProgressTracked'
        $result.Context.BaselineIssueCount | Should -Be 4
        $result.Context.CurrentIssueCount | Should -Be 3
        $result.Context.FixedIssueCount | Should -Be 2
        $result.Context.FixedAttackPathCount | Should -Be 1
        $result.Context.FixedCheckCount | Should -Be 1
        $result.Context.RemainingIssueCount | Should -Be 2
        $result.Context.NewIssueCount | Should -Be 1
        $result.Context.BurnDownPercent | Should -Be 50.0
        $result.Context.ContextChipKeys | Should -Contain 'BaselineDiscoveryRunId'
        $result.Context.MetricKeys | Should -Contain 'FixedAttackPathCount'

        $result.Rows | Should -HaveCount 5
        $result.Rows.Status | Should -Contain 'Fixed'
        $result.Rows.Status | Should -Contain 'Remaining'
        $result.Rows.Status | Should -Contain 'New'
        $fixedCheck = $result.Rows | Where-Object { $_.SignalKey -eq 'check|check-fixed|resource-fixed' }
        $fixedCheck.SignalType | Should -Be 'Check'
        $fixedCheck.Title | Should -Be 'Fixed failed check'
        $fixedCheck.Identity | Should -BeNullOrEmpty
    }

    It 'returns selector-safe comparable pair options' {
        Add-ComparableEvidencePair

        $options = @(Get-CIEMEnvironmentalProgressEvidencePairOption)

        $options | Should -HaveCount 1
        $options[0].Value | Should -Be 'baselineDiscovery:101|baselineScan:baseline-scan|currentDiscovery:202|currentScan:current-scan'
        $options[0].Label | Should -Match '2026-05-01T00:20:00Z'
        $options[0].Label | Should -Match '2026-05-02T00:20:00Z'
    }

    It 'resolves an explicit pair id to the exact eligible scans after a newer scan exists for the baseline discovery' {
        Add-ProgressDiscoveryRun -Id 301 -StartedAt '2026-05-01T00:00:00Z' -CompletedAt '2026-05-01T00:10:00Z'
        Add-ProgressScanRun -Id 'older-baseline-scan' -DiscoveryRunId 301 -StartedAt '2026-05-01T00:10:00Z' -CompletedAt '2026-05-01T00:20:00Z'
        Add-ProgressScanRun -Id 'newer-baseline-scan' -DiscoveryRunId 301 -StartedAt '2026-05-01T00:21:00Z' -CompletedAt '2026-05-01T00:30:00Z'
        Add-ProgressDiscoveryRun -Id 302 -StartedAt '2026-05-02T00:00:00Z' -CompletedAt '2026-05-02T00:10:00Z'
        Add-ProgressScanRun -Id 'exact-current-scan' -DiscoveryRunId 302 -StartedAt '2026-05-02T00:10:00Z' -CompletedAt '2026-05-02T00:20:00Z'

        $pairId = 'baselineDiscovery:301|baselineScan:older-baseline-scan|currentDiscovery:302|currentScan:exact-current-scan'
        $result = Invoke-CIEMReport -Id 'azure.environmental.progress' -Parameter @{ EvidencePairId = $pairId }

        $result.Context.Status | Should -Be 'ProgressTracked'
        $result.Context.BaselineScanRunId | Should -Be 'older-baseline-scan'
        $result.Context.CurrentScanRunId | Should -Be 'exact-current-scan'
    }
}
