function Test-StorageSmbChannelEncryptionWithSecureAlgorithm {
    <#
    .SYNOPSIS
        Tests if SMB channel encryption uses secure algorithms.

    .DESCRIPTION
        Ensures that SMB channel encryption for file shares uses secure algorithms
        like AES-256-GCM for data confidentiality and integrity in transit.

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
                $statusExtended = "Storage account '$accountName' file service configuration could not be retrieved. SMB channel encryption status is unknown."
            }
            else {
                # Check SMB protocol settings (strict mode safe)
                $protocolSettings = if ($fileService.PSObject.Properties['properties'] -and
                    $fileService.properties.PSObject.Properties['protocolSettings']) {
                    $fileService.properties.protocolSettings
                }
                else {
                    $null
                }
                $smbSettings = if ($protocolSettings -and $protocolSettings.PSObject.Properties['smb']) {
                    $protocolSettings.smb
                }
                else {
                    $null
                }
                $channelEncryption = if ($smbSettings -and $smbSettings.PSObject.Properties['channelEncryption']) {
                    $smbSettings.channelEncryption
                }
                else {
                    $null
                }

                # channelEncryption can be a semicolon-separated string like "AES-128-CCM;AES-128-GCM;AES-256-GCM"
                # or an array of values
                $hasSecureEncryption = $false
                if ($channelEncryption) {
                    if ($channelEncryption -is [string]) {
                        $hasSecureEncryption = $channelEncryption -match 'AES-256-GCM'
                    }
                    elseif ($channelEncryption -is [array]) {
                        $hasSecureEncryption = $channelEncryption -contains 'AES-256-GCM'
                    }
                }

                if ($hasSecureEncryption) {
                    $status = 'PASS'
                    $statusExtended = "Storage account '$accountName' SMB channel encryption includes AES-256-GCM."
                }
                else {
                    $currentEncryption = if ($channelEncryption) { $channelEncryption } else { 'not configured' }
                    $status = 'FAIL'
                    $statusExtended = "Storage account '$accountName' SMB channel encryption does not include AES-256-GCM (current: $currentEncryption). Configure SMB to use AES-256-GCM for secure encryption."
                }
            }

            [CIEMScanResult]::Create($Check, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
