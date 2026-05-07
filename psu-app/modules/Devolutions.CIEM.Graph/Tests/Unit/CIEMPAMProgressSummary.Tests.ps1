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
}

Describe 'Get-CIEMPAMProgressSummary' {
    BeforeEach {
        Invoke-CIEMQuery -Query 'DELETE FROM ciem_exposure_changes' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM ciem_exposure_snapshot_items' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM graph_edges' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM graph_nodes' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM azure_discovery_runs' -AsNonQuery | Out-Null

        Mock -ModuleName Devolutions.CIEM Get-CIEMDashboardNeedsAttention { @() }
    }

    It 'exports the PAM progress command' {
        Get-Command Get-CIEMPAMProgressSummary -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'returns DiscoveryRequired when no graph, baseline, or candidates exist' {
        $summary = Get-CIEMPAMProgressSummary

        $summary.Status | Should -Be 'DiscoveryRequired'
        $summary.ReadinessPercent | Should -Be 0
        $summary.PAMActionStatus | Should -Be 'NotScopedReadOnly'
        $summary.PAMCandidateCount | Should -Be 0
        @($summary.Stages | Where-Object Name -eq 'Outbound PAM actions')[0].Status | Should -Be 'NotScoped'
    }

    It 'computes exposure burndown, candidate counts, and read-only PAM stages' {
        Save-CIEMGraphNode -Id 'user-critical' -Kind 'EntraUser' -DisplayName 'Dormant Admin' -Provider 'azure' -CollectedAt '2026-05-07T00:00:00Z'

        $previousRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-06T01:00:00Z' -CompletedAt '2026-05-06T01:10:00Z'
        $currentRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-07T01:00:00Z' -CompletedAt '2026-05-07T01:10:00Z'

        foreach ($key in @('identity:old-1', 'identity:old-2', 'attack-path:old-3')) {
            Invoke-CIEMQuery -Query @"
INSERT INTO ciem_exposure_snapshot_items (
    discovery_run_id, exposure_key, exposure_type, severity, severity_rank,
    impacted_identity_name, impacted_resource_name, title, state_json, evidence, observed_at
)
VALUES (
    @run_id, @key, 'IdentityRisk', 'High', 2,
    'Dormant Admin', '/subscriptions/prod', @key, '{}', 'Previous exposure', '2026-05-06T01:10:00Z'
)
"@ -Parameters @{ run_id = $previousRun.Id; key = $key } -AsNonQuery | Out-Null
        }

        foreach ($key in @('identity:old-1', 'attack-path:new-1')) {
            Invoke-CIEMQuery -Query @"
INSERT INTO ciem_exposure_snapshot_items (
    discovery_run_id, exposure_key, exposure_type, severity, severity_rank,
    impacted_identity_name, impacted_resource_name, title, state_json, evidence, observed_at
)
VALUES (
    @run_id, @key, 'IdentityRisk', 'Critical', 1,
    'Dormant Admin', '/subscriptions/prod', @key, '{}', 'Current exposure', '2026-05-07T01:10:00Z'
)
"@ -Parameters @{ run_id = $currentRun.Id; key = $key } -AsNonQuery | Out-Null
        }

        Invoke-CIEMQuery -Query @"
INSERT INTO ciem_exposure_changes (
    id, previous_discovery_run_id, current_discovery_run_id, exposure_key, change_type,
    exposure_type, severity, severity_rank, title, previous_severity, current_severity,
    impacted_identity_name, impacted_resource_name, first_seen_at, evidence, created_at
)
VALUES (
    'pam-progress-change', @previous_run_id, @current_run_id, 'attack-path:new-1', 'RiskIncrease',
    'AttackPath', 'Critical', 1, 'PAM progress attack path', 'High', 'Critical',
    'Dormant Admin', '/subscriptions/prod', '2026-05-07T01:10:00Z', 'Exposure increased', '2026-05-07T01:10:00Z'
)
"@ -Parameters @{ previous_run_id = $previousRun.Id; current_run_id = $currentRun.Id } -AsNonQuery | Out-Null

        Mock -ModuleName Devolutions.CIEM Get-CIEMDashboardNeedsAttention {
            @(
                [PSCustomObject]@{
                    Id           = 'identity:user-critical'
                    SourceType   = 'Identity'
                    Severity     = 'Critical'
                    SeverityRank = 1
                    Title        = 'Dormant Admin'
                    Identity     = 'Dormant Admin'
                    IdentityId   = 'user-critical'
                    IdentityType = 'User'
                    Target       = '/subscriptions/prod'
                    Reason       = 'Holds privileged role with no sign-in activity for 120 days'
                    Evidence     = '1 entitlement(s); 1 privileged'
                }
                [PSCustomObject]@{
                    Id           = 'attack-path:public-vm'
                    SourceType   = 'AttackPath'
                    Severity     = 'High'
                    SeverityRank = 2
                    Title        = 'Management port open to the internet'
                    Identity     = 'Dormant Admin'
                    IdentityId   = ''
                    IdentityType = ''
                    Target       = 'Public VM'
                    Reason       = 'Attack path exposes Public VM'
                    Evidence     = 'Internet -> Public VM'
                }
            )
        }

        $summary = Get-CIEMPAMProgressSummary -Limit 5

        $summary.Status | Should -Be 'ProgressTracked'
        $summary.ReadinessPercent | Should -Be 100
        $summary.BaselineDiscoveryRunId | Should -Be $previousRun.Id
        $summary.CurrentDiscoveryRunId | Should -Be $currentRun.Id
        $summary.BaselineExposureCount | Should -Be 3
        $summary.CurrentExposureCount | Should -Be 2
        $summary.ExposureDelta | Should -Be -1
        $summary.RiskBurndownPercent | Should -Be 33.3
        $summary.ExposureChangeCount | Should -Be 1
        $summary.RiskIncreaseCount | Should -Be 1
        $summary.PAMCandidateCount | Should -Be 2
        $summary.JITCandidateCount | Should -Be 1
        $summary.BrokeredAccessCandidateCount | Should -Be 1
        @($summary.Candidates | Where-Object SourceType -eq 'Identity')[0].PAMCapability | Should -Be 'JIT elevation and approval workflow'
        @($summary.Candidates | Where-Object SourceType -eq 'AttackPath')[0].PAMCapability | Should -Be 'Access brokering and session governance'
    }

    It 'throws instead of mapping unsupported PAM candidate source types' {
        Mock -ModuleName Devolutions.CIEM Get-CIEMDashboardNeedsAttention {
            @(
                [PSCustomObject]@{
                    Id           = 'unsupported:1'
                    SourceType   = 'Unsupported'
                    Severity     = 'High'
                    SeverityRank = 2
                    Title        = 'Unsupported'
                    Identity     = 'Unsupported'
                    IdentityId   = ''
                    IdentityType = ''
                    Target       = 'Unsupported'
                    Reason       = 'Unsupported'
                    Evidence     = 'Unsupported'
                }
            )
        }

        { Get-CIEMPAMProgressSummary } | Should -Throw "Unsupported PAM progress source type 'Unsupported'."
    }
}
