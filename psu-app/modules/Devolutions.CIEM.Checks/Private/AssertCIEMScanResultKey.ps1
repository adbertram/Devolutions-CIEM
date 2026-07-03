function AssertCIEMScanResultKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter()]
        [string]$CheckId,

        [Parameter()]
        [string]$ResourceId,

        [Parameter()]
        [string]$Context
    )

    $ErrorActionPreference = 'Stop'

    if ($Status -ne 'FAIL') {
        return
    }

    $prefix = if ([string]::IsNullOrWhiteSpace($Context)) { 'Failed scan result' } else { "Failed scan result in $Context" }
    if ([string]::IsNullOrWhiteSpace($CheckId)) {
        throw "${prefix}: CheckId is required for failed scan results."
    }
    if ([string]::IsNullOrWhiteSpace($ResourceId)) {
        throw "${prefix}: ResourceId is required for failed scan results."
    }
}
