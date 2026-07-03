function SaveCIEMScanRunCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Connection,

        [Parameter(Mandatory)]
        [object]$ScanRun
    )

    $ErrorActionPreference = 'Stop'

    $parameters = ConvertToCIEMScanRunStorageParameters -ScanRun $ScanRun -Connection $Connection
    $snapshotByCheckId = @{}
    $failedKeys = @{}

    if ($ScanRun.ScanResults) {
        foreach ($result in @($ScanRun.ScanResults)) {
            $checkId = [string]$result.Check.Id
            AssertCIEMScanResultKey -Status ([string]$result.Status) -CheckId $checkId -ResourceId $result.ResourceId -Context "scan run '$($ScanRun.Id)'"

            if ([string]$result.Status -eq 'FAIL') {
                $failedKey = "$checkId|$($result.ResourceId)"
                if ($failedKeys.ContainsKey($failedKey)) {
                    throw "Duplicate failed scan result key '$failedKey' in scan run '$($ScanRun.Id)'."
                }
                $failedKeys[$failedKey] = $true
            }

            if (-not $snapshotByCheckId.ContainsKey($checkId)) {
                $snapshotByCheckId[$checkId] = NewCIEMCheckSnapshotJson -Check $result.Check
            }
            else {
                $snapshotJson = NewCIEMCheckSnapshotJson -Check $result.Check
                if ($snapshotByCheckId[$checkId] -ne $snapshotJson) {
                    throw "Conflicting check snapshot payloads for check '$checkId' in scan run '$($ScanRun.Id)'."
                }
            }
        }
    }

    $providerExists = Invoke-PSUSQLiteQuery -Connection $Connection -Query 'SELECT id FROM providers WHERE id = @id' -Parameters @{
        id = $parameters.provider_id
    }
    if (-not $providerExists) {
        throw "Save-CIEMScanRun cannot persist scan run '$($ScanRun.Id)' because provider '$($parameters.provider_id)' does not exist."
    }

    Invoke-PSUSQLiteQuery -Connection $Connection -ErrorAction Stop -Query @"
INSERT OR REPLACE INTO scan_runs (id, provider_id, scan_type, status, resource_filter, resource_providers, include_passed,
    started_at, completed_at, duration_seconds, total_results, failed_results, passed_results, skipped_results, manual_results,
    error_message, discovery_run_id, provider_explicit, progress_eligible, progress_scope_hash)
VALUES (@id, @provider_id, @scan_type, @status, @resource_filter, @resource_providers, @include_passed,
    @started_at, @completed_at, @duration_seconds, @total_results, @failed_results, @passed_results, @skipped_results, @manual_results,
    @error_message, @discovery_run_id, @provider_explicit, @progress_eligible, @progress_scope_hash)
"@ -Parameters $parameters -AsNonQuery | Out-Null

    SetCIEMScanRunProviders -Connection $Connection -ScanRunId $ScanRun.Id -Providers @($ScanRun.Providers)

    if ($ScanRun.ScanResults -and $ScanRun.ScanResults.Count -gt 0) {
        Write-CIEMLog -Message "DELETE scan_results WHERE scan_run_id='$($ScanRun.Id)' (upsert in Save-CIEMScanRun)" -Severity WARNING -Component 'Save-ScanRun'
        Invoke-PSUSQLiteQuery -Connection $Connection -ErrorAction Stop -Query 'DELETE FROM scan_results WHERE scan_run_id = @id' -Parameters @{ id = $ScanRun.Id } -AsNonQuery | Out-Null
        Invoke-PSUSQLiteQuery -Connection $Connection -ErrorAction Stop -Query 'DELETE FROM scan_run_check_snapshots WHERE scan_run_id = @id' -Parameters @{ id = $ScanRun.Id } -AsNonQuery | Out-Null

        foreach ($checkId in @($snapshotByCheckId.Keys | Sort-Object)) {
            Invoke-PSUSQLiteQuery -Connection $Connection -ErrorAction Stop -Query @"
INSERT INTO scan_run_check_snapshots (scan_run_id, check_id, snapshot_json)
VALUES (@scan_run_id, @check_id, @snapshot_json)
"@ -Parameters @{
                scan_run_id   = $ScanRun.Id
                check_id      = $checkId
                snapshot_json = $snapshotByCheckId[$checkId]
            } -AsNonQuery | Out-Null
        }

        foreach ($result in $ScanRun.ScanResults) {
            $checkId = [string]$result.Check.Id

            Invoke-PSUSQLiteQuery -Connection $Connection -ErrorAction Stop -Query @"
INSERT INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name, location)
VALUES (@scan_run_id, @check_id, @status, @status_extended, @resource_id, @resource_name, @location)
"@ -Parameters @{
                scan_run_id     = $ScanRun.Id
                check_id        = $checkId
                status          = [string]$result.Status
                status_extended = $result.StatusExtended
                resource_id     = $result.ResourceId
                resource_name   = $result.ResourceName
                location        = $result.Location
            } -AsNonQuery | Out-Null
        }
    }
}

function Save-CIEMScanRun {
    <#
    .SYNOPSIS
        Persists a CIEMScanRun to the CIEM SQLite database.
    .DESCRIPTION
        Saves the ScanRun metadata and optionally its results to the scan_runs
        and scan_results tables. Uses a single transaction for atomicity.

        For multi-provider scans, one scan_runs row is created with a comma-
        separated provider list. The provider_id FK uses the first provider.
    .PARAMETER ScanRun
        The CIEMScanRun object to persist.
    .OUTPUTS
        None
    .EXAMPLE
        $scanRun = New-CIEMScanRun -Providers 'Azure' -Services @('Entra')
        Save-CIEMScanRun -ScanRun $scanRun
    .EXAMPLE
        $scanRun | Save-CIEMScanRun
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $ScanRun
    )

    process {
        $ErrorActionPreference = 'Stop'
        $conn = Open-PSUSQLiteConnection -Database (Get-CIEMDatabasePath)
        $transactionStarted = $false
        try {
            Invoke-PSUSQLiteQuery -Connection $conn -Query "PRAGMA foreign_keys=ON" -AsNonQuery | Out-Null
            Invoke-PSUSQLiteQuery -Connection $conn -Query 'BEGIN TRANSACTION' -AsNonQuery | Out-Null
            $transactionStarted = $true
            SaveCIEMScanRunCore -Connection $conn -ScanRun $ScanRun
            Invoke-PSUSQLiteQuery -Connection $conn -Query 'COMMIT' -AsNonQuery | Out-Null
            $transactionStarted = $false
            Write-Verbose "Persisted ScanRun: $($ScanRun.Id) (Status: $($ScanRun.Status), Results: $($ScanRun.ScanResults.Count))"
        }
        catch {
            if ($transactionStarted) {
                Invoke-PSUSQLiteQuery -Connection $conn -Query 'ROLLBACK' -AsNonQuery | Out-Null
            }
            throw "Save-CIEMScanRun failed to persist scan run '$($ScanRun.Id)': $($_.Exception.Message)"
        }
        finally {
            $conn.Dispose()
        }
    }
}
