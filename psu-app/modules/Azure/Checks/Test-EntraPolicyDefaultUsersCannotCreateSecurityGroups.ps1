function Test-EntraPolicyDefaultUsersCannotCreateSecurityGroups {
    <#
    .SYNOPSIS
        Authorization policy disallows non-privileged users from creating security groups

    .DESCRIPTION
        **Microsoft Entra authorization policy** setting for default user role permissions governing creation of **security groups** by non-privileged users.
        
        The value of `allowed_to_create_security_groups` is examined to ensure group creation is limited to administrators across portals, API, and PowerShell.

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

    # TODO: Implement check logic based on Prowler check: entra_policy_default_users_cannot_create_security_groups

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check entra_policy_default_users_cannot_create_security_groups for reference.', 'N/A', 'entra Resources')
}
