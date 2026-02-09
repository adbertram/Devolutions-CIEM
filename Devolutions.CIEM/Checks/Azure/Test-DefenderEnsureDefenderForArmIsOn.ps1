function Test-DefenderEnsureDefenderForArmIsOn {
    <#
    .SYNOPSIS
        Defender for Azure Resource Manager is set to On (Standard pricing tier)

    .DESCRIPTION
        **Microsoft Defender for Cloud** plan for **Azure Resource Manager** is configured at the `Standard` tier for the subscription

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: defender_ensure_defender_for_arm_is_on

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check defender_ensure_defender_for_arm_is_on for reference.', 'N/A', 'defender Resources')
}
