function Get-CIEMEnvironmentalProgressEvidencePairOption {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    @(GetCIEMEnvironmentalProgressEvidencePair -All | ForEach-Object {
        [pscustomobject]@{
            Value                  = [string]$_.EvidencePairId
            Label                  = "Baseline $($_.BaselineCompletedAt) -> Current $($_.CurrentCompletedAt)"
            BaselineDiscoveryRunId = $_.BaselineDiscoveryRunId
            BaselineScanRunId      = $_.BaselineScanRunId
            CurrentDiscoveryRunId  = $_.CurrentDiscoveryRunId
            CurrentScanRunId       = $_.CurrentScanRunId
            BaselineCompletedAt    = $_.BaselineCompletedAt
            CurrentCompletedAt     = $_.CurrentCompletedAt
        }
    })
}
