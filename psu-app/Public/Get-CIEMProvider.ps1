function Get-CIEMProvider {
    <#
    .SYNOPSIS
        Lists available CIEM cloud providers.

    .DESCRIPTION
        Returns provider objects from the CIEM SQLite database. Each provider
        includes Name, Enabled, Endpoints, ResourceFilter, and a computed
        CheckCount property.

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

    $query = "SELECT p.id, p.name, p.type, p.enabled, p.created_at, p.updated_at FROM providers p"

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
        $provider.Endpoints = [PSCustomObject]@{}
        $provider.ResourceFilter = @()

        $provider
    })

    # Add computed CheckCount to each provider
    foreach ($p in $providers) {
        $checksDir = Join-Path $script:ModuleRoot "modules/$($p.Name)/Checks"
        $checkCount = if (Test-Path $checksDir) { @(Get-ChildItem -Path "$checksDir/*.ps1" -ErrorAction SilentlyContinue).Count } else { 0 }
        $p | Add-Member -NotePropertyName 'CheckCount' -NotePropertyValue $checkCount -Force
    }

    $providers
}
