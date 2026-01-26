function Get-CIEMProvider {
    <#
    .SYNOPSIS
        Lists available CIEM cloud providers.

    .DESCRIPTION
        Returns information about cloud providers supported by the CIEM module.
        Currently supports Azure only (V1).

    .OUTPUTS
        [PSCustomObject[]] Array of provider objects with properties:
        - Name: Provider name
        - Description: Provider description
        - CheckCount: Number of checks for this provider
        - Services: Array of service names

    .EXAMPLE
        Get-CIEMProvider
        # Returns Azure provider information

    .EXAMPLE
        (Get-CIEMProvider).Services
        # Returns array: Entra, IAM, KeyVault, Storage
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $ErrorActionPreference = 'Stop'

    # Get actual check count from metadata
    $checksPath = Join-Path $PSScriptRoot '../AzureChecks.json'
    $checkCount = 46  # Default

    if (Test-Path $checksPath) {
        $metadata = Get-Content $checksPath -Raw | ConvertFrom-Json
        $checks = $metadata
        if ($metadata.PSObject.Properties.Name -contains 'checks') {
            $checks = $metadata.checks
        }
        $checkCount = @($checks).Count
    }

    [PSCustomObject]@{
        Name = 'Azure'
        Description = 'Microsoft Azure identity and access management checks'
        CheckCount = $checkCount
        Services = @('Entra', 'IAM', 'KeyVault', 'Storage')
    }
}
