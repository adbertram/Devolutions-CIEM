function Test-StorageDefaultToEntraAuthorizationEnabled {
    <#
    .SYNOPSIS
        Tests if Microsoft Entra authorization is the default for storage accounts.

    .DESCRIPTION
        Ensures that the Azure Storage Account setting 'Default to Microsoft Entra
        authorization in the Azure portal' is enabled.

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
        PropertyPath  = 'properties.defaultToOAuthAuthentication'
        ExpectedValue = $true
        PassMessage   = "Storage account '{0}' defaults to Microsoft Entra ID authorization."
        FailMessage   = "Storage account '{0}' does not default to Microsoft Entra ID authorization. Enable 'Default to Microsoft Entra authorization in the Azure portal' to enforce identity-based access."
    }
    Test-StorageAccountProperty @params
}
