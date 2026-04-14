function InvokeCIEMCheck {
    <#
    .SYNOPSIS
        Executes a single CIEM check and emits findings to the pipeline.

    .DESCRIPTION
        Standardized entry point for running any CIEM check. Validates service
        caches, invokes the check function, counts findings, and handles errors.
        Emits [CIEMScanResult] objects to the pipeline.

        This is a private function called from InvokeCIEMScan.

    .PARAMETER Check
        The CIEMCheck metadata object describing the check to run.

    .PARAMETER ServiceCache
        Pre-resolved array of service caches the check needs. The caller resolves
        these from Check.Service + Check.DependsOn.

    .PARAMETER FunctionName
        The resolved check function name (already validated to exist).

    .PARAMETER ProviderName
        Provider name used for log/warning messages.

    .OUTPUTS
        [CIEMScanResult[]] Finding objects emitted to the pipeline.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult')]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check,

        [Parameter()]
        [CIEMServiceCache[]]$ServiceCache,

        [Parameter(Mandatory)]
        [string]$FunctionName,

        [Parameter()]
        [string]$ProviderName
    )

    $ErrorActionPreference = 'Stop'

    try {
        # Auto-skip if any required service failed to initialize
        if ($ServiceCache) {
            $failedServices = @($ServiceCache | Where-Object { -not $_.Success })
            if ($failedServices) {
                $failedDetails = @($failedServices | ForEach-Object {
                    $errorDetail = if ($_.Errors -and $_.Errors.Count -gt 0) { $_.Errors[0] } else { 'unknown error' }
                    "$($_.ServiceName): $errorDetail"
                })
                $failedMessage = "Required service(s) unavailable: $($failedDetails -join '; ')"
                Write-Verbose "[$ProviderName] Skipping check $($Check.Id) — service(s) failed: $failedMessage"
                [CIEMScanResult]::Create($Check, 'SKIPPED', $failedMessage, 'N/A', 'N/A')
                return
            }
        }

        # Build invocation parameters
        $invokeParams = @{ Check = $Check }
        if ($ServiceCache -and $ServiceCache.Count -gt 0) {
            $invokeParams.ServiceCache = $ServiceCache
        }

        # Invoke the check function and emit findings
        $checkFindingCount = 0
        foreach ($finding in (& $FunctionName @invokeParams)) {
            $checkFindingCount++
            $finding
        }

        # If zero findings, emit SKIPPED
        if ($checkFindingCount -eq 0) {
            Write-Verbose "[$ProviderName] Check $($Check.Id) produced no findings - marking as SKIPPED"
            [CIEMScanResult]::Create($Check, 'SKIPPED', 'Check produced no results - required data may be unavailable (e.g., no accessible subscriptions)', 'N/A', 'N/A')
        }
    } catch {
        throw
    }
}
