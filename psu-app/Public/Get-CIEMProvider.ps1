function Get-CIEMProvider {
    <#
    .SYNOPSIS
        Lists available CIEM cloud providers.

    .DESCRIPTION
        Returns provider objects from the CIEM SQLite database. Each provider
        includes Name, Enabled, IsDefault, Endpoints, ResourceFilter,
        and a computed CheckCount property.

    .PARAMETER Name
        Optional. Return a single provider by name (case-insensitive).

    .OUTPUTS
        [CIEMProvider[]] Array of provider objects.

    .EXAMPLE
        Get-CIEMProvider
        # Returns all providers

    .EXAMPLE
        Get-CIEMProvider -Name Azure
        # Returns a specific provider by name

    .EXAMPLE
        Get-CIEMProvider | Where-Object Enabled
        # Returns only enabled providers
    #>
    [CmdletBinding()]
    [OutputType('CIEMProvider[]')]
    param(
        [Parameter()]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    $query = "SELECT p.id, p.name, p.type, p.enabled, p.is_default, p.created_at, p.updated_at FROM providers p"

    if ($Name) {
        $query += "`nWHERE p.name = @name COLLATE NOCASE"
    }

    $params = @{}
    if ($Name) { $params.name = $Name }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)

    # Convert rows to CIEMProvider objects
    $providers = @(foreach ($row in $rows) {
        $provider = [CIEMProvider]::new()
        $provider.Name = $row.name
        $provider.Enabled = [bool]$row.enabled
        $provider.IsDefault = [bool]$row.is_default
        $provider.Authentication = $null

        # Endpoints from registered defaults or empty
        $reg = $script:ProviderTypes[$row.type]
        if ($reg -and $reg.DefaultEndpoints) {
            $provider.Endpoints = $reg.DefaultEndpoints
        }
        else {
            $provider.Endpoints = [PSCustomObject]@{}
        }

        $provider.ResourceFilter = @()

        $provider
    })

    # Add computed CheckCount to each provider
    foreach ($p in $providers) {
        $checksDir = $null
        $checksModule = Get-Module -Name 'Devolutions.CIEM.Checks' -ErrorAction SilentlyContinue
        if ($checksModule) {
            $checksDir = Join-Path $checksModule.ModuleBase "Checks/$($p.Name)"
        }
        if (-not $checksDir -or -not (Test-Path $checksDir)) {
            # Fall back to sibling Checks module directory (dev layout)
            $projectRoot = Split-Path $script:ModuleRoot -Parent
            $checksDir = Join-Path $projectRoot "Devolutions.CIEM.Checks/Checks/$($p.Name)"
        }
        $checkCount = if (Test-Path $checksDir) { @(Get-ChildItem -Path "$checksDir/*.ps1").Count } else { 0 }
        $p | Add-Member -NotePropertyName 'CheckCount' -NotePropertyValue $checkCount -Force
    }

    $providers
}
