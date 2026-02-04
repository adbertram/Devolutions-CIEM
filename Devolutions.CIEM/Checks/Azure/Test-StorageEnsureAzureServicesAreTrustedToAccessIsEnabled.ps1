function Test-StorageEnsureAzureServicesAreTrustedToAccessIsEnabled {
    <#
    .SYNOPSIS
        Tests if trusted Microsoft services are allowed to access the storage account.

    .DESCRIPTION
        Ensures that 'Allow trusted Microsoft services to access this storage account'
        is enabled within your Azure Storage account configuration.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata from AzureChecks.json.

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    foreach ($subscriptionId in $script:StorageService.Keys) {
        $storageData = $script:StorageService[$subscriptionId]

        foreach ($account in $storageData.StorageAccounts) {
            $accountName = $account.name
            $resourceId = $account.id

            # networkAcls.bypass should include 'AzureServices' to allow trusted services
            # Strict mode safe property access
            $networkAcls = if ($account.properties.PSObject.Properties['networkAcls']) {
                $account.properties.networkAcls
            }
            else {
                $null
            }
            $bypass = if ($networkAcls -and $networkAcls.PSObject.Properties['bypass']) {
                $networkAcls.bypass
            }
            else {
                $null
            }

            # bypass is a comma-separated string like "AzureServices, Logging, Metrics" or "None"
            $allowsAzureServices = $false
            if ($bypass) {
                $allowsAzureServices = $bypass -match 'AzureServices'
            }

            if ($allowsAzureServices) {
                $status = 'PASS'
                $statusExtended = "Storage account '$accountName' allows trusted Microsoft services to access it."
            }
            else {
                $status = 'FAIL'
                $statusExtended = "Storage account '$accountName' does not allow trusted Microsoft services to access it. Enable 'Allow trusted Microsoft services' in network settings."
            }

            [CIEMScanResult]::Create($CheckMetadata, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
