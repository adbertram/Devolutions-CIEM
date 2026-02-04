function Test-KeyvaultNonRbacSecretExpirationSet {
    <#
    .SYNOPSIS
        Tests that all secrets in non-RBAC Key Vaults have expiration dates set.

    .DESCRIPTION
        For Key Vaults that use access policy authorization (non-RBAC), verifies that all
        secrets have an expiration date configured. Secrets without expiration dates can
        remain valid indefinitely, which poses a security risk.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata (id, service, title, severity).

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    Test-KeyVaultItemExpiration -CheckMetadata $CheckMetadata -ItemType 'Secrets' -RequireRbac $false
}
