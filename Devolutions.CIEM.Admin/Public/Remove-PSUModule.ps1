function Remove-PSUModule {
    <#
    .SYNOPSIS
        Removes a module from PowerShell Universal.

    .DESCRIPTION
        Uninstalls a module from the PSU instance by name. For Azure-hosted PSU,
        this also removes the module files from the filesystem via the Kudu API.

    .PARAMETER Name
        The name of the module to remove.

    .PARAMETER Version
        Specific version to remove. If not specified, removes all versions.

    .PARAMETER Environment
        PSU target to connect to before removal. Use azure for the Azure PSU
        instance or local for the publish point PSU instance.

    .PARAMETER Url
        PSU URL to pass to Connect-PSU when Environment is specified.

    .PARAMETER Token
        PSU token to pass to Connect-PSU when Environment is specified.

    .PARAMETER EnvFilePath
        Path to the .env file to pass to Connect-PSU when Environment is specified.

    .PARAMETER ResourceGroup
        Azure resource group to pass to Connect-PSU when Environment is azure.

    .PARAMETER WebAppName
        Azure web app name to pass to Connect-PSU when Environment is azure.

    .PARAMETER Force
        Skip confirmation prompt.

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM"

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM" -Version "0.2.18"

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM" -Force

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM" -Environment azure -Force

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM" -Environment local -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [ValidateSet('local', 'azure')]
        [string]$Environment,

        [Parameter()]
        [string]$Url,

        [Parameter()]
        [string]$Token,

        [Parameter()]
        [string]$EnvFilePath,

        [Parameter()]
        [string]$ResourceGroup,

        [Parameter()]
        [string]$WebAppName,

        [Parameter()]
        [switch]$Force
    )

    $ErrorActionPreference = 'Stop'

    $connectionParameterNames = @('Url', 'Token', 'EnvFilePath', 'ResourceGroup', 'WebAppName')
    $connectionParametersSupplied = @($connectionParameterNames | Where-Object { $PSBoundParameters.ContainsKey($_) })

    if ($connectionParametersSupplied.Count -gt 0 -and -not $PSBoundParameters.ContainsKey('Environment')) {
        throw "Remove-PSUModule requires -Environment when connection parameters are supplied."
    }

    if ($PSBoundParameters.ContainsKey('Environment')) {
        $connectParams = @{}
        foreach ($connectionParameterName in $connectionParameterNames) {
            if ($PSBoundParameters.ContainsKey($connectionParameterName)) {
                $connectParams[$connectionParameterName] = Get-Variable -Name $connectionParameterName -ValueOnly
            }
        }

        if ($Environment -eq 'local') {
            $connectParams['Local'] = $true
        }

        $null = Connect-PSU @connectParams
    }

    AssertPSUConnection

    $modules = @(Get-PSUModule -Name $Name | Where-Object { $_.name -eq $Name })

    if ($Version) {
        $modules = @($modules | Where-Object { $_.version -eq $Version })
    }

    $headers = @{
        'Authorization'              = "Bearer $($script:PSUConnection.Token)"
        'Accept'                     = 'application/json'
        # ngrok free tunnels return a browser-warning HTML interstitial unless
        # this header is set, which silently breaks Invoke-RestMethod parsing.
        'ngrok-skip-browser-warning' = 'true'
    }

    $targetDesc = if ($Version) {
        "$Name v$Version"
    }
    elseif ($modules.Count -gt 0) {
        "$Name (all versions: $($modules.version -join ', '))"
    }
    else {
        "$Name (not present in PSU database)"
    }

    if (-not $Force -and -not $PSCmdlet.ShouldProcess($targetDesc, "Remove module")) {
        return
    }

    $results = @()

    foreach ($mod in $modules) {
        Write-Verbose "Removing $($mod.name) v$($mod.version) (ID: $($mod.id)) from PSU database..."
        $uri = "$($script:PSUConnection.Url)/api/v1/module/$($mod.id)"

        Invoke-RestMethod -Uri $uri -Headers $headers -Method Delete -ErrorAction Stop
        Write-Verbose "Database entry removed for $($mod.name) v$($mod.version)"
    }

    $isLocalPublishPoint = $PSBoundParameters.ContainsKey('Environment') -and $Environment -eq 'local'

    if ($script:PSUConnection.IsAzure) {
        Write-Verbose "Azure hosting detected. Removing module files from filesystem..."

        $rg = $script:PSUConnection.ResourceGroup
        $webApp = $script:PSUConnection.WebAppName

        if (-not $rg -or -not $webApp) {
            throw "Azure resource group and web app name are required for module filesystem cleanup."
        }
        else {
            $azParams = @(
                'webapp', 'deployment', 'list-publishing-profiles',
                '--resource-group', $rg,
                '--name', $webApp,
                '--query', "[?publishMethod=='MSDeploy']",
                '--output', 'json'
            )
            $publishProfile = az @azParams 2>$null | ConvertFrom-Json

            if (-not $publishProfile) {
                throw "Could not get publishing profile"
            }

            $kuduUser = $publishProfile[0].userName
            $kuduPass = $publishProfile[0].userPWD
            $kuduBase = "https://$webApp.scm.azurewebsites.net"

            $kuduAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${kuduUser}:${kuduPass}"))

            $deletePath = if ($Version) {
                "/home/Repository/Modules/$Name/$Version"
            }
            else {
                "/home/Repository/Modules/$Name"
            }

            Write-Verbose "Deleting folder: $deletePath"

            $cmdUri = "$kuduBase/api/command"
            $cmdBody = @{
                command = "rm -rf `"$deletePath`""
                dir     = "/home"
            } | ConvertTo-Json

            $cmdHeaders = @{
                'Authorization' = "Basic $kuduAuth"
                'Content-Type'  = 'application/json'
            }

            $cmdResult = Invoke-RestMethod -Uri $cmdUri -Headers $cmdHeaders -Method Post -Body $cmdBody -ErrorAction Stop

            if ($cmdResult.ExitCode -ne 0) {
                throw "Command failed with exit code $($cmdResult.ExitCode): $($cmdResult.Error)"
            }

            $results += [PSCustomObject]@{
                Name    = $Name
                Version = if ($Version) { $Version } else { 'All' }
                Status  = 'Removed'
                Source  = 'Filesystem'
            }

            Write-Verbose "Filesystem cleanup completed successfully."
        }
    }
    elseif ($isLocalPublishPoint) {
        Write-Verbose "Local publish point detected. Removing module files from filesystem..."

        $envVars = ReadCIEMAdminEnvFile -EnvFilePath $EnvFilePath
        $sshAlias = [string]$envVars['PUBLISH_POINT_SSH']
        $remotePsuPath = [string]$envVars['PUBLISH_POINT_PSU_PATH']

        if (-not $sshAlias) {
            throw "PUBLISH_POINT_SSH is required in .env for local module filesystem cleanup."
        }
        if (-not $remotePsuPath) {
            throw "PUBLISH_POINT_PSU_PATH is required in .env for local module filesystem cleanup."
        }

        $remoteModulesDir = "$($remotePsuPath.TrimEnd('/'))/Repository/Modules"
        $deletePath = if ($Version) {
            "$remoteModulesDir/$Name/$Version"
        }
        else {
            "$remoteModulesDir/$Name"
        }

        & ssh $sshAlias "rm -rf '$deletePath'" 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to remove local PSU module folder '$deletePath' on '$sshAlias'. ssh exited with code $LASTEXITCODE."
        }

        $results += [PSCustomObject]@{
            Name    = $Name
            Version = if ($Version) { $Version } else { 'All' }
            Status  = 'Removed'
            Source  = 'Filesystem'
        }

        Write-Verbose "Filesystem cleanup completed successfully."
    }
    else {
        if ($modules.Count -eq 0) {
            $results += [PSCustomObject]@{
                Name    = $Name
                Version = if ($Version) { $Version } else { 'All' }
                Status  = 'NotFound'
                Source  = 'Database'
            }
        }
        else {
            $results += [PSCustomObject]@{
                Name    = $Name
                Version = if ($Version) { $Version } else { 'All' }
                Status  = 'Removed'
                Source  = 'Database'
            }
        }
    }

    if ($modules.Count -gt 0 -or $script:PSUConnection.IsAzure -or $isLocalPublishPoint) {
        Write-Verbose "Syncing PSU configuration to clear module cache..."
        Sync-PSUConfiguration -Reset | Out-Null
        Write-Verbose "Configuration sync completed."
    }

    $results
}
