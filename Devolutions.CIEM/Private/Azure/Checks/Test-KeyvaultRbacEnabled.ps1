function Test-KeyvaultRbacEnabled {
    <#
    .SYNOPSIS
        Tests that RBAC authorization is enabled for Azure Key Vaults.

    .DESCRIPTION
        Verifies that Key Vaults are configured to use Role-Based Access Control (RBAC)
        instead of vault access policies. RBAC provides finer-grained access control
        and enables Privileged Identity Management (PIM) for just-in-time access.

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

    $ErrorActionPreference = 'Stop'

    foreach ($subscriptionId in $script:KeyVaultService.Keys) {
        $kvData = $script:KeyVaultService[$subscriptionId]

        foreach ($vault in $kvData.KeyVaults) {
            # Strict mode safe property access
            $isRbacEnabled = if ($vault.properties.PSObject.Properties['enableRbacAuthorization']) {
                $vault.properties.enableRbacAuthorization -eq $true
            }
            else {
                $false
            }

            $status = if ($isRbacEnabled) { 'PASS' } else { 'FAIL' }
            $message = if ($isRbacEnabled) {
                "Vault '$($vault.name)' has RBAC authorization enabled. Access is managed through Azure role assignments."
            }
            else {
                "Vault '$($vault.name)' uses vault access policies instead of RBAC. Consider enabling RBAC for finer-grained access control and PIM integration."
            }

            $params = @{
                CheckMetadata  = $CheckMetadata
                Status         = $status
                StatusExtended = $message
                ResourceId     = $vault.id
                ResourceName   = $vault.name
                Location       = $vault.location
            }
            New-CIEMFinding @params
        }
    }
}
