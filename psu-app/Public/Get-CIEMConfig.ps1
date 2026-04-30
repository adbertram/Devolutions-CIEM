function Get-CIEMConfig {
    <#
    .SYNOPSIS
        Loads the CIEM configuration from PSU cache.

    .DESCRIPTION
        Retrieves configuration from the PSU persistent cache (key: CIEM:Config).
        If the cache is empty (first run), initializes it with default values.
        Returns the configuration as a PSCustomObject.

    .OUTPUTS
        [PSCustomObject] Configuration values including Azure settings, scan options,
        output settings, and PAM remediation URLs.

    .EXAMPLE
        $config = Get-CIEMConfig
        $config.azure.endpoints.graphApi  # Returns 'https://graph.microsoft.com/v1.0'

    .EXAMPLE
        # Force refresh from cache
        $script:Config = $null
        $config = Get-CIEMConfig
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $ErrorActionPreference = 'Stop'

    $getCacheCommand = Get-Command -Name 'Get-PSUCache' -ErrorAction Stop
    if (-not $getCacheCommand) {
        throw "Get-PSUCache is required to read CIEM configuration."
    }

    # PSU context — read from cache (throws on infrastructure failure)
    $config = ReadPSUCache -Key $script:CIEMConfigCacheKey

    if (-not $config) {
        # First run — initialize cache with defaults
        $config = Get-CIEMDefaultConfig
        Set-PSUCache -Key $script:CIEMConfigCacheKey -Value $config -Persist -Integrated -ErrorAction Stop
        Write-Verbose "Initialized CIEM:Config in PSU cache with defaults"
    }
    else {
        # Backfill any missing top-level keys from defaults (handles config schema upgrades)
        $defaults = Get-CIEMDefaultConfig
        $needsUpdate = $false
        foreach ($prop in $defaults.PSObject.Properties) {
            if (-not $config.PSObject.Properties[$prop.Name]) {
                $config | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value
                $needsUpdate = $true
                Write-Verbose "Backfilled missing config key: $($prop.Name)"
            }
        }
        if ($needsUpdate) {
            Set-PSUCache -Key $script:CIEMConfigCacheKey -Value $config -Persist -Integrated -ErrorAction Stop
            Write-Verbose "Updated CIEM:Config in PSU cache with backfilled keys"
        }
    }

    [PSCustomObject]$config
}
