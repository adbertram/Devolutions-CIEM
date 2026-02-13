function Test-StorageEnsureSoftDeleteIsEnabled {
    <#
    .SYNOPSIS
        Tests if soft delete is enabled for Azure Containers and Blob Storage.

    .DESCRIPTION
        Ensures that soft delete is enabled for both blobs and containers
        to protect against accidental data loss.

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

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'Storage' }).CacheData

    foreach ($subscriptionId in $svc.Keys) {
        $storageData = $svc[$subscriptionId]

        foreach ($account in $storageData.StorageAccounts) {
            $accountName = $account.name
            $resourceId = $account.id

            # Get blob service configuration for this account
            $blobService = $storageData.BlobServices[$accountName]

            if (-not $blobService) {
                $status = 'FAIL'
                $statusExtended = "Storage account '$accountName' blob service configuration could not be retrieved. Soft delete status is unknown."
            }
            else {
                # Check blob soft delete (strict mode safe)
                $blobDeleteRetentionPolicy = if ($blobService.PSObject.Properties['properties'] -and
                    $blobService.properties.PSObject.Properties['deleteRetentionPolicy']) {
                    $blobService.properties.deleteRetentionPolicy
                }
                else {
                    $null
                }
                $blobSoftDeleteEnabled = if ($blobDeleteRetentionPolicy -and
                    $blobDeleteRetentionPolicy.PSObject.Properties['enabled']) {
                    $blobDeleteRetentionPolicy.enabled
                }
                else {
                    $false
                }
                $blobRetentionDays = if ($blobDeleteRetentionPolicy -and
                    $blobDeleteRetentionPolicy.PSObject.Properties['days']) {
                    $blobDeleteRetentionPolicy.days
                }
                else {
                    0
                }

                # Check container soft delete (strict mode safe)
                $containerDeleteRetentionPolicy = if ($blobService.PSObject.Properties['properties'] -and
                    $blobService.properties.PSObject.Properties['containerDeleteRetentionPolicy']) {
                    $blobService.properties.containerDeleteRetentionPolicy
                }
                else {
                    $null
                }
                $containerSoftDeleteEnabled = if ($containerDeleteRetentionPolicy -and
                    $containerDeleteRetentionPolicy.PSObject.Properties['enabled']) {
                    $containerDeleteRetentionPolicy.enabled
                }
                else {
                    $false
                }
                $containerRetentionDays = if ($containerDeleteRetentionPolicy -and
                    $containerDeleteRetentionPolicy.PSObject.Properties['days']) {
                    $containerDeleteRetentionPolicy.days
                }
                else {
                    0
                }

                $issues = @()

                if (-not $blobSoftDeleteEnabled) {
                    $issues += 'blob soft delete is not enabled'
                }
                if (-not $containerSoftDeleteEnabled) {
                    $issues += 'container soft delete is not enabled'
                }

                if ($issues.Count -eq 0) {
                    $status = 'PASS'
                    $statusExtended = "Storage account '$accountName' has soft delete enabled for blobs ($blobRetentionDays days) and containers ($containerRetentionDays days)."
                }
                else {
                    $status = 'FAIL'
                    $statusExtended = "Storage account '$accountName': $($issues -join '; '). Enable soft delete for both blobs and containers."
                }
            }

            [CIEMScanResult]::Create($Check, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
