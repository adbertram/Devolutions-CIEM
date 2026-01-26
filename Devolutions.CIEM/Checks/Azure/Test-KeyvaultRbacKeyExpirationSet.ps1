function Test-KeyvaultRbacKeyExpirationSet {
    <#
    .SYNOPSIS
        Tests that all keys in RBAC-enabled Key Vaults have expiration dates set.

    .DESCRIPTION
        For Key Vaults that use RBAC authorization, verifies that all keys have an
        expiration date configured. Keys without expiration dates can remain valid
        indefinitely, which poses a security risk.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata (id, service, title, severity).

    .OUTPUTS
        [PSCustomObject[]] Array of finding objects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    Test-KeyVaultItemExpiration -CheckMetadata $CheckMetadata -ItemType 'Keys' -RequireRbac $true
}
