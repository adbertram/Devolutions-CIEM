function Set-CIEMConfig {
    <#
    .SYNOPSIS
        Updates the CIEM configuration in config.json.

    .DESCRIPTION
        Accepts a hashtable of settings to update, reads the existing config.json,
        merges user-provided settings, writes back to config.json, and reloads
        the $script:Config variable.

        Dev-only fields (prowler.*, checksPath, azure.endpoints.*) are preserved
        and not exposed through this function.

    .PARAMETER Settings
        A hashtable containing the settings to update. Supports nested paths using
        dot notation in the hashtable keys.

    .PARAMETER ConfigPath
        Optional path to a custom config.json file. If not specified,
        uses the default config.json in the module root.

    .EXAMPLE
        Set-CIEMConfig -Settings @{
            'azure.authentication.method' = 'ServicePrincipal'
            'azure.authentication.servicePrincipal.tenantId' = '12345-6789'
            'scan.throttleLimit' = 20
        }

    .EXAMPLE
        # Reset to defaults
        $defaults = @{
            'azure.authentication.method' = 'ServicePrincipalSecret'
            'azure.subscriptionFilter' = @()
            'scan.throttleLimit' = 10
            'scan.timeoutSeconds' = 300
            'scan.continueOnError' = $true
            'output.verboseLogging' = $false
            'pam.remediationUrl' = 'https://devolutions.net/pam'
        }
        Set-CIEMConfig -Settings $defaults
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Settings,

        [Parameter()]
        [string]$ConfigPath = (Join-Path $script:ModuleRoot 'config.json')
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    # Read existing config to preserve dev-only fields
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable

    # Helper function to set nested hashtable values using dot notation
    function Set-NestedValue {
        param(
            [hashtable]$Hashtable,
            [string]$Path,
            $Value
        )

        $parts = $Path -split '\.'
        $current = $Hashtable

        for ($i = 0; $i -lt $parts.Count - 1; $i++) {
            $part = $parts[$i]
            if (-not $current.ContainsKey($part)) {
                $current[$part] = @{}
            } elseif ($current[$part] -isnot [hashtable]) {
                # Convert PSCustomObject to hashtable if needed
                $current[$part] = @{}
            }
            $current = $current[$part]
        }

        $finalKey = $parts[-1]
        $current[$finalKey] = $Value
    }

    # Apply each setting from the provided hashtable
    foreach ($key in $Settings.Keys) {
        $value = $Settings[$key]

        # Skip dev-only fields if someone tries to set them
        if ($key -match '^prowler\.' -or $key -eq 'checksPath' -or $key -match '^azure\.endpoints\.') {
            Write-Warning "Skipping dev-only setting: $key"
            continue
        }

        Set-NestedValue -Hashtable $config -Path $key -Value $value
    }

    if ($PSCmdlet.ShouldProcess($ConfigPath, 'Update configuration')) {
        # Write the updated config back to file
        $jsonContent = $config | ConvertTo-Json -Depth 10
        Set-Content -Path $ConfigPath -Value $jsonContent -Encoding UTF8

        # Reload $script:Config
        $script:Config = Get-CIEMConfig -ConfigPath $ConfigPath

        Write-Verbose "Configuration updated successfully"
    }
}
