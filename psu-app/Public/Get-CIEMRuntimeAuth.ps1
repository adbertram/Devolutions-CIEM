function Get-CIEMRuntimeAuth {
    <#
    .SYNOPSIS
        Returns the runtime authentication context for a cloud provider.
    .DESCRIPTION
        Exposes the module-scoped authentication context populated by Connect-CIEM.
        Used by the Checks module to access provider auth info (TenantId,
        SubscriptionIds, AccountId, etc.) without direct $script: access.
    .PARAMETER Provider
        Provider name to retrieve auth context for. If omitted, returns the
        full hashtable of all authenticated providers.
    .OUTPUTS
        [PSCustomObject] or [hashtable]
    .EXAMPLE
        $auth = Get-CIEMRuntimeAuth -Provider Azure
        $auth.TenantId
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Provider
    )

    if ($Provider) {
        $script:AuthContext[$Provider.ToString()]
    } else {
        $script:AuthContext
    }
}
