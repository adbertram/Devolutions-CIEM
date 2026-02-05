function Test-KeyvaultNonRbacSecretExpirationSet {
    <#
    .SYNOPSIS
        Tests that all secrets in non-RBAC Key Vaults have expiration dates set.

    .DESCRIPTION
        For Key Vaults that use access policy authorization (non-RBAC), verifies that all
        secrets have an expiration date configured. Secrets without expiration dates can
        remain valid indefinitely, which poses a security risk.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    Test-KeyVaultItemExpiration -Check $Check -ItemType 'Secrets' -RequireRbac $false
}
