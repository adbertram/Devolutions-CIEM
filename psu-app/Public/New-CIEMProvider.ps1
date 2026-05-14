function New-CIEMProvider {
    <#
    .SYNOPSIS
        Creates a new CIEM cloud provider.

    .DESCRIPTION
        Adds a new provider to the CIEM SQLite database. Validates name
        uniqueness and applies sensible defaults. Authentication is managed
        separately with generic authentication profile assignments.

    .PARAMETER Name
        Provider name (e.g., 'Azure', 'AWS', 'GCP'). Must be unique.

    .PARAMETER Enabled
        Whether the provider is enabled. Defaults to $true.

    .PARAMETER Endpoints
        Optional PSCustomObject with provider-specific API endpoints.

    .PARAMETER ResourceFilter
        Optional array of subscription IDs or account IDs to filter.

    .OUTPUTS
        [CIEMProvider] The new provider object with computed CheckCount.

    .EXAMPLE
        New-CIEMProvider -Name 'GCP'

    .EXAMPLE
        New-CIEMProvider -Name 'Azure' -Enabled $true
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a configuration object in database, not a system resource')]
    [OutputType('CIEMProvider')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [bool]$Enabled = $true,

        [Parameter()]
        [PSCustomObject]$Endpoints,

        [Parameter()]
        [string[]]$ResourceFilter
    )

    $ErrorActionPreference = 'Stop'

    $providerId = $Name.ToLower()
    $providerType = $Name
    $now = (Get-Date).ToString('o')

    # Validate name uniqueness
    $existing = Invoke-CIEMQuery -Query "SELECT id FROM providers WHERE id = @id" -Parameters @{ id = $providerId }
    if ($existing) {
        throw "Provider '$Name' already exists. Use Update-CIEMProvider to modify it."
    }

    # Insert provider
    Invoke-CIEMQuery -Query @"
INSERT INTO providers (id, name, type, enabled, created_at, updated_at)
VALUES (@id, @name, @type, @enabled, @now, @now)
"@ -Parameters @{
        id      = $providerId
        name    = $Name
        type    = $providerType
        enabled = if ($Enabled) { 1 } else { 0 }
        now     = $now
    } -AsNonQuery | Out-Null

    # Return the newly created provider
    Get-CIEMProvider -Name $Name
}
