function Reset-CIEMConfig {
    <#
    .SYNOPSIS
        Resets the CIEM configuration to default values.

    .DESCRIPTION
        Overwrites the PSU cache configuration with default values and
        updates the $script:Config variable. Use this to restore factory
        defaults after configuration changes.

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

    $ErrorActionPreference = 'Stop'

    if ($PSCmdlet.ShouldProcess($script:CIEMConfigCacheKey, 'Reset configuration to defaults')) {
        $defaults = Get-CIEMDefaultConfig

        $setCacheCommand = Get-Command -Name 'Set-PSUCache' -ErrorAction Stop
        if (-not $setCacheCommand) {
            throw "Set-PSUCache is required to reset CIEM configuration."
        }

        Set-PSUCache -Key $script:CIEMConfigCacheKey -Value $defaults -Persist -Integrated -ErrorAction Stop
        Write-Verbose "Configuration reset to defaults in PSU cache"

        # Update in-memory config
        $script:Config = [PSCustomObject]$defaults

        Write-Verbose "Configuration reset to defaults"
    }
}
