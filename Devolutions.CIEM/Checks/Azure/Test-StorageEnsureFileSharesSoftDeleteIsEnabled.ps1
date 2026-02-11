function Test-StorageEnsureFileSharesSoftDeleteIsEnabled {
    <#
    .SYNOPSIS
        Tests if soft delete is enabled for Azure File Shares.

    .DESCRIPTION
        Ensures that soft delete is enabled for Azure File Shares to protect
        against accidental or malicious deletion of important data.

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

            # Get file service configuration for this account
            $fileService = $storageData.FileServices[$accountName]

            if (-not $fileService) {
                # File service may not be configured or accessible
                $status = 'FAIL'
                $statusExtended = "Storage account '$accountName' file service configuration could not be retrieved. File share soft delete status is unknown."
            }
            else {
                # Strict mode safe property access
                $shareDeleteRetentionPolicy = if ($fileService.PSObject.Properties['properties'] -and
                    $fileService.properties.PSObject.Properties['shareDeleteRetentionPolicy']) {
                    $fileService.properties.shareDeleteRetentionPolicy
                }
                else {
                    $null
                }
                $isEnabled = if ($shareDeleteRetentionPolicy -and $shareDeleteRetentionPolicy.PSObject.Properties['enabled']) {
                    $shareDeleteRetentionPolicy.enabled
                }
                else {
                    $false
                }
                $retentionDays = if ($shareDeleteRetentionPolicy -and $shareDeleteRetentionPolicy.PSObject.Properties['days']) {
                    $shareDeleteRetentionPolicy.days
                }
                else {
                    0
                }

                if ($isEnabled -eq $true) {
                    $status = 'PASS'
                    $statusExtended = "Storage account '$accountName' has file share soft delete enabled with $retentionDays days retention."
                }
                else {
                    $status = 'FAIL'
                    $statusExtended = "Storage account '$accountName' does not have file share soft delete enabled. Enable soft delete to protect against accidental deletion."
                }
            }

            [CIEMScanResult]::Create($Check, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
