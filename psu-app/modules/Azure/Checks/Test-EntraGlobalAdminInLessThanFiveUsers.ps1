function Test-EntraGlobalAdminInLessThanFiveUsers {
    <#
    .SYNOPSIS
        Global Administrator role has fewer than 5 members

    .DESCRIPTION
        **Microsoft Entra Global Administrator** assignments are evaluated by counting current role members per tenant and identifying when the number of assignees is `5` or more.

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

    # TODO: Implement check logic based on Prowler check: entra_global_admin_in_less_than_five_users

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check entra_global_admin_in_less_than_five_users for reference.', 'N/A', 'entra Resources')
}
