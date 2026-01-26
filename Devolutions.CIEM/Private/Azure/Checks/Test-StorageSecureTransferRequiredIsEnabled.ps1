function Test-StorageSecureTransferRequiredIsEnabled {
    <#
    .SYNOPSIS
        Tests if secure transfer (HTTPS) is required for storage accounts.

    .DESCRIPTION
        Ensures that all data transferred between clients and Azure Storage
        accounts is encrypted using the HTTPS protocol.

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
        PropertyPath  = 'properties.supportsHttpsTrafficOnly'
        ExpectedValue = $true
        PassMessage   = "Storage account '{0}' requires secure transfer (HTTPS only)."
        FailMessage   = "Storage account '{0}' does not require secure transfer. Enable 'Secure transfer required' to enforce HTTPS connections."
    }
    Test-StorageAccountProperty @params
}
