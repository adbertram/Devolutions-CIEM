function Test-StorageSecureTransferRequiredIsEnabled {
    <#
    .SYNOPSIS
        Tests if secure transfer (HTTPS) is required for storage accounts.

    .DESCRIPTION
        Ensures that all data transferred between clients and Azure Storage
        accounts is encrypted using the HTTPS protocol.

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

    $params = @{
        Check = $Check
        PropertyPath  = 'properties.supportsHttpsTrafficOnly'
        ExpectedValue = $true
        PassMessage   = "Storage account '{0}' requires secure transfer (HTTPS only)."
        FailMessage   = "Storage account '{0}' does not require secure transfer. Enable 'Secure transfer required' to enforce HTTPS connections."
    }
    Test-StorageAccountProperty @params
}
