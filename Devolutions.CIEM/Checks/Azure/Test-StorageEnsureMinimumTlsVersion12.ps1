function Test-StorageEnsureMinimumTlsVersion12 {
    <#
    .SYNOPSIS
        Tests if the minimum TLS version is set to 1.2.

    .DESCRIPTION
        Ensures the 'Minimum TLS version' for storage accounts is set to 'Version 1.2'
        to protect against known vulnerabilities in older TLS versions.

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
        PropertyPath  = 'properties.minimumTlsVersion'
        ExpectedValue = 'TLS1_2'
        PassMessage   = "Storage account '{0}' has minimum TLS version set to TLS 1.2."
        FailMessage   = "Storage account '{0}' has minimum TLS version set to '{1}'. Set minimum TLS version to TLS1_2."
        DefaultValue  = 'not set (defaults to older version)'
    }
    Test-StorageAccountProperty @params
}
