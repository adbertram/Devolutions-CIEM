function Update-CIEMProvider {
    <#
    .SYNOPSIS
        Updates an existing CIEM cloud provider.

    .DESCRIPTION
        Modifies properties of a provider in the CIEM SQLite database.
        Only specified parameters are updated; unspecified ones are preserved.

        Provider-specific auth persistence is dispatched to the registered
        provider type's WriteAuth callback. When called with a [bool], the
        callback syncs the enabled flag. When called with a PSCustomObject,
        the callback performs a full auth UPSERT.

    .PARAMETER Name
        Provider name to update (case-insensitive).

    .PARAMETER Enabled
        Whether the provider is enabled.

    .PARAMETER IsDefault
        Set this provider as the default. Clears IsDefault on all others.

    .PARAMETER Authentication
        New authentication settings as a PSCustomObject.

    .PARAMETER Endpoints
        New PSCustomObject with provider-specific API endpoints.

    .PARAMETER ResourceFilter
        New array of subscription IDs or account IDs.

    .PARAMETER PassThru
        Returns the updated provider object. By default, this function produces no output.

    .OUTPUTS
        [CIEMProvider] When -PassThru is specified, the updated provider object with computed CheckCount.

    .EXAMPLE
        Update-CIEMProvider -Name 'GCP' -Enabled $true

    .EXAMPLE
        Update-CIEMProvider -Name 'Azure' -IsDefault
    #>
    [CmdletBinding()]
    [OutputType([CIEMProvider])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [bool]$Enabled,

        [Parameter()]
        [switch]$IsDefault,

        [Parameter()]
        [object]$Authentication,

        [Parameter()]
        [PSCustomObject]$Endpoints,

        [Parameter()]
        [string[]]$ResourceFilter,

        [Parameter()]
        [switch]$PassThru
    )

    $ErrorActionPreference = 'Stop'

    $providerId = $Name.ToLower()
    $now = (Get-Date).ToString('o')

    # Verify provider exists
    $existing = Invoke-CIEMQuery -Query "SELECT id, type FROM providers WHERE id = @id" -Parameters @{ id = $providerId }
    if (-not $existing) {
        throw "Provider '$Name' not found. Use New-CIEMProvider to create it."
    }

    $providerType = $existing.type

    $conn = Open-PSUSQLiteConnection -Database $script:DatabasePath
    try {
        $tx = $conn.BeginTransaction()

        # Update enabled flag
        if ($PSBoundParameters.ContainsKey('Enabled')) {
            Invoke-PSUSQLiteQuery -Connection $conn -Query "UPDATE providers SET enabled = @enabled, updated_at = @now WHERE id = @id" -Parameters @{
                id = $providerId; enabled = if ($Enabled) { 1 } else { 0 }; now = $now
            } -AsNonQuery | Out-Null

            # Dispatch enabled sync to registered provider type
            $reg = $script:ProviderTypes[$providerType]
            if ($reg -and $reg.WriteAuth) {
                & $reg.WriteAuth $conn $providerId ([bool]$Enabled) $now
            }
        }

        # Update IsDefault
        if ($IsDefault.IsPresent) {
            Invoke-PSUSQLiteQuery -Connection $conn -Query "UPDATE providers SET is_default = 0 WHERE is_default = 1" -AsNonQuery | Out-Null
            Invoke-PSUSQLiteQuery -Connection $conn -Query "UPDATE providers SET is_default = 1, updated_at = @now WHERE id = @id" -Parameters @{
                id = $providerId; now = $now
            } -AsNonQuery | Out-Null
        }

        # Update authentication
        if ($PSBoundParameters.ContainsKey('Authentication')) {
            $reg = $script:ProviderTypes[$providerType]
            if ($reg -and $reg.WriteAuth) {
                & $reg.WriteAuth $conn $providerId $Authentication $now
            }
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

    if ($PassThru) {
        Get-CIEMProvider -Name $Name
    }
}
