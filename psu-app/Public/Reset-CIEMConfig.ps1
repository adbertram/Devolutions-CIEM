function Reset-CIEMConfig {
    <#
    .SYNOPSIS
        Resets the CIEM configuration to default values.

    .DESCRIPTION
        Overwrites the PSU cache configuration with default values and
        updates the $script:Config variable. Use this to restore factory
        defaults after configuration changes.

        When running outside of PSU context, resets only the in-memory config.

    .EXAMPLE
        Reset-CIEMConfig
        # Configuration is now reset to defaults

    .EXAMPLE
        # Verify reset worked
        Reset-CIEMConfig
        (Get-CIEMConfig).scan.throttleLimit  # Returns 10 (default)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'SupportsShouldProcess is declared')]
    param()

    if ($PSCmdlet.ShouldProcess('CIEM:Config', 'Reset configuration to defaults')) {
        $defaults = Get-CIEMDefaultConfig

        # Check if PSU cache cmdlets are available
        $psuCacheAvailable = Get-Command -Name 'Set-PSUCache' -ErrorAction SilentlyContinue
        $psuCacheConnected = $false

        if ($psuCacheAvailable) {
            try {
                Set-PSUCache -Key 'CIEM:Config' -Value $defaults -Persist -Integrated -ErrorAction Stop
                $psuCacheConnected = $true
                Write-Verbose "Configuration reset to defaults in PSU cache"
            }
            catch {
                Write-Verbose "PSU cache not accessible: $($_.Exception.Message)"
            }
        }

        if (-not $psuCacheConnected) {
            Write-Warning "PSU cache not available. Configuration reset only applies to in-memory config."
        }

        # Update in-memory config
        $script:Config = [PSCustomObject]$defaults

        Write-Verbose "Configuration reset to defaults"
    }
}
