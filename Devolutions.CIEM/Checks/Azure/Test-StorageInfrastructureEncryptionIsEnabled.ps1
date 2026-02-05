function Test-StorageInfrastructureEncryptionIsEnabled {
    <#
    .SYNOPSIS
        Tests if infrastructure encryption is enabled for storage accounts.

    .DESCRIPTION
        Ensures that 'Enable Infrastructure Encryption' is set to 'enabled'
        for Azure Storage accounts to provide double encryption protection.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $params = @{
        Check = $Check
        PropertyPath  = 'properties.encryption.requireInfrastructureEncryption'
        ExpectedValue = $true
        PassMessage   = "Storage account '{0}' has infrastructure encryption (double encryption) enabled."
        FailMessage   = "Storage account '{0}' does not have infrastructure encryption enabled. Enable infrastructure encryption for double encryption protection."
        DefaultValue  = $false
    }
    Test-StorageAccountProperty @params
}
