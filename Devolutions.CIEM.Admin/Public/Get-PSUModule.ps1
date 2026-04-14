function Get-PSUModule {
    <#
    .SYNOPSIS
        Gets modules installed in PowerShell Universal.

    .DESCRIPTION
        Retrieves a list of all modules installed in the PSU instance,
        or a specific module by name.

    .PARAMETER Name
        Optional module name to filter by. Supports wildcards.

    .EXAMPLE
        Get-PSUModule
        # Lists all installed modules

    .EXAMPLE
        Get-PSUModule -Name "Devolutions.CIEM"
        # Gets a specific module
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    Assert-PSUConnection

    $headers = @{
        'Authorization'              = "Bearer $($script:PSUConnection.Token)"
        'Accept'                     = 'application/json'
        # ngrok free tunnels return a browser-warning HTML interstitial unless
        # this header is set, which silently breaks Invoke-RestMethod parsing.
        'ngrok-skip-browser-warning' = 'true'
    }

    $uri = "$($script:PSUConnection.Url)/api/v1/module"

    try {
        $modules = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
    }
    catch {
        throw "Failed to get modules: $_"
    }

    if ($Name) {
        $modules = $modules | Where-Object { $_.name -like $Name }
    }

    $modules
}
