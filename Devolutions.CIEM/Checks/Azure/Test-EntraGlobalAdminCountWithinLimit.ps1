function Test-EntraGlobalAdminCountWithinLimit {
    <#
    .SYNOPSIS
        Ensure fewer than 5 users have global administrator assignment.

    .DESCRIPTION
        This recommendation aims to maintain a balance between security and operational
        efficiency by ensuring that a minimum of 2 and a maximum of 4 users are assigned
        the Global Administrator role in Microsoft Entra ID. Having at least two Global
        Administrators ensures redundancy, while limiting the number to four reduces the
        risk of excessive privileged access.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: entra_global_admin_in_less_than_five_users

    [CIEMScanResult]::Create($CheckMetadata, 'MANUAL', 'This check requires manual implementation. See Prowler check entra_global_admin_in_less_than_five_users for reference.', 'N/A', 'Global Administrator Role')
}
