function NewCIEMCheckSnapshotJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Check
    )

    $ErrorActionPreference = 'Stop'

    $payload = [ordered]@{
        id              = [string]$Check.Id
        provider        = [string]$Check.Provider
        service         = [string]$Check.Service
        title           = [string]$Check.Title
        description     = [string]$Check.Description
        risk            = [string]$Check.Risk
        severity        = [string]$Check.Severity
        remediation     = [ordered]@{
            text = [string]$Check.Remediation.Text
            url  = [string]$Check.Remediation.Url
        }
        relatedUrl      = [string]$Check.RelatedUrl
        checkScript     = [string]$Check.CheckScript
        executionMode   = [string]$Check.ExecutionMode
        manualReason    = $Check.ManualReason
        evaluator       = $Check.Evaluator
        evaluatorConfig = $Check.EvaluatorConfig
        dependsOn       = @($Check.DependsOn)
        dataNeeds       = if ($null -eq $Check.DataNeeds) { $null } else { @($Check.DataNeeds) }
        disabled        = [bool]$Check.Disabled
        permissions     = $Check.Permissions
    }

    $payload | ConvertTo-Json -Depth 20 -Compress
}

function UpdateCIEMScanRunStorageSchema {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $scanRunColumns = @(Invoke-CIEMQuery -Query "PRAGMA table_info('scan_runs')")
    if ($scanRunColumns.Count -eq 0) {
        throw "Cannot migrate scan-run storage because table 'scan_runs' does not exist."
    }

    $scanResultColumns = @(Invoke-CIEMQuery -Query "PRAGMA table_info('scan_results')")
    if ($scanResultColumns.Count -eq 0) {
        throw "Cannot migrate scan-run storage because table 'scan_results' does not exist."
    }

    $columnNames = @{}
    foreach ($column in $scanRunColumns) {
        $columnNames[[string]$column.name] = $true
    }

    foreach ($column in @(
        @{ Name = 'discovery_run_id';     Definition = 'INTEGER REFERENCES azure_discovery_runs(id) ON DELETE SET NULL' },
        @{ Name = 'provider_explicit';    Definition = 'INTEGER NOT NULL DEFAULT 0' },
        @{ Name = 'progress_eligible';    Definition = 'INTEGER NOT NULL DEFAULT 0' },
        @{ Name = 'progress_scope_hash';  Definition = 'TEXT' }
    )) {
        if (-not $columnNames.ContainsKey($column.Name)) {
            Invoke-CIEMQuery -Query "ALTER TABLE scan_runs ADD COLUMN $($column.Name) $($column.Definition)" -AsNonQuery | Out-Null
        }
    }

    Invoke-CIEMQuery -Query @'
CREATE TABLE IF NOT EXISTS scan_run_providers (
    scan_run_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    PRIMARY KEY (scan_run_id, provider),
    FOREIGN KEY (scan_run_id) REFERENCES scan_runs(id) ON DELETE CASCADE
)
'@ -AsNonQuery | Out-Null

    Invoke-CIEMQuery -Query 'CREATE INDEX IF NOT EXISTS idx_scan_run_providers_provider ON scan_run_providers(provider, scan_run_id)' -AsNonQuery | Out-Null

    Invoke-CIEMQuery -Query @'
CREATE TABLE IF NOT EXISTS scan_run_check_snapshots (
    scan_run_id TEXT NOT NULL,
    check_id TEXT NOT NULL,
    snapshot_json TEXT NOT NULL,
    PRIMARY KEY (scan_run_id, check_id),
    FOREIGN KEY (scan_run_id) REFERENCES scan_runs(id) ON DELETE CASCADE
)
'@ -AsNonQuery | Out-Null

    Invoke-CIEMQuery -Query 'CREATE INDEX IF NOT EXISTS idx_scan_run_check_snapshots_check ON scan_run_check_snapshots(check_id)' -AsNonQuery | Out-Null

    $providers = @(Invoke-CIEMQuery -Query 'SELECT id, name FROM providers')
    if ($providers.Count -eq 0) {
        throw "Cannot migrate scan-run providers because table 'providers' has no rows."
    }

    $providerByToken = @{}
    foreach ($provider in $providers) {
        $providerByToken[[string]$provider.id.ToLowerInvariant()] = [string]$provider.name
        $providerByToken[[string]$provider.name.ToLowerInvariant()] = [string]$provider.name
    }

    $existingProviderRows = @(Invoke-CIEMQuery -Query 'SELECT scan_run_id FROM scan_run_providers LIMIT 1')
    if ($existingProviderRows.Count -eq 0) {
        $runs = @(Invoke-CIEMQuery -Query 'SELECT id, provider_id, resource_providers FROM scan_runs')
        foreach ($run in $runs) {
            $legacyText = [string]$run.resource_providers
            $tokens = if (-not [string]::IsNullOrWhiteSpace($legacyText)) {
                @($legacyText -split ',' | ForEach-Object { [string]$_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
            else {
                @([string]$run.provider_id)
            }

            $canonicalProviders = @()
            foreach ($token in $tokens) {
                $key = $token.ToLowerInvariant()
                if (-not $providerByToken.ContainsKey($key)) {
                    throw "Unknown provider token '$token' in legacy scan run '$($run.id)'."
                }
                if ($canonicalProviders -notcontains $providerByToken[$key]) {
                    $canonicalProviders += $providerByToken[$key]
                }
            }

            foreach ($providerName in $canonicalProviders) {
                Invoke-CIEMQuery -Query @'
INSERT OR IGNORE INTO scan_run_providers (scan_run_id, provider)
VALUES (@scan_run_id, @provider)
'@ -Parameters @{
                    scan_run_id = [string]$run.id
                    provider    = $providerName
                } -AsNonQuery | Out-Null
            }
        }
    }

    $existingSnapshotRows = @(Invoke-CIEMQuery -Query 'SELECT scan_run_id FROM scan_run_check_snapshots LIMIT 1')
    if ($existingSnapshotRows.Count -eq 0) {
        $catalogById = @{}
        foreach ($check in @(GetCIEMCheckCatalog)) {
            $catalogById[[string]$check.Id] = $check
        }

        $resultChecks = @(Invoke-CIEMQuery -Query 'SELECT DISTINCT scan_run_id, check_id FROM scan_results')
        foreach ($resultCheck in $resultChecks) {
            $checkId = [string]$resultCheck.check_id
            if ($catalogById.ContainsKey($checkId)) {
                Invoke-CIEMQuery -Query @'
INSERT OR IGNORE INTO scan_run_check_snapshots (scan_run_id, check_id, snapshot_json)
VALUES (@scan_run_id, @check_id, @snapshot_json)
'@ -Parameters @{
                    scan_run_id   = [string]$resultCheck.scan_run_id
                    check_id      = $checkId
                    snapshot_json = NewCIEMCheckSnapshotJson -Check $catalogById[$checkId]
                } -AsNonQuery | Out-Null
            }
        }
    }

    $checkCascadeForeignKeys = @(
        Invoke-CIEMQuery -Query "PRAGMA foreign_key_list('scan_results')" |
            Where-Object {
                $_.table -eq 'checks' -and
                $_.from -eq 'check_id' -and
                $_.on_delete -eq 'CASCADE'
            }
    )

    if ($checkCascadeForeignKeys.Count -gt 0) {
        $databasePath = Get-CIEMDatabasePath
        $connection = Open-PSUSQLiteConnection -Database $databasePath
        try {
            Invoke-PSUSQLiteQuery -Connection $connection -Query 'PRAGMA foreign_keys=OFF' -AsNonQuery | Out-Null
            Invoke-PSUSQLiteQuery -Connection $connection -Query 'BEGIN TRANSACTION' -AsNonQuery | Out-Null
            try {
                Invoke-PSUSQLiteQuery -Connection $connection -Query @'
CREATE TABLE scan_results_migration (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    scan_run_id TEXT NOT NULL,
    check_id TEXT NOT NULL,
    status TEXT NOT NULL,
    status_extended TEXT,
    resource_id TEXT,
    resource_name TEXT,
    location TEXT,
    FOREIGN KEY (scan_run_id) REFERENCES scan_runs(id) ON DELETE CASCADE
)
'@ -AsNonQuery | Out-Null

                Invoke-PSUSQLiteQuery -Connection $connection -Query @'
INSERT INTO scan_results_migration (
    id, scan_run_id, check_id, status, status_extended,
    resource_id, resource_name, location
)
SELECT
    id, scan_run_id, check_id, status, status_extended,
    resource_id, resource_name, location
FROM scan_results
'@ -AsNonQuery | Out-Null

                Invoke-PSUSQLiteQuery -Connection $connection -Query 'DROP TABLE scan_results' -AsNonQuery | Out-Null
                Invoke-PSUSQLiteQuery -Connection $connection -Query 'ALTER TABLE scan_results_migration RENAME TO scan_results' -AsNonQuery | Out-Null
                Invoke-PSUSQLiteQuery -Connection $connection -Query 'CREATE INDEX IF NOT EXISTS idx_scan_results_run_status ON scan_results(scan_run_id, status)' -AsNonQuery | Out-Null
                Invoke-PSUSQLiteQuery -Connection $connection -Query 'CREATE INDEX IF NOT EXISTS idx_scan_results_check ON scan_results(check_id)' -AsNonQuery | Out-Null
                Invoke-PSUSQLiteQuery -Connection $connection -Query 'CREATE INDEX IF NOT EXISTS idx_scan_results_resource ON scan_results(resource_id)' -AsNonQuery | Out-Null
                Invoke-PSUSQLiteQuery -Connection $connection -Query 'COMMIT' -AsNonQuery | Out-Null
            }
            catch {
                Invoke-PSUSQLiteQuery -Connection $connection -Query 'ROLLBACK' -AsNonQuery | Out-Null
                throw
            }
            finally {
                Invoke-PSUSQLiteQuery -Connection $connection -Query 'PRAGMA foreign_keys=ON' -AsNonQuery | Out-Null
            }
        }
        finally {
            $connection.Dispose()
        }
    }

    Invoke-CIEMQuery -Query 'CREATE INDEX IF NOT EXISTS idx_scan_runs_discovery_progress_completed ON scan_runs(discovery_run_id, status, progress_eligible, completed_at)' -AsNonQuery | Out-Null
    Invoke-CIEMQuery -Query 'CREATE INDEX IF NOT EXISTS idx_scan_runs_progress_scope ON scan_runs(progress_scope_hash)' -AsNonQuery | Out-Null
}
