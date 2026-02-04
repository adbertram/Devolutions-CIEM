function Test-StorageKeyRotation90Day {
    <#
    .SYNOPSIS
        Tests if storage account access keys have been rotated within 90 days.

    .DESCRIPTION
        Ensures that Storage Account Access Keys are periodically regenerated
        to reduce the risk of unauthorized access from exposed keys.

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

    # Prowler checks the key_expiration_period_in_days policy setting
    $ErrorActionPreference = 'Stop'
    $rotationThresholdDays = 90

    foreach ($subscriptionId in $script:StorageService.Keys) {
        $storageData = $script:StorageService[$subscriptionId]

        foreach ($account in $storageData.StorageAccounts) {
            $accountName = $account.name
            $resourceId = $account.id

            # Check keyPolicy.keyExpirationPeriodInDays (strict mode safe)
            $keyExpirationPeriod = if ($account.properties.PSObject.Properties['keyPolicy'] -and
                $account.properties.keyPolicy.PSObject.Properties['keyExpirationPeriodInDays']) {
                $account.properties.keyPolicy.keyExpirationPeriodInDays
            }
            else {
                $null
            }

            if (-not $keyExpirationPeriod) {
                $status = 'FAIL'
                $statusExtended = "Storage account $accountName has no key expiration period set."
            }
            elseif ($keyExpirationPeriod -gt $rotationThresholdDays) {
                $status = 'FAIL'
                $statusExtended = "Storage account $accountName has an invalid key expiration period of $keyExpirationPeriod days."
            }
            else {
                $status = 'PASS'
                $statusExtended = "Storage account $accountName has a key expiration period of $keyExpirationPeriod days."
            }

            [CIEMScanResult]::Create($CheckMetadata, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
