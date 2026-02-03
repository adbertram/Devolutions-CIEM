function Get-CIEMConfig {
    <#
    .SYNOPSIS
        Loads the CIEM configuration from PSU cache.

    .DESCRIPTION
        Retrieves configuration from the PSU persistent cache (key: CIEM:Config).
        If the cache is empty (first run), initializes it with default values.
        Returns the configuration as a PSCustomObject.

        When running outside of PSU context (e.g., local development), returns
        in-memory defaults.

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

    $config = $null

    # Check if PSU cache cmdlets are available and connected
    $psuCacheAvailable = Get-Command -Name 'Get-PSUCache' -ErrorAction SilentlyContinue

    if ($psuCacheAvailable) {
        try {
            $config = Get-PSUCache -Key 'CIEM:Config' -ErrorAction Stop

            if (-not $config) {
                # First run - initialize with defaults
                $config = Get-CIEMDefaultConfig
                Set-PSUCache -Key 'CIEM:Config' -Value $config -Persist -ErrorAction Stop
                Write-Verbose "Initialized CIEM:Config in PSU cache with defaults"
            }
        }
        catch {
            # PSU cache command exists but we're not connected (e.g., local dev)
            Write-Verbose "PSU cache not accessible: $($_.Exception.Message)"
            $config = $null
        }
    }

    # Fallback to in-memory defaults if PSU cache not available or failed
    if (-not $config) {
        Write-Verbose "Using in-memory defaults"
        $config = Get-CIEMDefaultConfig
    }

    [PSCustomObject]$config
}
