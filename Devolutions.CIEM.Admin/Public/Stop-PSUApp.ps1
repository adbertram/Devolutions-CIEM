function Stop-PSUApp {
    <#
    .SYNOPSIS
        Stops a PowerShell Universal app.

    .PARAMETER Name
        The name of the app to stop.

    .PARAMETER Id
        The ID of the app to stop.

    .PARAMETER PassThru
        Return the app object after stopping.

    .EXAMPLE
        Stop-PSUApp -Name "CIEM"
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName', Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [int]$Id,

        [Parameter()]
        [switch]$PassThru
    )

    $ErrorActionPreference = 'Stop'

    AssertPSUConnection

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $app = Get-PSUApp -Name $Name | Where-Object { $_.name -eq $Name }
        if (-not $app) { throw "App '$Name' not found." }
        if (@($app).Count -gt 1) { throw "Multiple apps found matching '$Name'. Use -Id to specify." }
        $Id = $app.id
        $appName = $app.name
    }
    else {
        $app = Get-PSUApp -Id $Id
        $appName = $app.name
    }

    $headers = @{
        'Authorization'              = "Bearer $($script:PSUConnection.Token)"
        'Accept'                     = 'application/json'
        # ngrok free tunnels return a browser-warning HTML interstitial unless
        # this header is set, which silently breaks Invoke-RestMethod parsing.
        'ngrok-skip-browser-warning' = 'true'
    }

    $uri = "$($script:PSUConnection.Url)/api/v1/dashboard/$Id/status"

    if ($PSCmdlet.ShouldProcess($appName, "Stop PSU app")) {
        Write-Verbose "Stopping app '$appName' (ID: $Id)..."

        try {
            $null = Invoke-RestMethod -Uri $uri -Headers $headers -Method Delete -ErrorAction Stop
            Write-Verbose "App stopped successfully."
        }
        catch {
            throw "Failed to stop app '$appName'. Error: $_"
        }

        if ($PassThru.IsPresent) {
            Get-PSUApp -Id $Id
        }
        else {
            [PSCustomObject]@{
                Id     = $Id
                Name   = $appName
                Status = 'Stopped'
            }
        }
    }
}
