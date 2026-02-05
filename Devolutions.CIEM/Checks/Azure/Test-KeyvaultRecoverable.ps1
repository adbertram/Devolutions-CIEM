function Test-KeyvaultRecoverable {
    <#
    .SYNOPSIS
        Tests that Azure Key Vaults are configured for recoverability.

    .DESCRIPTION
        Verifies that Key Vaults have both soft delete and purge protection enabled.
        - Soft delete: Deleted vaults/objects can be recovered for 90 days
        - Purge protection: Prevents permanent deletion during retention period

        Both settings are required to ensure Key Vault data can be recovered from
        accidental or malicious deletion.

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

    $ErrorActionPreference = 'Stop'

    foreach ($subscriptionId in $script:KeyVaultService.Keys) {
        $kvData = $script:KeyVaultService[$subscriptionId]

        foreach ($vault in $kvData.KeyVaults) {
            # Strict mode safe property access
            $softDeleteEnabled = if ($vault.properties.PSObject.Properties['enableSoftDelete']) {
                $vault.properties.enableSoftDelete -eq $true
            }
            else {
                $false
            }
            $purgeProtectionEnabled = if ($vault.properties.PSObject.Properties['enablePurgeProtection']) {
                $vault.properties.enablePurgeProtection -eq $true
            }
            else {
                $false
            }

            $status, $message = switch ($true) {
                ($softDeleteEnabled -and $purgeProtectionEnabled) {
                    'PASS', "Vault '$($vault.name)' is fully recoverable with soft delete and purge protection enabled."
                }
                ($softDeleteEnabled -and -not $purgeProtectionEnabled) {
                    'FAIL', "Vault '$($vault.name)' has soft delete enabled but purge protection is disabled. Vault contents could be permanently purged before retention period ends."
                }
                default {
                    'FAIL', "Vault '$($vault.name)' does not have soft delete enabled. Deleted vault contents cannot be recovered. Enable soft delete and purge protection."
                }
            }

            [CIEMScanResult]::Create($Check, $status, $message, $vault.id, $vault.name, $vault.location)
        }
    }
}
