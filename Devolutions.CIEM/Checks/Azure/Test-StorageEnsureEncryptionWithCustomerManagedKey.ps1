function Test-StorageEnsureEncryptionWithCustomerManagedKey {
    <#
    .SYNOPSIS
        Tests if storage accounts use Customer Managed Keys for encryption.

    .DESCRIPTION
        Ensures that Azure Storage accounts are using Customer Managed Keys (CMKs)
        instead of Microsoft Managed Keys for encryption.

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

    $ErrorActionPreference = 'Stop'

    foreach ($subscriptionId in $script:StorageService.Keys) {
        $storageData = $script:StorageService[$subscriptionId]

        foreach ($account in $storageData.StorageAccounts) {
            $accountName = $account.name
            $resourceId = $account.id

            # encryption.keySource should be 'Microsoft.Keyvault' for CMK
            # 'Microsoft.Storage' means Microsoft Managed Keys are used
            # Strict mode safe property access
            $encryption = if ($account.properties.PSObject.Properties['encryption']) {
                $account.properties.encryption
            }
            else {
                $null
            }
            $keySource = if ($encryption -and $encryption.PSObject.Properties['keySource']) {
                $encryption.keySource
            }
            else {
                'Microsoft.Storage'
            }

            if ($keySource -eq 'Microsoft.Keyvault') {
                $status = 'PASS'
                $statusExtended = "Storage account '$accountName' uses Customer Managed Keys (CMK) from Key Vault for encryption."
            }
            else {
                $status = 'FAIL'
                $statusExtended = "Storage account '$accountName' uses Microsoft Managed Keys for encryption (keySource: '$keySource'). Configure Customer Managed Keys from Key Vault for enhanced control."
            }

            [CIEMScanResult]::Create($Check, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
