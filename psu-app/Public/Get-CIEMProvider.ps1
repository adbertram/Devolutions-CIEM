function Get-CIEMProvider {
    <#
    .SYNOPSIS
        Lists available CIEM cloud providers.

    .DESCRIPTION
        Returns provider objects from the CIEM SQLite database. Each provider
        includes Name, Enabled, IsDefault, Authentication, Endpoints, ResourceFilter,
        and a computed CheckCount property.

        Authentication details are reconstructed by dispatching to registered
        provider type callbacks. Unregistered types get a generic auth object.

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
    [OutputType([CIEMProvider[]])]
    param(
        [Parameter()]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    # Build SQL dynamically from registered provider types
    $selectColumns = [System.Collections.Generic.List[string]]::new()
    $selectColumns.Add('p.id, p.name, p.type, p.enabled, p.is_default, p.created_at, p.updated_at')

    $joinClauses = [System.Collections.Generic.List[string]]::new()

    foreach ($typeName in $script:ProviderTypes.Keys) {
        $reg = $script:ProviderTypes[$typeName]
        if ($reg.QueryAuth) {
            $queryAuth = & $reg.QueryAuth
            if ($queryAuth.Columns) {
                $selectColumns.Add($queryAuth.Columns)
            }
            if ($queryAuth.JoinClause) {
                $joinClauses.Add($queryAuth.JoinClause)
            }
        }
    }

    $query = "SELECT $($selectColumns -join ",`n       ")`nFROM providers p"
    if ($joinClauses.Count -gt 0) {
        $query += "`n" + ($joinClauses -join "`n")
    }

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

        # Reconstruct authentication via registered provider type callback
        $reg = $script:ProviderTypes[$row.type]
        if ($reg -and $reg.ReadAuth) {
            $provider.Authentication = & $reg.ReadAuth $row $false
        }
        else {
            # Unregistered type: generic auth
            $provider.Authentication = [PSCustomObject]@{
                Provider = $row.type
                Enabled  = [bool]$row.enabled
                Method   = ''
            }
        }

        # Endpoints from registered defaults or empty
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
