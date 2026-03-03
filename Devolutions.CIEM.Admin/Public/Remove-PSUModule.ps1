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

    .PARAMETER Force
        Skip confirmation prompt.

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM"

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM" -Version "0.2.18"

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM" -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [switch]$Force
    )

    Assert-PSUConnection

    $modules = Get-PSUModule -Name $Name | Where-Object { $_.name -eq $Name }

    if (-not $modules) {
        throw "Module '$Name' not found in PSU."
    }

    if ($Version) {
        $modules = $modules | Where-Object { $_.version -eq $Version }
        if (-not $modules) {
            throw "Module '$Name' version '$Version' not found in PSU."
        }
    }

    $modules = @($modules)

    $headers = @{
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
    }

    $targetDesc = if ($Version) { "$Name v$Version" } else { "$Name (all versions: $($modules.version -join ', '))" }

    if (-not $Force -and -not $PSCmdlet.ShouldProcess($targetDesc, "Remove module")) {
        return
    }

    $results = @()

    foreach ($mod in $modules) {
        Write-Verbose "Removing $($mod.name) v$($mod.version) (ID: $($mod.id)) from PSU database..."
        $uri = "$($script:PSUConnection.Url)/api/v1/module/$($mod.id)"

        try {
            Invoke-RestMethod -Uri $uri -Headers $headers -Method Delete -ErrorAction Stop
            Write-Verbose "Database entry removed for $($mod.name) v$($mod.version)"
        }
        catch {
            Write-Warning "Failed to remove database entry for $($mod.name) v$($mod.version): $_"
        }
    }

    if ($script:PSUConnection.IsAzure) {
        Write-Verbose "Azure hosting detected. Removing module files from filesystem..."

        $rg = $script:PSUConnection.ResourceGroup
        $webApp = $script:PSUConnection.WebAppName

        if (-not $rg -or -not $webApp) {
            Write-Warning "Azure resource group or webapp name not configured. Filesystem cleanup skipped."
        }
        else {
            try {
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
            catch {
                Write-Warning "Failed to remove module files from Azure filesystem: $_"
                Write-Warning "You may need to manually delete: Repository/Modules/$Name/"
            }
        }
    }
    else {
        Write-Warning "Non-Azure PSU detected. REST API DELETE only removes database entries."
        Write-Warning "Module files may still exist on the PSU server filesystem."
    }

    Write-Verbose "Syncing PSU configuration to clear module cache..."
    try {
        Sync-PSUConfiguration -Reset | Out-Null
        Write-Verbose "Configuration sync completed."
    }
    catch {
        Write-Warning "Failed to sync configuration: $_"
        Write-Warning "You may need to manually call: Sync-PSUConfiguration -Reset"
    }

    if ($results.Count -eq 0) {
        [PSCustomObject]@{
            Name    = $Name
            Version = if ($Version) { $Version } else { 'All' }
            Status  = 'RemovedFromDatabase'
            Note    = 'Filesystem cleanup may be required'
        }
    }
    else {
        $results
    }
}
