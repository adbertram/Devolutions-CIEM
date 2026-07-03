BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'CIEM scan-run progress linking' {
    BeforeEach {
        $script:TestDatabasePath = Join-Path $TestDrive ("ciem-" + [guid]::NewGuid().ToString('N') + '.db')
        New-CIEMDatabase -Path $script:TestDatabasePath

        InModuleScope Devolutions.CIEM -Parameters @{ DatabasePath = $script:TestDatabasePath } {
            param([string]$DatabasePath)
            $script:DatabasePath = $DatabasePath
        }

        Mock -ModuleName Devolutions.CIEM ReadPSUCache { $null }
        Mock -ModuleName Devolutions.CIEM InvokeCIEMScan { @() }
    }

    function script:Add-TestDiscoveryRun {
        param(
            [Parameter(Mandatory)][int]$Id,
            [Parameter(Mandatory)][string]$Scope,
            [Parameter(Mandatory)][string]$Status,
            [Parameter(Mandatory)][string]$StartedAt,
            [string]$CompletedAt,
            [string]$AttackPathScopeHash,
            [string]$DiscoveryScopeHash,
            [string]$ExposureSnapshotCompletedAt
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

    It 'links explicit Azure scans to the latest completed full discovery with materialized evidence' {
        Add-TestDiscoveryRun -Id 11 -Scope All -Status Completed -StartedAt '2026-05-01T00:00:00Z' -CompletedAt '2026-05-01T00:10:00Z' -AttackPathScopeHash 'attack-old' -DiscoveryScopeHash 'scope-old' -ExposureSnapshotCompletedAt '2026-05-01T00:10:00Z'
        Add-TestDiscoveryRun -Id 12 -Scope All -Status Completed -StartedAt '2026-05-02T00:00:00Z' -CompletedAt '2026-05-02T00:10:00Z' -AttackPathScopeHash 'attack-new' -DiscoveryScopeHash 'scope-new' -ExposureSnapshotCompletedAt '2026-05-02T00:10:00Z'

        $scanRun = New-CIEMScanRun -Provider Azure
        $loaded = Get-CIEMScanRun -Id $scanRun.Id

        $scanRun.DiscoveryRunId | Should -Be 12
        $scanRun.ProviderExplicit | Should -BeTrue
        $scanRun.ProgressEligible | Should -BeTrue
        $scanRun.ProgressScopeHash | Should -Not -BeNullOrEmpty
        $loaded.DiscoveryRunId | Should -Be 12
        $loaded.ProviderExplicit | Should -BeTrue
        $loaded.ProgressEligible | Should -BeTrue
        $loaded.ProgressScopeHash | Should -Be $scanRun.ProgressScopeHash
    }

    It 'does not mark an omitted-provider Azure-only scan as progress eligible' {
        Add-TestDiscoveryRun -Id 21 -Scope All -Status Completed -StartedAt '2026-05-01T00:00:00Z' -CompletedAt '2026-05-01T00:10:00Z' -AttackPathScopeHash 'attack-scope' -DiscoveryScopeHash 'discovery-scope' -ExposureSnapshotCompletedAt '2026-05-01T00:10:00Z'

        $scanRun = New-CIEMScanRun

        $scanRun.Providers | Should -Be @('Azure')
        $scanRun.DiscoveryRunId | Should -Be 21
        $scanRun.ProviderExplicit | Should -BeFalse
        $scanRun.ProgressEligible | Should -BeFalse
        $scanRun.ProgressScopeHash | Should -BeNullOrEmpty
    }

    It 'keeps check-filtered and service-filtered Azure scans out of progress evidence' {
        Add-TestDiscoveryRun -Id 31 -Scope All -Status Completed -StartedAt '2026-05-01T00:00:00Z' -CompletedAt '2026-05-01T00:10:00Z' -AttackPathScopeHash 'attack-scope' -DiscoveryScopeHash 'discovery-scope' -ExposureSnapshotCompletedAt '2026-05-01T00:10:00Z'

        $checkFiltered = New-CIEMScanRun -Provider Azure -CheckId 'aisearch_service_not_publicly_accessible'
        $serviceFiltered = New-CIEMScanRun -Provider Azure -Service 'Entra'

        $checkFiltered.DiscoveryRunId | Should -Be 31
        $checkFiltered.ProviderExplicit | Should -BeTrue
        $checkFiltered.ProgressEligible | Should -BeFalse
        $checkFiltered.ProgressScopeHash | Should -BeNullOrEmpty
        $serviceFiltered.DiscoveryRunId | Should -Be 31
        $serviceFiltered.ProviderExplicit | Should -BeTrue
        $serviceFiltered.ProgressEligible | Should -BeFalse
        $serviceFiltered.ProgressScopeHash | Should -BeNullOrEmpty
    }

    It 'records non-Azure scans as operational scan history only' {
        Update-CIEMProvider -Name AWS -Enabled $true
        Add-TestDiscoveryRun -Id 41 -Scope All -Status Completed -StartedAt '2026-05-01T00:00:00Z' -CompletedAt '2026-05-01T00:10:00Z' -AttackPathScopeHash 'attack-scope' -DiscoveryScopeHash 'discovery-scope' -ExposureSnapshotCompletedAt '2026-05-01T00:10:00Z'

        $scanRun = New-CIEMScanRun -Provider AWS

        $scanRun.DiscoveryRunId | Should -BeNullOrEmpty
        $scanRun.ProviderExplicit | Should -BeTrue
        $scanRun.ProgressEligible | Should -BeFalse
        $scanRun.ProgressScopeHash | Should -BeNullOrEmpty
    }

    It 'does not link scans when no completed full discovery has materialized evidence' {
        Add-TestDiscoveryRun -Id 52 -Scope All -Status Failed -StartedAt '2026-05-03T00:00:00Z' -CompletedAt '2026-05-03T00:10:00Z' -AttackPathScopeHash 'attack-failed' -DiscoveryScopeHash 'scope-failed' -ExposureSnapshotCompletedAt '2026-05-03T00:10:00Z'
        Add-TestDiscoveryRun -Id 53 -Scope ARM -Status Completed -StartedAt '2026-05-02T00:00:00Z' -CompletedAt '2026-05-02T00:10:00Z' -AttackPathScopeHash 'attack-arm' -DiscoveryScopeHash 'scope-arm' -ExposureSnapshotCompletedAt '2026-05-02T00:10:00Z'
        Add-TestDiscoveryRun -Id 54 -Scope All -Status Completed -StartedAt '2026-05-01T00:00:00Z' -CompletedAt '2026-05-01T00:10:00Z' -AttackPathScopeHash '' -DiscoveryScopeHash 'scope-empty-attack' -ExposureSnapshotCompletedAt '2026-05-01T00:10:00Z'
        Add-TestDiscoveryRun -Id 55 -Scope All -Status Completed -StartedAt '2026-04-30T00:00:00Z' -CompletedAt '2026-04-30T00:10:00Z' -AttackPathScopeHash 'attack-empty-scope' -DiscoveryScopeHash '' -ExposureSnapshotCompletedAt '2026-04-30T00:10:00Z'
        Add-TestDiscoveryRun -Id 56 -Scope All -Status Completed -StartedAt '2026-04-29T00:00:00Z' -CompletedAt '2026-04-29T00:10:00Z' -AttackPathScopeHash 'attack-empty-snapshot' -DiscoveryScopeHash 'scope-empty-snapshot' -ExposureSnapshotCompletedAt ''

        $scanRun = New-CIEMScanRun -Provider Azure

        $scanRun.DiscoveryRunId | Should -BeNullOrEmpty
        $scanRun.ProviderExplicit | Should -BeTrue
        $scanRun.ProgressEligible | Should -BeFalse
        $scanRun.ProgressScopeHash | Should -BeNullOrEmpty
    }

    It 'blocks Azure scans while an Azure discovery is running' {
        Add-TestDiscoveryRun -Id 57 -Scope All -Status Running -StartedAt '2026-05-04T00:00:00Z'

        { New-CIEMScanRun -Provider Azure } | Should -Throw '*Azure discovery run is already in progress*'
    }

    It 'allows AWS-only scans while an Azure discovery is running' {
        Update-CIEMProvider -Name AWS -Enabled $true
        Add-TestDiscoveryRun -Id 58 -Scope All -Status Running -StartedAt '2026-05-04T00:00:00Z'

        $scanRun = New-CIEMScanRun -Provider AWS

        $scanRun.Providers | Should -Be @('AWS')
        $scanRun.ProgressEligible | Should -BeFalse
    }

    It 'changes the progress scope hash when the linked discovery scope changes' {
        Add-TestDiscoveryRun -Id 61 -Scope All -Status Completed -StartedAt '2026-05-01T00:00:00Z' -CompletedAt '2026-05-01T00:10:00Z' -AttackPathScopeHash 'attack-scope' -DiscoveryScopeHash 'discovery-scope-a' -ExposureSnapshotCompletedAt '2026-05-01T00:10:00Z'
        $first = New-CIEMScanRun -Provider Azure

        Add-TestDiscoveryRun -Id 62 -Scope All -Status Completed -StartedAt '2026-05-02T00:00:00Z' -CompletedAt '2026-05-02T00:10:00Z' -AttackPathScopeHash 'attack-scope' -DiscoveryScopeHash 'discovery-scope-b' -ExposureSnapshotCompletedAt '2026-05-02T00:10:00Z'
        $second = New-CIEMScanRun -Provider Azure

        $first.ProgressScopeHash | Should -Not -BeNullOrEmpty
        $second.ProgressScopeHash | Should -Not -BeNullOrEmpty
        $second.ProgressScopeHash | Should -Not -Be $first.ProgressScopeHash
    }
}
