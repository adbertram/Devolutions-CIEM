function Save-CIEMScanRun {
    <#
    .SYNOPSIS
        Persists a CIEMScanRun to PSU cache.
    .DESCRIPTION
        Saves the ScanRun metadata and optionally its results to PSU persistent cache.
        Maintains scan history (last 10 scans) and tracks current scan ID.
    .PARAMETER ScanRun
        The CIEMScanRun object to persist.
    .OUTPUTS
        None
        This function does not return output.
    .EXAMPLE
        $scanRun = New-CIEMScanRun -Provider 'Azure' -Services @('Entra')
        Save-CIEMScanRun -ScanRun $scanRun

        Persists a scan run to the PSU cache.
    .EXAMPLE
        $scanRun | Save-CIEMScanRun

        Persists a scan run via pipeline input.
    .NOTES
        Cache keys used:
        - CIEM:ScanRuns:{Id} - ScanRun metadata (hashtable)
        - CIEM:ScanResults:{Id} - ScanResults array
        - CIEM:ScanRunHistory - Unlimited scan history
        - CIEM:CurrentScanRun - Current scan ID
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $ScanRun
    )

    process {
        $psuCacheAvailable = Get-Command -Name 'Set-PSUCache' -ErrorAction Ignore
        if (-not $psuCacheAvailable) {
            Write-Verbose "PSU cache not available - ScanRun not persisted"
            return
        }

        # 1. Store ScanRun metadata as PSCustomObject (class instances lose data in PSU cache)
        $metadataKey = "CIEM:ScanRuns:$($ScanRun.Id)"
        $serializableRun = [PSCustomObject]@{
            Id                = $ScanRun.Id
            Status            = [string]$ScanRun.Status
            Providers         = @($ScanRun.Providers)
            ProviderSummaries = @($ScanRun.ProviderSummaries)
            Services          = @($ScanRun.Services)
            StartTime         = $ScanRun.StartTime
            EndTime           = $ScanRun.EndTime
            Duration          = $ScanRun.Duration
            IncludePassed     = $ScanRun.IncludePassed
            TotalResults      = $ScanRun.TotalResults
            FailedResults     = $ScanRun.FailedResults
            PassedResults     = $ScanRun.PassedResults
            SkippedResults    = $ScanRun.SkippedResults
            ManualResults     = $ScanRun.ManualResults
            ErrorMessage      = $ScanRun.ErrorMessage
        }
        Set-PSUCache -Key $metadataKey -Value $serializableRun -Persist -Integrated

        # 2. Store ScanResults separately (if present)
        #    Convert CIEMScanResult class instances to PSCustomObjects so PSU cache
        #    serializes their properties (class instances only get .ToString() → "CIEMScanResult")
        if ($ScanRun.ScanResults -and $ScanRun.ScanResults.Count -gt 0) {
            $resultsKey = "CIEM:ScanResults:$($ScanRun.Id)"
            $serializableResults = @($ScanRun.ScanResults | ForEach-Object {
                [PSCustomObject]@{
                    Check          = $_.Check  # Already a PSCustomObject from Get-CIEMCheck
                    Status         = [string]$_.Status
                    StatusExtended = $_.StatusExtended
                    ResourceId     = $_.ResourceId
                    ResourceName   = $_.ResourceName
                    Location       = $_.Location
                }
            })
            Set-PSUCache -Key $resultsKey -Value $serializableResults -Persist -Integrated
        }

        # 3. Update scan history (prepend, keep last 10)
        $historyKey = 'CIEM:ScanRunHistory'
        $existingHistory = Get-PSUCache -Key $historyKey -Integrated -ErrorAction Ignore
        if (-not $existingHistory) { $existingHistory = @() }

        # Remove this scan if it already exists in history (for updates)
        $existingHistory = @($existingHistory | Where-Object { $_.Id -ne $ScanRun.Id })
        # Prepend current scan (as serializable PSCustomObject) — no cap, keep all history
        $existingHistory = @($serializableRun) + @($existingHistory)
        Set-PSUCache -Key $historyKey -Value $existingHistory -Persist -Integrated

        # 4. Update current scan ID
        Set-PSUCache -Key 'CIEM:CurrentScanRun' -Value $ScanRun.Id -Persist -Integrated

        Write-Verbose "Persisted ScanRun: $($ScanRun.Id) (Status: $($ScanRun.Status))"
    }
}
