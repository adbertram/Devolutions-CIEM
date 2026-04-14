function Set-CIEMConfig {
    <#
    .SYNOPSIS
        Updates the CIEM configuration in PSU cache.

    .DESCRIPTION
        Accepts a hashtable of settings to update, retrieves the current config
        from PSU cache, merges user-provided settings, writes back to PSU cache,
        and updates the $script:Config variable.

        Supports nested paths using dot notation in the hashtable keys.

        When running outside of PSU context, updates only the in-memory config.

    .PARAMETER Settings
        A hashtable containing the settings to update. Supports nested paths using
        dot notation in the hashtable keys.

    .EXAMPLE
        Set-CIEMConfig -Settings @{
            'azure.authentication.method' = 'ServicePrincipal'
            'azure.authentication.tenantId' = '12345-6789'
            'scan.throttleLimit' = 20
        }

    .EXAMPLE
        # Update a single setting
        Set-CIEMConfig -Settings @{ 'output.verboseLogging' = $true }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings
    )

    begin {
        $ErrorActionPreference = 'Stop'

        # Helper function to set nested property values using dot notation
        # Works with PSCustomObject (from PSU cache) or hashtable
        function Resolve-NestedPropertyPath {
            param(
                $Object,
                [string]$Path,
                $Value
            )

            $ErrorActionPreference = 'Stop'

            $parts = $Path -split '\.'
            $current = $Object

            # Navigate to parent of final property
            for ($i = 0; $i -lt $parts.Count - 1; $i++) {
                $part = $parts[$i]
                $current = $current.$part
            }

            # Set the final property value
            $finalKey = $parts[-1]
            $current.$finalKey = $Value
        }
    }

    process {
        $ErrorActionPreference = 'Stop'

        # Check if PSU cache cmdlets are available
        $psuCacheAvailable = Get-Command -Name 'Get-PSUCache' -ErrorAction SilentlyContinue

        # Get current config
        $config = $null
        if ($psuCacheAvailable) {
            # PSU context — read from cache (throws on infrastructure failure)
            $config = ReadPSUCache -Key $script:CIEMConfigCacheKey
        }

        if (-not $config) {
            $config = Get-CIEMDefaultConfig
        }

        # Apply each setting from the provided hashtable
        foreach ($key in $Settings.Keys) {
            $value = $Settings[$key]
            Resolve-NestedPropertyPath -Object $config -Path $key -Value $value
        }

        if ($PSCmdlet.ShouldProcess($script:CIEMConfigCacheKey, 'Update configuration in PSU cache')) {
            # Write to PSU cache if available (throws on failure)
            if ($psuCacheAvailable) {
                Set-PSUCache -Key $script:CIEMConfigCacheKey -Value $config -Persist -Integrated -ErrorAction Stop
                Write-Verbose "Configuration saved to PSU cache"
            }

            # Update in-memory config
            $script:Config = [PSCustomObject]$config

            Write-Verbose "Configuration updated successfully"
        }
    }
}