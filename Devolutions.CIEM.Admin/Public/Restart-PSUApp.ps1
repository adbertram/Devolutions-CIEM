function Restart-PSUApp {
    <#
    .SYNOPSIS
        Restarts a PowerShell Universal app.

    .PARAMETER Name
        The name of the app to restart.

    .PARAMETER Id
        The ID of the app to restart.

    .PARAMETER PassThru
        Return the app object after restarting.

    .EXAMPLE
        Restart-PSUApp -Name "CIEM"
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

    Assert-PSUConnection

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

    $uri = "$($script:PSUConnection.Url)/api/v1/dashboard/$Id/status/restart"

    if ($PSCmdlet.ShouldProcess($appName, "Restart PSU app")) {
        Write-Verbose "Restarting app '$appName' (ID: $Id)..."

        try {
            $null = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -TimeoutSec 30 -ErrorAction Stop
            Write-Verbose "App restarted successfully."
        }
        catch [System.Threading.Tasks.TaskCanceledException] {
            Write-Verbose "Restart request timed out after 30s. The app restart may still be in progress."
        }
        catch {
            throw "Failed to restart app '$appName'. Error: $_"
        }

        if ($PassThru.IsPresent) {
            Get-PSUApp -Id $Id
        }
        else {
            [PSCustomObject]@{
                Id     = $Id
                Name   = $appName
                Status = 'Restarted'
            }
        }
    }
}
