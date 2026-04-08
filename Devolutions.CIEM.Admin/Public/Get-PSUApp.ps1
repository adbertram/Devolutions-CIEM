function Get-PSUApp {
    <#
    .SYNOPSIS
        Gets apps (dashboards) from PowerShell Universal.

    .DESCRIPTION
        Retrieves a list of all apps in the PSU instance, or a specific app by name.

    .PARAMETER Name
        Optional app name to filter by. Supports wildcards.

    .PARAMETER Id
        Optional app ID to retrieve directly.

    .EXAMPLE
        Get-PSUApp

    .EXAMPLE
        Get-PSUApp -Name "CIEM"
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById')]
        [int]$Id
    )

    Assert-PSUConnection

    $headers = @{
        'Authorization'              = "Bearer $($script:PSUConnection.Token)"
        'Accept'                     = 'application/json'
        # ngrok free tunnels return a browser-warning HTML interstitial for
        # GET requests unless this header is set, which silently breaks
        # Invoke-RestMethod JSON parsing.
        'ngrok-skip-browser-warning' = 'true'
    }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $uri = "$($script:PSUConnection.Url)/api/v1/dashboard/$Id"
        try {
            Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        }
        catch {
            throw "Failed to get app with ID $Id. Error: $_"
        }
    }
    else {
        $uri = "$($script:PSUConnection.Url)/api/v1/dashboard"
        try {
            $apps = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        }
        catch {
            throw "Failed to get apps. Error: $_"
        }

        if ($Name) {
            $apps = $apps | Where-Object { $_.name -like $Name }
        }

        $apps
    }
}
