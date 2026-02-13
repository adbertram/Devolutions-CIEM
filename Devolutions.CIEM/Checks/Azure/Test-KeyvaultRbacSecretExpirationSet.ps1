function Test-KeyvaultRbacSecretExpirationSet {
    <#
    .SYNOPSIS
        Tests that all secrets in RBAC-enabled Key Vaults have expiration dates set.

    .DESCRIPTION
        For Key Vaults that use RBAC authorization, verifies that all secrets have an
        expiration date configured. Secrets without expiration dates can remain valid
        indefinitely, which poses a security risk.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    Test-KeyVaultItemExpiration -Check $Check -ServiceCache $ServiceCache -ItemType 'Secrets' -RequireRbac $true
}
