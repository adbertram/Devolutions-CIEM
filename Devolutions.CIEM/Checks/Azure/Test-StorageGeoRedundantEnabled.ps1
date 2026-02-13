function Test-StorageGeoRedundantEnabled {
    <#
    .SYNOPSIS
        Tests if geo-redundant storage (GRS) is enabled on storage accounts.

    .DESCRIPTION
        Ensures that geo-redundant storage (GRS) is enabled on critical Azure Storage
        Accounts for data durability and availability during regional outages.

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

    # SKU names that provide geo-redundancy
    $geoRedundantSkus = @('Standard_GRS', 'Standard_RAGRS', 'Standard_GZRS', 'Standard_RAGZRS')

    foreach ($subscriptionId in $svc.Keys) {
        $storageData = $svc[$subscriptionId]

        foreach ($account in $storageData.StorageAccounts) {
            $accountName = $account.name
            $resourceId = $account.id

            # Check the SKU name for geo-redundancy
            $skuName = $account.sku.name

            if ($geoRedundantSkus -contains $skuName) {
                $status = 'PASS'
                $statusExtended = "Storage account '$accountName' has geo-redundant storage enabled (SKU: $skuName)."
            }
            else {
                $status = 'FAIL'
                $statusExtended = "Storage account '$accountName' does not have geo-redundant storage enabled (SKU: $skuName). Consider using GRS, RA-GRS, GZRS, or RA-GZRS for critical data."
            }

            [CIEMScanResult]::Create($Check, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
