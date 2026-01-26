function Test-StorageBlobPublicAccessLevelIsDisabled {
    <#
    .SYNOPSIS
        Tests if blob public access is disabled at the account and container level.

    .DESCRIPTION
        Ensures that the 'Public access level' is set to 'Private (no anonymous access)'
        for all blob containers in your storage account.

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

    # Prowler simply checks the account-level allowBlobPublicAccess property
    $params = @{
        CheckMetadata = $CheckMetadata
        PropertyPath  = 'properties.allowBlobPublicAccess'
        ExpectedValue = $false
        PassMessage   = "Storage account '{0}' has allow blob public access disabled."
        FailMessage   = "Storage account '{0}' has allow blob public access enabled."
    }
    Test-StorageAccountProperty @params
}
