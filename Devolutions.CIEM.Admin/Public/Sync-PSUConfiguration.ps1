function Sync-PSUConfiguration {
    <#
    .SYNOPSIS
        Synchronizes PSU configuration and clears in-memory caches.

    .DESCRIPTION
        Calls the PSU configuration sync API to reload configuration files
        and clear in-memory caches. Use -Reset for a complete reset similar
        to restarting the service.

    .PARAMETER Reset
        Perform a complete reset, similar to restarting the PSU service.

    .EXAMPLE
        Sync-PSUConfiguration

    .EXAMPLE
        Sync-PSUConfiguration -Reset
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Reset
    )

    $ErrorActionPreference = 'Stop'

    AssertPSUConnection

    $headers = @{
        'Authorization'              = "Bearer $($script:PSUConnection.Token)"
        'Accept'                     = 'application/json'
        # ngrok free tunnels return a browser-warning HTML interstitial unless
        # this header is set, which silently breaks Invoke-RestMethod parsing.
        'ngrok-skip-browser-warning' = 'true'
    }

    $uri = "$($script:PSUConnection.Url)/api/v1/configuration"
    if ($Reset) {
        $uri += "?reset=true"
    }

    Write-Verbose "Syncing PSU configuration (Reset: $Reset)..."

    try {
        Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -ErrorAction Stop
        Write-Verbose "Configuration sync completed."

        [PSCustomObject]@{
            Status = 'Synced'
            Reset  = $Reset.IsPresent
        }
    }
    catch {
        throw "Failed to sync configuration: $_"
    }
}
