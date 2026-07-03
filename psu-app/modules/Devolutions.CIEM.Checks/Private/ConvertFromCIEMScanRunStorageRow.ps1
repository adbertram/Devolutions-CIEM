function ConvertFromCIEMScanRunStorageRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Row
    )

    $ErrorActionPreference = 'Stop'

    $providers = @(
        Invoke-CIEMQuery -Query 'SELECT provider FROM scan_run_providers WHERE scan_run_id = @scan_run_id ORDER BY provider' -Parameters @{
            scan_run_id = [string]$Row.id
        } | ForEach-Object { [string]$_.provider }
    )

    [PSCustomObject]@{
        Id                = [string]$Row.id
        Type              = [string]$Row.scan_type
        Status            = [string]$Row.status
        Providers         = $providers
        ProviderSummaries = @()
        Services          = @()
        StartTime         = if ($Row.started_at) { [datetime]$Row.started_at } else { $null }
        EndTime           = if ($Row.completed_at) { [datetime]$Row.completed_at } else { $null }
        Duration          = if ($Row.duration_seconds) {
            $span = [timespan]::FromSeconds($Row.duration_seconds)
            if ($span.TotalMinutes -ge 1) { "{0:N0}m {1:N0}s" -f [Math]::Floor($span.TotalMinutes), $span.Seconds }
            else { "{0:N0}s" -f $span.TotalSeconds }
        } else { $null }
        IncludePassed     = [bool]$Row.include_passed
        TotalResults      = [int]$Row.total_results
        FailedResults     = [int]$Row.failed_results
        PassedResults     = [int]$Row.passed_results
        SkippedResults    = [int]$Row.skipped_results
        ManualResults     = [int]$Row.manual_results
        ErrorMessage      = $Row.error_message
        DiscoveryRunId    = if ($null -eq $Row.discovery_run_id) { $null } else { [int]$Row.discovery_run_id }
        ProviderExplicit  = [bool]$Row.provider_explicit
        ProgressEligible  = [bool]$Row.progress_eligible
        ProgressScopeHash = $Row.progress_scope_hash
    }
}
