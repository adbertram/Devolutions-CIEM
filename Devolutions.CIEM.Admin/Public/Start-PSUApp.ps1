function Start-PSUApp {
    <#
    .SYNOPSIS
        Starts a PowerShell Universal app.

    .PARAMETER Name
        The name of the app to start.

    .PARAMETER Id
        The ID of the app to start.

    .PARAMETER PassThru
        Return the app object after starting.

    .EXAMPLE
        Start-PSUApp -Name "CIEM"
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

    $uri = "$($script:PSUConnection.Url)/api/v1/dashboard/$Id/status"

    if ($PSCmdlet.ShouldProcess($appName, "Start PSU app")) {
        Write-Verbose "Starting app '$appName' (ID: $Id)..."

        try {
            $null = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -ErrorAction Stop
            Write-Verbose "App started successfully."
        }
        catch {
            throw "Failed to start app '$appName'. Error: $_"
        }

        if ($PassThru.IsPresent) {
            Get-PSUApp -Id $Id
        }
        else {
            [PSCustomObject]@{
                Id     = $Id
                Name   = $appName
                Status = 'Started'
            }
        }
    }
}
