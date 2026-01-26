function Test-StorageAccountKeyAccessDisabled {
    <#
    .SYNOPSIS
        Tests if storage account key access is disabled.

    .DESCRIPTION
        Ensures that access to Azure Storage Accounts using account keys is disabled,
        enforcing the use of Microsoft Entra ID for authentication.

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

    $params = @{
        CheckMetadata = $CheckMetadata
        PropertyPath  = 'properties.allowSharedKeyAccess'
        ExpectedValue = $false
        PassMessage   = "Storage account '{0}' has shared key access disabled."
        FailMessage   = "Storage account '{0}' has shared key access enabled. Disable shared key access to enforce Entra ID authentication."
    }
    Test-StorageAccountProperty @params
}
