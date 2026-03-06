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
        # Resolve provider_id for FK (use first provider, lowercased)
        $primaryProvider = @($ScanRun.Providers)[0]
        $providerId = $primaryProvider.ToString().ToLower()

        # Ensure the provider exists in the DB (it should, but be safe)
        $providerExists = Invoke-CIEMQuery -Query "SELECT id FROM providers WHERE id = @id" -Parameters @{ id = $providerId }
        if (-not $providerExists) {
            Write-Verbose "Save-CIEMScanRun: Provider '$providerId' not in database — skipping persistence."
            return
        }

        $conn = Open-PSUSQLiteConnection -Database (Get-CIEMDatabasePath)
        try {
            Invoke-PSUSQLiteQuery -Connection $conn -Query "PRAGMA foreign_keys=ON" -AsNonQuery | Out-Null
            $tx = $conn.BeginTransaction()

            # Upsert scan run metadata
            $startedAt = if ($ScanRun.StartTime) { ([datetime]$ScanRun.StartTime).ToString('o') } else { (Get-Date).ToString('o') }
            $completedAt = if ($ScanRun.EndTime) { ([datetime]$ScanRun.EndTime).ToString('o') } else { $null }
            $durationSeconds = if ($ScanRun.EndTime -and $ScanRun.StartTime) {
                (([datetime]$ScanRun.EndTime) - ([datetime]$ScanRun.StartTime)).TotalSeconds
            } else { $null }

            Invoke-PSUSQLiteQuery -Connection $conn -ErrorAction Stop -Query @"
INSERT OR REPLACE INTO scan_runs (id, provider_id, status, resource_filter, resource_providers, include_passed,
    started_at, completed_at, duration_seconds, total_results, failed_results, passed_results, skipped_results, manual_results, error_message)
VALUES (@id, @provider_id, @status, @resource_filter, @resource_providers, @include_passed,
    @started_at, @completed_at, @duration_seconds, @total_results, @failed_results, @passed_results, @skipped_results, @manual_results, @error_message)
"@ -Parameters @{
                id                 = $ScanRun.Id
                provider_id        = $providerId
                status             = [string]$ScanRun.Status
                resource_filter    = $null
                resource_providers = ($ScanRun.Providers -join ',')
                include_passed     = if ($ScanRun.IncludePassed) { 1 } else { 0 }
                started_at         = $startedAt
                completed_at       = $completedAt
                duration_seconds   = $durationSeconds
                total_results      = [int]$ScanRun.TotalResults
                failed_results     = [int]$ScanRun.FailedResults
                passed_results     = [int]$ScanRun.PassedResults
                skipped_results    = [int]$ScanRun.SkippedResults
                manual_results     = [int]$ScanRun.ManualResults
                error_message      = $ScanRun.ErrorMessage
            } -AsNonQuery | Out-Null

            # Insert scan results (if present)
            if ($ScanRun.ScanResults -and $ScanRun.ScanResults.Count -gt 0) {
                # Delete existing results for this run (for upsert behavior)
                Invoke-PSUSQLiteQuery -Connection $conn -ErrorAction Stop -Query "DELETE FROM scan_results WHERE scan_run_id = @id" -Parameters @{ id = $ScanRun.Id } -AsNonQuery | Out-Null

                foreach ($result in $ScanRun.ScanResults) {
                    $checkId = if ($result.Check.Id) { $result.Check.Id } else { $result.Check.id }
                    if (-not $checkId) { continue }

                    Invoke-PSUSQLiteQuery -Connection $conn -ErrorAction Stop -Query @"
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

            $tx.Commit()
            Write-Verbose "Persisted ScanRun: $($ScanRun.Id) (Status: $($ScanRun.Status), Results: $($ScanRun.ScanResults.Count))"
        }
        catch {
            if ($tx) { $tx.Rollback() }
            Write-Warning "Save-CIEMScanRun: Failed to persist scan run $($ScanRun.Id): $($_.Exception.Message)"
        }
        finally {
            $conn.Dispose()
        }
    }
}
