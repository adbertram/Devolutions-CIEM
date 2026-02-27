function Test-DefenderEnsureIotHubDefenderIsOn {
    <#
    .SYNOPSIS
        Defender for IoT Hub is set to On

    .DESCRIPTION
        **Microsoft Defender for IoT security solution** exists in the subscription and reports status `Enabled` for monitored **IoT Hub** resources.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: defender_ensure_iot_hub_defender_is_on

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check defender_ensure_iot_hub_defender_is_on for reference.', 'N/A', 'defender Resources')
}
