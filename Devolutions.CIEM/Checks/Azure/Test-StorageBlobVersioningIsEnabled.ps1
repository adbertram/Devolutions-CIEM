function Test-StorageBlobVersioningIsEnabled {
    <#
    .SYNOPSIS
        Tests if blob versioning is enabled on storage accounts.

    .DESCRIPTION
        Ensures that blob versioning is enabled on Azure Blob Storage accounts
        to automatically retain previous versions of objects.

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

    foreach ($subscriptionId in $script:StorageService.Keys) {
        $storageData = $script:StorageService[$subscriptionId]

        foreach ($account in $storageData.StorageAccounts) {
            $accountName = $account.name
            $resourceId = $account.id

            # Get blob service configuration for this account
            $blobService = $storageData.BlobServices[$accountName]

            if (-not $blobService) {
                $status = 'FAIL'
                $statusExtended = "Storage account '$accountName' blob service configuration could not be retrieved. Blob versioning status is unknown."
            }
            else {
                # Strict mode safe property access
                $isVersioningEnabled = if ($blobService.PSObject.Properties['properties'] -and
                    $blobService.properties.PSObject.Properties['isVersioningEnabled']) {
                    $blobService.properties.isVersioningEnabled
                }
                else {
                    $null
                }

                if ($isVersioningEnabled -eq $true) {
                    $status = 'PASS'
                    $statusExtended = "Storage account '$accountName' has blob versioning enabled."
                }
                else {
                    $status = 'FAIL'
                    $statusExtended = "Storage account '$accountName' does not have blob versioning enabled. Enable versioning to protect against accidental data loss."
                }
            }

            [CIEMScanResult]::Create($Check, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
