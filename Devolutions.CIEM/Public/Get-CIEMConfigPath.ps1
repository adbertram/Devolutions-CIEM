function Get-CIEMConfigPath {
    <#
    .SYNOPSIS
        Gets the path to the CIEM config.json file.

    .DESCRIPTION
        Finds the config.json path by checking:
        1. The loaded Devolutions.CIEM module's ModuleBase
        2. The script-scoped $script:ModuleRoot variable

        This is used by PSU dashboard pages at runtime to locate configuration.

    .OUTPUTS
        [string] Path to config.json if found, $null otherwise.

    .EXAMPLE
        $ConfigPath = Get-CIEMConfigPath
        if ($ConfigPath) {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        }
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $configPath = $null

    # First, try to get path from loaded module
    $module = Get-Module -Name 'Devolutions.CIEM' -ErrorAction SilentlyContinue
    if ($module) {
        $modulePath = Join-Path $module.ModuleBase 'config.json'
        if (Test-Path $modulePath) {
            $configPath = $modulePath
        }
    }

    # Fallback to script-scoped ModuleRoot
    if (-not $configPath -and $script:ModuleRoot) {
        $rootPath = Join-Path $script:ModuleRoot 'config.json'
        if (Test-Path $rootPath) {
            $configPath = $rootPath
        }
    }

    $configPath
}
