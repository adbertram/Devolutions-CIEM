function Test-GuarddutyIsEnabled {
    <#
    .SYNOPSIS
        GuardDuty detector is enabled and not suspended

    .DESCRIPTION
        **Amazon GuardDuty** detector existence and health are evaluated per Region. It identifies where GuardDuty isn't enabled for the account, where a detector has no status, or where a detector is configured but `suspended`.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: guardduty_is_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check guardduty_is_enabled for reference.', 'N/A', 'guardduty Resources')
}
