function Test-StorageEnsurePrivateEndpointInStorageAccount {
    <#
    .SYNOPSIS
        Tests if Private Endpoints are used to access storage accounts.

    .DESCRIPTION
        Ensures that Private Endpoints are configured for Azure Storage accounts
        to allow secure access over an encrypted Private Link.

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

            # Check for private endpoint connections (strict mode safe)
            $privateEndpointConnections = if ($account.properties.PSObject.Properties['privateEndpointConnections']) {
                $account.properties.privateEndpointConnections
            }
            else {
                $null
            }

            if ($privateEndpointConnections -and $privateEndpointConnections.Count -gt 0) {
                # Check if any connections are approved
                $approvedConnections = $privateEndpointConnections | Where-Object {
                    $_.properties.privateLinkServiceConnectionState.status -eq 'Approved'
                }

                if ($approvedConnections -and $approvedConnections.Count -gt 0) {
                    $status = 'PASS'
                    $statusExtended = "Storage account '$accountName' has $($approvedConnections.Count) approved private endpoint connection(s)."
                }
                else {
                    $status = 'FAIL'
                    $statusExtended = "Storage account '$accountName' has private endpoint connections but none are in 'Approved' state. Approve the pending connections or configure new private endpoints."
                }
            }
            else {
                $status = 'FAIL'
                $statusExtended = "Storage account '$accountName' does not have any private endpoints configured. Configure private endpoints for secure network access."
            }

            [CIEMScanResult]::Create($Check, $status, $statusExtended, $resourceId, $accountName, $account.location)
        }
    }
}
