function Get-CIEMConfig {
    <#
    .SYNOPSIS
        Loads the CIEM configuration from config.json.

    .DESCRIPTION
        Reads and parses the config.json file from the module root directory.
        Returns a hashtable containing all configuration values that can be
        accessed via $script:Config in other module functions.

    .PARAMETER ConfigPath
        Optional path to a custom config.json file. If not specified,
        uses the default config.json in the module root.

    .OUTPUTS
        [PSCustomObject] Configuration values including Azure settings, scan options,
        output settings, and PAM remediation URLs.

    .EXAMPLE
        $config = Get-CIEMConfig
        $config.azure.endpoints.graphApi  # Returns 'https://graph.microsoft.com/v1.0'

    .EXAMPLE
        $config = Get-CIEMConfig -ConfigPath '/custom/path/config.json'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$ConfigPath = (Join-Path $script:ModuleRoot 'config.json')
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found: $ConfigPath"
    }

    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

    # Validate required structure
    foreach ($section in @('azure', 'scan', 'pam')) {
        if (-not $config.PSObject.Properties[$section]) {
            throw "Invalid config: missing '$section' section"
        }
    }

    $config
}
