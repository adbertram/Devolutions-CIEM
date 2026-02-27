function New-CIEMProvider {
    <#
    .SYNOPSIS
        Creates a new CIEM cloud provider.

    .DESCRIPTION
        Adds a new provider to the CIEM SQLite database. Validates name
        uniqueness and applies sensible defaults. If a provider type is
        registered via Register-CIEMProviderType, its WriteAuth callback
        persists provider-specific auth data.

    .PARAMETER Name
        Provider name (e.g., 'Azure', 'AWS', 'GCP'). Must be unique.

    .PARAMETER Enabled
        Whether the provider is enabled. Defaults to $true.

    .PARAMETER IsDefault
        Set this provider as the default. Clears IsDefault on all others.

    .PARAMETER Authentication
        Optional PSCustomObject with authentication settings. If not specified,
        creates a default auth context from the registered provider type or a
        generic one for unregistered types.

    .PARAMETER Endpoints
        Optional PSCustomObject with provider-specific API endpoints.

    .PARAMETER ResourceFilter
        Optional array of subscription IDs or account IDs to filter.

    .OUTPUTS
        [CIEMProvider] The new provider object with computed CheckCount.

    .EXAMPLE
        New-CIEMProvider -Name 'GCP'

    .EXAMPLE
        New-CIEMProvider -Name 'Azure' -Enabled $true -IsDefault
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a configuration object in database, not a system resource')]
    [OutputType([CIEMProvider])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [bool]$Enabled = $true,

        [Parameter()]
        [switch]$IsDefault,

        [Parameter()]
        [PSCustomObject]$Authentication,

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

    # Resolve authentication context
    if (-not $Authentication) {
        $reg = $script:ProviderTypes[$providerType]
        if ($reg) {
            $Authentication = [PSCustomObject]@{
                Provider = $Name
                Enabled  = $Enabled
                Method   = ''
            }
        }
        else {
            $Authentication = [PSCustomObject]@{
                Provider = $Name
                Enabled  = $Enabled
                Method   = ''
            }
        }
    }

    # Check if this should be default (first provider or explicit)
    $existingCount = Invoke-CIEMQuery -Query "SELECT COUNT(*) AS cnt FROM providers" | Select-Object -ExpandProperty cnt
    $makeDefault = $IsDefault.IsPresent -or $existingCount -eq 0

    # Use transaction for atomicity
    $conn = Open-PSUSQLiteConnection -Database $script:DatabasePath
    try {
        $tx = $conn.BeginTransaction()

        # Clear IsDefault on others if this will be default
        if ($makeDefault) {
            Invoke-PSUSQLiteQuery -Connection $conn -Query "UPDATE providers SET is_default = 0 WHERE is_default = 1" -AsNonQuery | Out-Null
        }

        # Insert provider
        Invoke-PSUSQLiteQuery -Connection $conn -Query @"
INSERT INTO providers (id, name, type, enabled, is_default, created_at, updated_at)
VALUES (@id, @name, @type, @enabled, @is_default, @now, @now)
"@ -Parameters @{
            id         = $providerId
            name       = $Name
            type       = $providerType
            enabled    = if ($Enabled) { 1 } else { 0 }
            is_default = if ($makeDefault) { 1 } else { 0 }
            now        = $now
        } -AsNonQuery | Out-Null

        # Dispatch to registered provider type for auth persistence
        $reg = $script:ProviderTypes[$providerType]
        if ($reg -and $reg.WriteAuth) {
            & $reg.WriteAuth $conn $providerId $Authentication $now
        }

        $tx.Commit()
    }
    catch {
        if ($tx) { $tx.Rollback() }
        throw
    }
    finally {
        $conn.Dispose()
    }

    # Return the newly created provider
    Get-CIEMProvider -Name $Name
}
