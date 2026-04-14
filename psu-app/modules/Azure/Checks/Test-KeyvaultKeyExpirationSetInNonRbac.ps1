function Test-KeyvaultKeyExpirationSetInNonRbac {
    <#
    .SYNOPSIS
        Key Vault without RBAC authorization has expiration date set for all enabled keys

    .DESCRIPTION
        **Azure Key Vaults** using access **policies (non-RBAC)** are assessed to confirm all **enabled keys** have an `expiration` (`exp`) defined. The finding highlights keys in these vaults that lack a set lifetime.

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

    # TODO: Implement check logic based on Prowler check: keyvault_key_expiration_set_in_non_rbac

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check keyvault_key_expiration_set_in_non_rbac for reference.', 'N/A', 'keyvault Resources')
}
