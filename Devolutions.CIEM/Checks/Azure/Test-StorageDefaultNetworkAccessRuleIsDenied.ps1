function Test-StorageDefaultNetworkAccessRuleIsDenied {
    <#
    .SYNOPSIS
        Tests if the default network access rule is set to deny.

    .DESCRIPTION
        Ensures that the default network access rule for storage accounts is set to Deny,
        restricting access to traffic from all networks by default.

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

            # networkAcls.defaultAction should be 'Deny' for secure configuration
            # If 'Allow', all network traffic is permitted by default
            # Strict mode safe property access
            $networkAcls = if ($account.properties.PSObject.Properties['networkAcls']) {
                $account.properties.networkAcls
            }
            else {
                $null
            }
            $defaultAction = if ($networkAcls -and $networkAcls.PSObject.Properties['defaultAction']) {
                $networkAcls.defaultAction
            }
            else {
                'Allow'
            }

            if ($defaultAction -eq 'Deny') {
                $status = 'PASS'
                $statusExtended = "Storage account '$accountName' has default network access rule set to Deny."
            }
            else {
                $status = 'FAIL'
                $statusExtended = "Storage account '$accountName' has default network access rule set to '$defaultAction'. Set the default action to 'Deny' to restrict access."
            }

            [CIEMScanResult]::Create($Check, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
