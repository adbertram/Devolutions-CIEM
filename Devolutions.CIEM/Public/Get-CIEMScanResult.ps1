function Get-CIEMScanResult {
    <#
    .SYNOPSIS
        Retrieves scan results for a specific ScanRun from cache.
    .DESCRIPTION
        Retrieves the CIEMScanResult array for a given ScanRunId from PSU persistent cache.
        This function is used to get the detailed results for a specific scan run.
    .PARAMETER ScanRunId
        The ID of the ScanRun to get results for (required).
    .EXAMPLE
        $scanRun = Get-CIEMScanRun | Select-Object -First 1
        $results = Get-CIEMScanResult -ScanRunId $scanRun.Id

        Gets results for the most recent scan run.
    .EXAMPLE
        $failed = Get-CIEMScanResult -ScanRunId $scanRun.Id | Where-Object { $_.Status -eq 'FAIL' }

        Gets only the failed results from a scan run.
    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [string]$ScanRunId
    )

    $psuCacheAvailable = Get-Command -Name 'Get-PSUCache' -ErrorAction Ignore
    if (-not $psuCacheAvailable) {
        Write-Verbose "PSU cache not available"
        return @()
    }

    $resultsKey = "CIEM:ScanResults:$ScanRunId"
    $results = Get-PSUCache -Key $resultsKey -ErrorAction Ignore

    if (-not $results) {
        Write-Verbose "No results found for ScanRunId: $ScanRunId"
        return @()
    }

    return @($results)
}
