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
        $Check
    )

    Test-KeyVaultItemExpiration -Check $Check -ItemType 'Secrets' -RequireRbac $true
}
