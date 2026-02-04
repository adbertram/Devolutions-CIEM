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
        - CIEM:ScanRunHistory - Last 10 ScanRun metadata entries
        - CIEM:CurrentScanRun - Current scan ID
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [CIEMScanRun]$ScanRun
    )

    process {
        $psuCacheAvailable = Get-Command -Name 'Set-PSUCache' -ErrorAction Ignore
        if (-not $psuCacheAvailable) {
            Write-Verbose "PSU cache not available - ScanRun not persisted"
            return
        }

        # 1. Store ScanRun metadata
        $metadataKey = "CIEM:ScanRuns:$($ScanRun.Id)"
        Set-PSUCache -Key $metadataKey -Value $ScanRun.ToHashtable() -Persist

        # 2. Store ScanResults separately (if present)
        if ($ScanRun.ScanResults -and $ScanRun.ScanResults.Count -gt 0) {
            $resultsKey = "CIEM:ScanResults:$($ScanRun.Id)"
            Set-PSUCache -Key $resultsKey -Value @($ScanRun.ScanResults) -Persist
        }

        # 3. Update scan history (prepend, keep last 10)
        $historyKey = 'CIEM:ScanRunHistory'
        $existingHistory = Get-PSUCache -Key $historyKey -ErrorAction Ignore
        if (-not $existingHistory) { $existingHistory = @() }

        # Remove this scan if it already exists in history (for updates)
        $existingHistory = @($existingHistory | Where-Object { $_.Id -ne $ScanRun.Id })
        # Prepend current scan and keep last 10
        $existingHistory = @($ScanRun.ToHashtable()) + @($existingHistory) | Select-Object -First 10
        Set-PSUCache -Key $historyKey -Value $existingHistory -Persist

        # 4. Update current scan ID
        Set-PSUCache -Key 'CIEM:CurrentScanRun' -Value $ScanRun.Id -Persist

        Write-Verbose "Persisted ScanRun: $($ScanRun.Id) (Status: $($ScanRun.Status))"
    }
}
