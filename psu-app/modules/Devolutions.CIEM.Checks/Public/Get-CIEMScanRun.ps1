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

    # Build query
    if ($Id) {
        $rows = @(Invoke-CIEMQuery -Query "SELECT * FROM scan_runs WHERE id = @id" -Parameters @{ id = $Id })
    } else {
        $rows = @(Invoke-CIEMQuery -Query "SELECT * FROM scan_runs ORDER BY started_at DESC")
    }

    if ($rows.Count -eq 0) {
        if ($Id) { Write-Verbose "ScanRun not found: $Id" }
        else     { Write-Verbose "No scan history found" }
        return @()
    }

    $scanRuns = foreach ($row in $rows) {
        $providers = if ($row.resource_providers) { @($row.resource_providers -split ',') } else { @() }

        $obj = [PSCustomObject]@{
            Id                = $row.id
            Status            = $row.status
            Providers         = $providers
            ProviderSummaries = @()
            Services          = @()
            StartTime         = if ($row.started_at) { [datetime]$row.started_at } else { $null }
            EndTime           = if ($row.completed_at) { [datetime]$row.completed_at } else { $null }
            Duration          = if ($row.duration_seconds) {
                $span = [timespan]::FromSeconds($row.duration_seconds)
                if ($span.TotalMinutes -ge 1) { "{0:N0}m {1:N0}s" -f [Math]::Floor($span.TotalMinutes), $span.Seconds }
                else { "{0:N0}s" -f $span.TotalSeconds }
            } else { $null }
            IncludePassed     = [bool]$row.include_passed
            TotalResults      = [int]$row.total_results
            FailedResults     = [int]$row.failed_results
            PassedResults     = [int]$row.passed_results
            SkippedResults    = [int]$row.skipped_results
            ManualResults     = [int]$row.manual_results
            ErrorMessage      = $row.error_message
        }

        if ($IncludeResults) {
            $results = @(Get-CIEMScanResult -ScanRunId $row.id)
            $obj | Add-Member -NotePropertyName ScanResults -NotePropertyValue $results -Force

            # Compute per-provider summaries
            $obj.ProviderSummaries = @(foreach ($provName in $providers) {
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
