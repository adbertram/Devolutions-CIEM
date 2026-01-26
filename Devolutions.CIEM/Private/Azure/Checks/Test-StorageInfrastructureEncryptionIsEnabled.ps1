function Test-StorageInfrastructureEncryptionIsEnabled {
    <#
    .SYNOPSIS
        Tests if infrastructure encryption is enabled for storage accounts.

    .DESCRIPTION
        Ensures that 'Enable Infrastructure Encryption' is set to 'enabled'
        for Azure Storage accounts to provide double encryption protection.

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
        PropertyPath  = 'properties.encryption.requireInfrastructureEncryption'
        ExpectedValue = $true
        PassMessage   = "Storage account '{0}' has infrastructure encryption (double encryption) enabled."
        FailMessage   = "Storage account '{0}' does not have infrastructure encryption enabled. Enable infrastructure encryption for double encryption protection."
        DefaultValue  = $false
    }
    Test-StorageAccountProperty @params
}
