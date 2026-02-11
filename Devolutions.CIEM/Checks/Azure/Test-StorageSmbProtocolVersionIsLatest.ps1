function Test-StorageSmbProtocolVersionIsLatest {
    <#
    .SYNOPSIS
        Tests if SMB protocol version is set to the latest version.

    .DESCRIPTION
        Ensures that SMB file shares are configured to use only the latest
        SMB protocol version (SMB 3.1.1) for security.

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
                $statusExtended = "Storage account '$accountName' file service configuration could not be retrieved. SMB protocol version status is unknown."
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
                $versions = if ($smbSettings -and $smbSettings.PSObject.Properties['versions']) {
                    $smbSettings.versions
                }
                else {
                    $null
                }

                # versions can be a semicolon-separated string like "SMB2.1;SMB3.0;SMB3.1.1"
                # or an array of values
                # The most secure configuration is to only allow SMB3.1.1
                $hasLatestVersion = $false
                $allowsOlderVersions = $false

                if ($versions) {
                    if ($versions -is [string]) {
                        $hasLatestVersion = $versions -match 'SMB3\.1\.1'
                        # Check if older versions are also allowed
                        $allowsOlderVersions = $versions -match 'SMB2\.1|SMB3\.0[^.]'
                    }
                    elseif ($versions -is [array]) {
                        $hasLatestVersion = $versions -contains 'SMB3.1.1'
                        $allowsOlderVersions = ($versions | Where-Object { $_ -match 'SMB2\.1|SMB3\.0' }).Count -gt 0
                    }
                }

                if ($hasLatestVersion -and -not $allowsOlderVersions) {
                    $status = 'PASS'
                    $statusExtended = "Storage account '$accountName' is configured to use only SMB 3.1.1 (latest version)."
                }
                elseif ($hasLatestVersion -and $allowsOlderVersions) {
                    $status = 'FAIL'
                    $statusExtended = "Storage account '$accountName' allows SMB 3.1.1 but also allows older versions ($versions). Configure to use only SMB 3.1.1."
                }
                else {
                    $currentVersions = if ($versions) { $versions } else { 'not configured (defaults to all versions)' }
                    $status = 'FAIL'
                    $statusExtended = "Storage account '$accountName' does not have SMB protocol version restricted to SMB 3.1.1 (current: $currentVersions). Configure to use only SMB 3.1.1."
                }
            }

            [CIEMScanResult]::Create($Check, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
