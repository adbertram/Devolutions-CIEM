function Get-CIEMProvider {
    <#
    .SYNOPSIS
        Lists available CIEM cloud providers.

    .DESCRIPTION
        Returns provider objects from the CIEM:Providers PSU cache. Each provider
        includes Name, Enabled, IsDefault, Authentication, Endpoints, ResourceFilter,
        and a computed CheckCount property.

        On first run (empty cache), returns built-in Azure and AWS defaults.

    .PARAMETER Name
        Optional. Return a single provider by name (case-insensitive).

    .OUTPUTS
        [CIEMProvider[]] Array of provider objects.

    .EXAMPLE
        Get-CIEMProvider
        # Returns all providers

    .EXAMPLE
        Get-CIEMProvider -Name Azure
        # Returns the Azure provider

    .EXAMPLE
        Get-CIEMProvider | Where-Object Enabled
        # Returns only enabled providers
    #>
    [CmdletBinding()]
    [OutputType([CIEMProvider[]])]
    param(
        [Parameter()]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    # Try to read from PSU cache
    $rawProviders = $null
    try {
        $rawProviders = @(Get-PSUCache -Key 'CIEM:Providers' -ErrorAction SilentlyContinue)
    }
    catch {
        # Not in PSU context or cache unavailable
    }

    # Fall back to built-in defaults if cache is empty
    if (-not $rawProviders -or $rawProviders.Count -eq 0 -or ($rawProviders.Count -eq 1 -and $null -eq $rawProviders[0])) {
        $azureAuth = [CIEMAzureSPAuthenticationContext]::new()
        $azureAuth.Enabled = $true

        $azure = [CIEMProvider]::new('Azure')
        $azure.Enabled = $true
        $azure.IsDefault = $true
        $azure.Authentication = $azureAuth
        $azure.Endpoints = [PSCustomObject]@{
            graphApi = 'https://graph.microsoft.com/v1.0'
            armApi   = 'https://management.azure.com'
        }

        $awsAuth = [CIEMAWSCurrentProfileAuthenticationContext]::new()

        $aws = [CIEMProvider]::new('AWS')
        $aws.Authentication = $awsAuth
        $aws.Endpoints = [PSCustomObject]@{}

        $providers = @($azure, $aws)
    }
    else {
        # Convert deserialized PSCustomObjects to typed CIEMProvider instances
        $providers = @($rawProviders | ConvertTo-CIEMProvider)
    }

    # Add computed CheckCount to each provider
    foreach ($p in $providers) {
        $checksPath = Join-Path -Path $script:ModuleRoot -ChildPath "Checks/$($p.Name)"
        $checkCount = if (Test-Path $checksPath) { @(Get-ChildItem -Path "$checksPath/*.ps1").Count } else { 0 }
        $p | Add-Member -NotePropertyName 'CheckCount' -NotePropertyValue $checkCount -Force
    }

    # Filter by name if specified
    if ($Name) {
        $providers = @($providers | Where-Object { $_.Name -eq $Name })
    }

    $providers
}
