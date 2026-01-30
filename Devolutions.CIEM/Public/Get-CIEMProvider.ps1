function Get-CIEMProvider {
    <#
    .SYNOPSIS
        Lists available CIEM cloud providers.

    .DESCRIPTION
        Returns information about cloud providers configured in config.json.
        Dynamically reads provider sections and creates objects with all
        properties found in the config plus computed properties.

    .OUTPUTS
        [PSCustomObject[]] Array of provider objects with config properties plus:
        - Name: Provider name (title case)
        - IsDefault: Whether this is the default provider
        - CheckCount: Number of checks for this provider

    .EXAMPLE
        Get-CIEMProvider
        # Returns all configured providers

    .EXAMPLE
        Get-CIEMProvider | Where-Object Enabled
        # Returns only enabled providers
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $ErrorActionPreference = 'Stop'

    $supportedProviders = Get-SupportedProvider

    foreach ($providerName in $supportedProviders) {
        $providerConfig = $script:Config.$providerName
        $displayName = (Get-Culture).TextInfo.ToTitleCase($providerName)

        $checksPath = Join-Path -Path $script:ModuleRoot -ChildPath "Checks/$displayName"
        $checkCount = if (Test-Path $checksPath) { @(Get-ChildItem -Path "$checksPath/*.ps1").Count } else { 0 }

        # Start with computed properties
        $obj = [ordered]@{
            Name       = $displayName
            IsDefault  = ($script:Config.cloudProvider -eq $displayName)
            CheckCount = $checkCount
        }

        # Add all properties from config
        foreach ($prop in $providerConfig.PSObject.Properties) {
            $obj[$prop.Name] = $prop.Value
        }

        [PSCustomObject]$obj
    }
}
