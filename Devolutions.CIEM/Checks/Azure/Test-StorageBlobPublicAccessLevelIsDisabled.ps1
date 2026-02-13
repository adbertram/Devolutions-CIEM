function Test-StorageBlobPublicAccessLevelIsDisabled {
    <#
    .SYNOPSIS
        Tests if blob public access is disabled at the account and container level.

    .DESCRIPTION
        Ensures that the 'Public access level' is set to 'Private (no anonymous access)'
        for all blob containers in your storage account.

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

    # Prowler simply checks the account-level allowBlobPublicAccess property
    $params = @{
        Check = $Check
        PropertyPath  = 'properties.allowBlobPublicAccess'
        ExpectedValue = $false
        PassMessage   = "Storage account '{0}' has allow blob public access disabled."
        FailMessage   = "Storage account '{0}' has allow blob public access enabled."
        ServiceCache  = $ServiceCache
    }
    Test-StorageAccountProperty @params
}
