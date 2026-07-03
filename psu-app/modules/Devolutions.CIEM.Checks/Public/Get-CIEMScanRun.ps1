function Get-CIEMScanRun {
    <#
    .SYNOPSIS
        Retrieves ScanRun(s) from the CIEM SQLite database.
    .DESCRIPTION
        Retrieves scan run metadata from the scan_runs table. Can retrieve a
        specific ScanRun by ID or all scan runs (ordered by most recent first).
    .PARAMETER Id
        ScanRun ID to retrieve. If not specified, returns all scan runs.
    .PARAMETER IncludeResults
        When specified, also loads the ScanResults from scan_results + checks tables.
    .EXAMPLE
        $scanRuns = Get-CIEMScanRun
        # Gets all scan runs from history.
    .EXAMPLE
        $latest = Get-CIEMScanRun | Select-Object -First 1
        # Gets the most recent scan run.
    .EXAMPLE
        $scanRun = Get-CIEMScanRun -Id 'abc-123-def' -IncludeResults
        # Gets a specific scan run by ID with its results loaded.
    .OUTPUTS
        [PSCustomObject[]] Array of ScanRun-shaped objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter()]
        [switch]$IncludeResults
    )

    $ErrorActionPreference = 'Stop'

    if ($Id) {
        $rows = @(Invoke-CIEMQuery -Query @'
SELECT
    id, provider_id, scan_type, status, resource_filter, resource_providers,
    include_passed, started_at, completed_at, duration_seconds, total_results,
    failed_results, passed_results, skipped_results, manual_results, error_message,
    discovery_run_id, provider_explicit, progress_eligible, progress_scope_hash
FROM scan_runs
WHERE id = @id
'@ -Parameters @{ id = $Id })
    } else {
        $rows = @(Invoke-CIEMQuery -Query @'
SELECT
    id, provider_id, scan_type, status, resource_filter, resource_providers,
    include_passed, started_at, completed_at, duration_seconds, total_results,
    failed_results, passed_results, skipped_results, manual_results, error_message,
    discovery_run_id, provider_explicit, progress_eligible, progress_scope_hash
FROM scan_runs
ORDER BY julianday(started_at) DESC, rowid DESC
'@)
    }

    if ($rows.Count -eq 0) {
        if ($Id) { Write-Verbose "ScanRun not found: $Id" }
        else     { Write-Verbose "No scan history found" }
        return @()
    }

    $scanRuns = foreach ($row in $rows) {
        $obj = ConvertFromCIEMScanRunStorageRow -Row $row

        if ($IncludeResults) {
            $results = @(Get-CIEMScanResult -ScanRunId $row.id)
            $obj | Add-Member -NotePropertyName ScanResults -NotePropertyValue $results -Force

            # Compute per-provider summaries
            $obj.ProviderSummaries = @(foreach ($provName in @($obj.Providers)) {
                $pr = @($results | Where-Object { $_.Check.Provider -eq $provName })
                [PSCustomObject]@{
                    Provider       = $provName
                    TotalResults   = $pr.Count
                    FailedResults  = @($pr | Where-Object { $_.Status -eq 'FAIL' }).Count
                    PassedResults  = @($pr | Where-Object { $_.Status -eq 'PASS' }).Count
                    SkippedResults = @($pr | Where-Object { $_.Status -eq 'SKIPPED' }).Count
                    ManualResults  = @($pr | Where-Object { $_.Status -eq 'MANUAL' }).Count
                }
            })
        }

        $obj
    }

    $scanRuns
}
