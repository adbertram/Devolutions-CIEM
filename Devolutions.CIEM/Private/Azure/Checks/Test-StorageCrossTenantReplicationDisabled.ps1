function Test-StorageCrossTenantReplicationDisabled {
    <#
    .SYNOPSIS
        Tests if cross-tenant replication is disabled on storage accounts.

    .DESCRIPTION
        Ensures that cross-tenant replication is not enabled on Azure Storage Accounts
        to prevent unintended replication of data across tenant boundaries.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata from AzureChecks.json.

    .OUTPUTS
        [PSCustomObject[]] Array of finding objects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
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

            # allowCrossTenantReplication: false means cross-tenant replication is disabled (pass)
            # allowCrossTenantReplication: true or null means it could be enabled (fail)
            # Strict mode safe property access
            $allowCrossTenantReplication = if ($account.properties.PSObject.Properties['allowCrossTenantReplication']) {
                $account.properties.allowCrossTenantReplication
            }
            else {
                $null
            }

            if ($allowCrossTenantReplication -eq $false) {
                $status = 'PASS'
                $statusExtended = "Storage account '$accountName' has cross-tenant replication disabled."
            }
            else {
                $status = 'FAIL'
                $statusExtended = "Storage account '$accountName' allows cross-tenant replication. Disable cross-tenant replication to prevent data leakage across tenant boundaries."
            }

            [PSCustomObject]@{
                CheckId        = $CheckMetadata.id
                Status         = $status
                StatusExtended = $statusExtended
                ResourceId     = $resourceId
                ResourceName   = $accountName
                Location       = $account.location
                Severity       = $CheckMetadata.severity
            }
        }
    }
}
