function ConvertToCIEMScanRunStorageParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ScanRun,

        [Parameter()]
        [object]$Connection
    )

    $ErrorActionPreference = 'Stop'

    $providers = @(ConvertToCIEMCanonicalProviderList -Providers @($ScanRun.Providers) -Connection $Connection)
    $providerMap = GetCIEMCanonicalProviderMap -Connection $Connection
    $primaryProviderName = [string]$providers[0]
    if (-not $providerMap.IdByName.ContainsKey($primaryProviderName)) {
        throw "Provider '$primaryProviderName' has no provider id."
    }

    $startedAt = ([datetime]$ScanRun.StartTime).ToString('o')
    $completedAt = if ($ScanRun.EndTime) { ([datetime]$ScanRun.EndTime).ToString('o') } else { $null }
    $durationSeconds = if ($ScanRun.EndTime) {
        (([datetime]$ScanRun.EndTime) - ([datetime]$ScanRun.StartTime)).TotalSeconds
    }
    else {
        $null
    }

    @{
        id                  = [string]$ScanRun.Id
        provider_id         = [string]$providerMap.IdByName[$primaryProviderName]
        scan_type           = [string]$ScanRun.Type
        status              = [string]$ScanRun.Status
        resource_filter     = $null
        resource_providers  = ($providers -join ',')
        include_passed      = if ($ScanRun.IncludePassed) { 1 } else { 0 }
        started_at          = $startedAt
        completed_at        = $completedAt
        duration_seconds    = $durationSeconds
        total_results       = [int]$ScanRun.TotalResults
        failed_results      = [int]$ScanRun.FailedResults
        passed_results      = [int]$ScanRun.PassedResults
        skipped_results     = [int]$ScanRun.SkippedResults
        manual_results      = [int]$ScanRun.ManualResults
        error_message       = $ScanRun.ErrorMessage
        discovery_run_id    = if ($null -ne $ScanRun.DiscoveryRunId) { [int]$ScanRun.DiscoveryRunId } else { $null }
        provider_explicit   = if ($ScanRun.ProviderExplicit) { 1 } else { 0 }
        progress_eligible   = if ($ScanRun.ProgressEligible) { 1 } else { 0 }
        progress_scope_hash = $ScanRun.ProgressScopeHash
    }
}
