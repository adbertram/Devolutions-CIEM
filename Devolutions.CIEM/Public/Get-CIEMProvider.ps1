function Get-CIEMProvider {
    <#
    .SYNOPSIS
        Lists available CIEM cloud providers.

    .DESCRIPTION
        Returns information about cloud providers based on known providers
        (azure, aws) with configuration from the CIEM config. Each provider
        object includes computed properties and all config properties.

    .OUTPUTS
        [PSCustomObject[]] Array of provider objects with:
        - Name: Provider name (title case)
        - Enabled: Whether the provider is enabled in config (defaults to false)
        - IsDefault: Whether this is the default provider
        - CheckCount: Number of checks for this provider
        - Plus all properties from the provider's config section

    .EXAMPLE
        Get-CIEMProvider
        # Returns all known providers

    .EXAMPLE
        Get-CIEMProvider | Where-Object Enabled
        # Returns only enabled providers
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $ErrorActionPreference = 'Stop'

    # Get provider names from config - any top-level key with an 'enabled' property is a provider
    $nonProviderKeys = @('cloudProvider', 'scan', 'output', 'pam')
    $providerNames = $script:Config.PSObject.Properties.Name | Where-Object { $_ -notin $nonProviderKeys }

    foreach ($providerName in $providerNames) {
        $providerConfig = $script:Config.$providerName
        $displayName = (Get-Culture).TextInfo.ToTitleCase($providerName)

        $checksPath = Join-Path -Path $script:ModuleRoot -ChildPath "Checks/$displayName"
        $checkCount = if (Test-Path $checksPath) { @(Get-ChildItem -Path "$checksPath/*.ps1").Count } else { 0 }

        # Start with computed properties (Enabled defaults to false if not in config)
        $obj = [ordered]@{
            Name       = $displayName
            Enabled    = $false
            IsDefault  = ($script:Config.cloudProvider -eq $displayName)
            CheckCount = $checkCount
        }

        # Add all properties from config (this will override Enabled if it exists)
        if ($providerConfig) {
            foreach ($prop in $providerConfig.PSObject.Properties) {
                $obj[$prop.Name] = $prop.Value
            }
        }

        [PSCustomObject]$obj
    }
}
