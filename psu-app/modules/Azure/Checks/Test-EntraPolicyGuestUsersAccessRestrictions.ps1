function Test-EntraPolicyGuestUsersAccessRestrictions {
    <#
    .SYNOPSIS
        Authorization policy restricts guest user access to properties and memberships of their own directory objects

    .DESCRIPTION
        **Microsoft Entra authorization policy** guest settings are assessed to determine whether guest user access is limited to the properties and memberships of their own directory objects (`Restricted access`) instead of broader visibility into users and groups

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: entra_policy_guest_users_access_restrictions

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check entra_policy_guest_users_access_restrictions for reference.', 'N/A', 'entra Resources')
}
