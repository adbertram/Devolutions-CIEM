function Test-KeyvaultKeyExpirationSetInNonRbac {
    <#
    .SYNOPSIS
        Tests that all keys in non-RBAC Key Vaults have expiration dates set.

    .DESCRIPTION
        For Key Vaults that use access policy authorization (non-RBAC), verifies that all
        keys have an expiration date configured. Keys without expiration dates can remain
        valid indefinitely, which poses a security risk.

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

    Test-KeyVaultItemExpiration -Check $Check -ServiceCache $ServiceCache -ItemType 'Keys' -RequireRbac $false
}
