function Test-KeyvaultRbacKeyExpirationSet {
    <#
    .SYNOPSIS
        Tests that all keys in RBAC-enabled Key Vaults have expiration dates set.

    .DESCRIPTION
        For Key Vaults that use RBAC authorization, verifies that all keys have an
        expiration date configured. Keys without expiration dates can remain valid
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
        $Check
    )

    Test-KeyVaultItemExpiration -Check $Check -ItemType 'Keys' -RequireRbac $true
}
