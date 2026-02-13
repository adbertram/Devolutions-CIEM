function Test-KeyvaultRbacEnabled {
    <#
    .SYNOPSIS
        Tests that RBAC authorization is enabled for Azure Key Vaults.

    .DESCRIPTION
        Verifies that Key Vaults are configured to use Role-Based Access Control (RBAC)
        instead of vault access policies. RBAC provides finer-grained access control
        and enables Privileged Identity Management (PIM) for just-in-time access.

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

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'KeyVault' }).CacheData

    foreach ($subscriptionId in $svc.Keys) {
        $kvData = $svc[$subscriptionId]

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

            [CIEMScanResult]::Create($Check, $status, $message, $vault.id, $vault.name, $vault.location)
        }
    }
}
