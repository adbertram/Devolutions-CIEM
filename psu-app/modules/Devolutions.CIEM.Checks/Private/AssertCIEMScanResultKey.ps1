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
    [CIEMScanResult]::AssertScanResultKey($Status, $CheckId, $ResourceId, $Context)
}
