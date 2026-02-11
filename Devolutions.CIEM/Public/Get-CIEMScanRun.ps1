function Get-CIEMScanRun {
    <#
    .SYNOPSIS
        Retrieves ScanRun(s) from PSU cache.
    .DESCRIPTION
        Retrieves scan run metadata from PSU persistent cache. Can retrieve a specific
        ScanRun by ID or all scan runs from history.
    .PARAMETER Id
        ScanRun ID to retrieve. If not specified, returns all scan runs from history.
    .PARAMETER IncludeResults
        When specified, also loads the ScanResults array into the returned object(s).
    .EXAMPLE
        $scanRuns = Get-CIEMScanRun

        Gets all scan runs from history.
    .EXAMPLE
        $latest = Get-CIEMScanRun | Select-Object -First 1

        Gets the most recent scan run.
    .EXAMPLE
        $scanRun = Get-CIEMScanRun -Id 'abc-123-def' -IncludeResults

        Gets a specific scan run by ID with its results loaded.
    .OUTPUTS
        [CIEMScanRun[]] Array of ScanRun objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanRun[]])]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter()]
        [switch]$IncludeResults
    )

    $psuCacheAvailable = Get-Command -Name 'Get-PSUCache' -ErrorAction Ignore
    if (-not $psuCacheAvailable) {
        Write-Verbose "PSU cache not available"
        return @()
    }

    if ($Id) {
        # Return specific scan run
        $metadataKey = "CIEM:ScanRuns:$Id"
        $data = Get-PSUCache -Key $metadataKey -Integrated -ErrorAction Ignore

        if ($data) {
            if ($IncludeResults) {
                $resultsKey = "CIEM:ScanResults:$Id"
                $results = Get-PSUCache -Key $resultsKey -Integrated -ErrorAction Ignore
                $data | Add-Member -NotePropertyName ScanResults -NotePropertyValue @($results) -Force
            }
            return $data
        }
        else {
            Write-Verbose "ScanRun not found: $Id"
            return @()
        }
    }
    else {
        # Return all scan runs from history
        $historyData = Get-PSUCache -Key 'CIEM:ScanRunHistory' -Integrated -ErrorAction Ignore

        if ($historyData -and @($historyData).Count -gt 0) {
            $scanRuns = foreach ($item in @($historyData)) {
                if ($IncludeResults) {
                    $resultsKey = "CIEM:ScanResults:$($item.Id)"
                    $results = Get-PSUCache -Key $resultsKey -Integrated -ErrorAction Ignore
                    $item | Add-Member -NotePropertyName ScanResults -NotePropertyValue @($results) -Force
                }
                $item
            }
            return $scanRuns
        }
        else {
            Write-Verbose "No scan history found"
            return @()
        }
    }
}
