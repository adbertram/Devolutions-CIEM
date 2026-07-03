BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    function New-LegacyScanRunDatabase {
        param(
            [Parameter(Mandatory)][string]$Path
        )

        $connection = Open-PSUSQLiteConnection -Database $Path
        try {
            foreach ($statement in @(
                'PRAGMA foreign_keys=ON',
                @'
CREATE TABLE providers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    type TEXT NOT NULL,
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
)
'@,
                "INSERT INTO providers (id, name, type, enabled, created_at, updated_at) VALUES ('azure', 'Azure', 'Azure', 1, '2026-05-01T00:00:00Z', '2026-05-01T00:00:00Z'), ('aws', 'AWS', 'AWS', 1, '2026-05-01T00:00:00Z', '2026-05-01T00:00:00Z')",
                'CREATE TABLE checks (id TEXT PRIMARY KEY, disabled INTEGER NOT NULL DEFAULT 0)',
                "INSERT INTO checks (id, disabled) VALUES ('aisearch_service_not_publicly_accessible', 0)",
                @'
CREATE TABLE azure_discovery_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    psu_job_id INTEGER,
    scope TEXT NOT NULL,
    status TEXT NOT NULL,
    started_at TEXT NOT NULL,
    completed_at TEXT
)
'@,
                @'
CREATE TABLE scan_runs (
    id TEXT PRIMARY KEY,
    provider_id TEXT NOT NULL,
    scan_type TEXT NOT NULL DEFAULT 'checks',
    status TEXT NOT NULL,
    resource_filter TEXT,
    resource_providers TEXT,
    include_passed INTEGER DEFAULT 1,
    started_at TEXT NOT NULL,
    completed_at TEXT,
    duration_seconds REAL,
    total_results INTEGER DEFAULT 0,
    failed_results INTEGER DEFAULT 0,
    passed_results INTEGER DEFAULT 0,
    skipped_results INTEGER DEFAULT 0,
    manual_results INTEGER DEFAULT 0,
    error_message TEXT,
    FOREIGN KEY (provider_id) REFERENCES providers(id) ON DELETE CASCADE
)
'@,
                @'
CREATE TABLE scan_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_run_id TEXT NOT NULL,
    check_id TEXT NOT NULL,
    status TEXT NOT NULL,
    status_extended TEXT,
    resource_id TEXT,
    resource_name TEXT,
    location TEXT,
    FOREIGN KEY (scan_run_id) REFERENCES scan_runs(id) ON DELETE CASCADE,
    FOREIGN KEY (check_id) REFERENCES checks(id) ON DELETE CASCADE
)
'@,
                "INSERT INTO scan_runs (id, provider_id, scan_type, status, resource_providers, include_passed, started_at, completed_at, duration_seconds, total_results, failed_results, passed_results, skipped_results, manual_results) VALUES ('legacy-csv', 'azure', 'checks', 'Completed', 'azure,AWS', 1, '2026-05-01T00:00:00Z', '2026-05-01T00:01:00Z', 60, 1, 1, 0, 0, 0)",
                "INSERT INTO scan_runs (id, provider_id, scan_type, status, resource_providers, include_passed, started_at, completed_at, duration_seconds, total_results, failed_results, passed_results, skipped_results, manual_results) VALUES ('legacy-provider-id', 'azure', 'checks', 'Completed', NULL, 1, '2026-05-01T00:02:00Z', '2026-05-01T00:03:00Z', 60, 0, 0, 0, 0, 0)",
                "INSERT INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name, location) VALUES ('legacy-csv', 'aisearch_service_not_publicly_accessible', 'FAIL', 'Public access enabled', '/subscriptions/test/resourceGroups/rg/providers/Microsoft.Search/searchServices/search1', 'search1', 'Global')"
            )) {
                Invoke-PSUSQLiteQuery -Connection $connection -Query $statement -AsNonQuery | Out-Null
            }
        }
        finally {
            $connection.Dispose()
        }
    }
}

Describe 'CIEM scan-run storage schema' {
    BeforeEach {
        $script:TestDatabasePath = Join-Path $TestDrive ("ciem-" + [guid]::NewGuid().ToString('N') + '.db')
        New-CIEMDatabase -Path $script:TestDatabasePath

        InModuleScope Devolutions.CIEM -Parameters @{ DatabasePath = $script:TestDatabasePath } {
            param([string]$DatabasePath)
            $script:DatabasePath = $DatabasePath
        }
    }

    It 'creates scan-run progress columns and indexes in fresh databases' {
        $columns = Invoke-CIEMQuery -Query "PRAGMA table_info('scan_runs')"
        $indexes = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'scan_runs'"

        $columns.name | Should -Contain 'discovery_run_id'
        $columns.name | Should -Contain 'provider_explicit'
        $columns.name | Should -Contain 'progress_eligible'
        $columns.name | Should -Contain 'progress_scope_hash'
        $indexes.name | Should -Contain 'idx_scan_runs_discovery_progress_completed'
        $indexes.name | Should -Contain 'idx_scan_runs_progress_scope'
    }

    It 'creates normalized scan provider and check snapshot tables in fresh databases' {
        $tables = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('scan_run_providers', 'scan_run_check_snapshots')"
        $providerIndexes = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'scan_run_providers'"
        $snapshotIndexes = Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'scan_run_check_snapshots'"

        $tables.name | Should -Contain 'scan_run_providers'
        $tables.name | Should -Contain 'scan_run_check_snapshots'
        $providerIndexes.name | Should -Contain 'idx_scan_run_providers_provider'
        $snapshotIndexes.name | Should -Contain 'idx_scan_run_check_snapshots_check'
    }

    It 'does not cascade-delete historical scan results when check catalog rows are deleted' {
        $foreignKeys = Invoke-CIEMQuery -Query "PRAGMA foreign_key_list('scan_results')"
        $checkCascadeForeignKeys = @(
            $foreignKeys | Where-Object {
                $_.table -eq 'checks' -and
                $_.from -eq 'check_id' -and
                $_.on_delete -eq 'CASCADE'
            }
        )

        $checkCascadeForeignKeys | Should -HaveCount 0
    }

    It 'exposes progress tracking properties on CIEMScanRun' {
        $properties = InModuleScope Devolutions.CIEM {
            ([CIEMScanRun]::new()).PSObject.Properties.Name
        }

        $properties | Should -Contain 'DiscoveryRunId'
        $properties | Should -Contain 'ProviderExplicit'
        $properties | Should -Contain 'ProgressEligible'
        $properties | Should -Contain 'ProgressScopeHash'
    }

    It 'persists progress fields and normalized provider membership' {
        Invoke-CIEMQuery -Query @"
INSERT INTO azure_discovery_runs (
    id, psu_job_id, scope, status, started_at, completed_at,
    attack_path_scope_hash, discovery_scope_hash, exposure_snapshot_completed_at
)
VALUES (
    17, -17, 'All', 'Completed', '2026-05-01T00:00:00Z', '2026-05-01T00:05:00Z',
    'attack-scope', 'discovery-scope', '2026-05-01T00:05:00Z'
)
"@ -AsNonQuery | Out-Null

        $scanRun = InModuleScope Devolutions.CIEM {
            $run = [CIEMScanRun]::new(@('AWS', 'Azure'), @(), $true)
            $run.Id = 'progress-save'
            $run.Status = [CIEMScanRunStatus]::Completed
            $run.StartTime = [datetime]'2026-05-01T00:06:00Z'
            $run.EndTime = [datetime]'2026-05-01T00:07:00Z'
            $run.DiscoveryRunId = 17
            $run.ProviderExplicit = $true
            $run.ProgressEligible = $true
            $run.ProgressScopeHash = 'progress-hash'
            $run
        }

        Save-CIEMScanRun -ScanRun $scanRun

        $row = Invoke-CIEMQuery -Query "SELECT discovery_run_id, provider_explicit, progress_eligible, progress_scope_hash, resource_providers, provider_id FROM scan_runs WHERE id = 'progress-save'"
        $providers = Invoke-CIEMQuery -Query "SELECT provider FROM scan_run_providers WHERE scan_run_id = 'progress-save' ORDER BY provider"
        $loaded = Get-CIEMScanRun -Id 'progress-save'

        [int]$row.discovery_run_id | Should -Be 17
        [int]$row.provider_explicit | Should -Be 1
        [int]$row.progress_eligible | Should -Be 1
        $row.progress_scope_hash | Should -Be 'progress-hash'
        $row.resource_providers | Should -Be 'AWS,Azure'
        $row.provider_id | Should -Be 'aws'
        $providers.provider | Should -Be @('AWS', 'Azure')
        $loaded.DiscoveryRunId | Should -Be 17
        $loaded.ProviderExplicit | Should -BeTrue
        $loaded.ProgressEligible | Should -BeTrue
        $loaded.ProgressScopeHash | Should -Be 'progress-hash'
        $loaded.Providers | Should -Be @('AWS', 'Azure')
    }

    It 'removes scan runs by provider membership instead of primary provider id' {
        Invoke-CIEMQuery -Query @"
INSERT INTO scan_runs (
    id, provider_id, scan_type, status, resource_providers, include_passed,
    started_at, completed_at, duration_seconds, total_results, failed_results,
    passed_results, skipped_results, manual_results
)
VALUES (
    'azure-member-owned-by-aws', 'aws', 'checks', 'Completed', NULL, 1,
    '2026-05-01T00:06:00Z', '2026-05-01T00:07:00Z', 60, 0, 0, 0, 0, 0
)
"@ -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query @"
INSERT INTO scan_run_providers (scan_run_id, provider)
VALUES ('azure-member-owned-by-aws', 'Azure')
"@ -AsNonQuery | Out-Null

        Remove-CIEMScanRun -ProviderId Azure -Confirm:$false

        $remaining = Invoke-CIEMQuery -Query "SELECT id FROM scan_runs WHERE id = 'azure-member-owned-by-aws'"
        $remaining | Should -BeNullOrEmpty
    }
}

Describe 'CIEM scan-run storage migration' {
    BeforeEach {
        $script:LegacyDatabasePath = Join-Path $TestDrive ("legacy-" + [guid]::NewGuid().ToString('N') + '.db')
        New-LegacyScanRunDatabase -Path $script:LegacyDatabasePath

        InModuleScope Devolutions.CIEM -Parameters @{ DatabasePath = $script:LegacyDatabasePath } {
            param([string]$DatabasePath)
            $script:DatabasePath = $DatabasePath
        }
    }

    It 'backfills canonical provider membership and historical check snapshots' {
        InModuleScope Devolutions.CIEM {
            UpdateCIEMScanRunStorageSchema
        }

        $providerRows = Invoke-CIEMQuery -Query 'SELECT scan_run_id, provider FROM scan_run_providers ORDER BY scan_run_id, provider'
        $snapshot = Invoke-CIEMQuery -Query "SELECT snapshot_json FROM scan_run_check_snapshots WHERE scan_run_id = 'legacy-csv' AND check_id = 'aisearch_service_not_publicly_accessible'"
        $snapshotPayload = $snapshot.snapshot_json | ConvertFrom-Json

        $providerRows | Should -HaveCount 3
        @($providerRows | Where-Object scan_run_id -eq 'legacy-csv').provider | Should -Be @('AWS', 'Azure')
        @($providerRows | Where-Object scan_run_id -eq 'legacy-provider-id').provider | Should -Be @('Azure')
        $snapshotPayload.id | Should -Be 'aisearch_service_not_publicly_accessible'
        $snapshotPayload.provider | Should -Be 'Azure'
        $snapshotPayload.service | Should -Be 'Aisearch'
        $snapshotPayload.title | Should -Be 'AI Search service has public network access disabled'
        $snapshotPayload.remediation.text | Should -Not -BeNullOrEmpty
    }

    It 'removes the historical check cascade without deleting scan results' {
        InModuleScope Devolutions.CIEM {
            UpdateCIEMScanRunStorageSchema
        }

        $foreignKeys = Invoke-CIEMQuery -Query "PRAGMA foreign_key_list('scan_results')"
        $checkCascadeForeignKeys = @(
            $foreignKeys | Where-Object {
                $_.table -eq 'checks' -and
                $_.from -eq 'check_id' -and
                $_.on_delete -eq 'CASCADE'
            }
        )

        Invoke-CIEMQuery -Query "DELETE FROM checks WHERE id = 'aisearch_service_not_publicly_accessible'" -AsNonQuery | Out-Null
        $resultRows = Invoke-CIEMQuery -Query "SELECT check_id FROM scan_results WHERE scan_run_id = 'legacy-csv'"

        $checkCascadeForeignKeys | Should -HaveCount 0
        $resultRows | Should -HaveCount 1
        $resultRows.check_id | Should -Be 'aisearch_service_not_publicly_accessible'
    }

    It 'is idempotent and preserves existing progress links' {
        InModuleScope Devolutions.CIEM {
            UpdateCIEMScanRunStorageSchema
        }
        Invoke-CIEMQuery -Query @"
INSERT INTO azure_discovery_runs (id, psu_job_id, scope, status, started_at, completed_at)
VALUES (88, -88, 'All', 'Completed', '2026-05-01T00:00:00Z', '2026-05-01T00:05:00Z')
"@ -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query "UPDATE scan_runs SET discovery_run_id = 88, progress_eligible = 1, progress_scope_hash = 'existing-scope' WHERE id = 'legacy-csv'" -AsNonQuery | Out-Null

        InModuleScope Devolutions.CIEM {
            UpdateCIEMScanRunStorageSchema
        }

        $row = Invoke-CIEMQuery -Query "SELECT discovery_run_id, progress_eligible, progress_scope_hash FROM scan_runs WHERE id = 'legacy-csv'"

        [int]$row.discovery_run_id | Should -Be 88
        [int]$row.progress_eligible | Should -Be 1
        $row.progress_scope_hash | Should -Be 'existing-scope'
    }
}
