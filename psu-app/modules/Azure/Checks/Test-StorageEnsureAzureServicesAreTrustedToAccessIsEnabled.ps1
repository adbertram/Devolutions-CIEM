function Test-StorageEnsureAzureServicesAreTrustedToAccessIsEnabled {
    <#
    .SYNOPSIS
        Storage account has 'Allow trusted Microsoft services to access this storage account' enabled

    .DESCRIPTION
        **Azure Storage account** network rules include the `AzureServices` bypass so **trusted Microsoft services** can reach the account even when firewalls restrict public access

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: storage_ensure_azure_services_are_trusted_to_access_is_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check storage_ensure_azure_services_are_trusted_to_access_is_enabled for reference.', 'N/A', 'storage Resources')
}
