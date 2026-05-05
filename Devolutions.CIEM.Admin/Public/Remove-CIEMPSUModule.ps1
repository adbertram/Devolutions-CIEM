function Remove-CIEMPSUModule {
    <#
    .SYNOPSIS
        Removes CIEM-owned PSU resources from a PSU target.

    .DESCRIPTION
        Connects to local or Azure PSU, removes CIEM-owned jobs, schedules, apps,
        and scripts registered by Import-CIEMScript, then removes the CIEM module.
        PSU job history is reported but not deleted because PSU does not expose a
        supported job deletion surface.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('local', 'azure')]
        [string]$Environment,

        [Parameter()]
        [string]$ModuleName = 'Devolutions.CIEM',

        [Parameter()]
        [string]$ModulePath = $script:PsuAppRoot,

        [Parameter()]
        [string]$EnvFilePath,

        [Parameter()]
        [string]$Url,

        [Parameter()]
        [string]$Token,

        [Parameter()]
        [string]$ResourceGroup,

        [Parameter()]
        [string]$WebAppName,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [switch]$Force
    )

    $ErrorActionPreference = 'Stop'

    $connectParams = @{}
    foreach ($connectionParameterName in @('Url', 'Token', 'EnvFilePath', 'ResourceGroup', 'WebAppName')) {
        if ($PSBoundParameters.ContainsKey($connectionParameterName)) {
            $connectParams[$connectionParameterName] = Get-Variable -Name $connectionParameterName -ValueOnly
        }
    }
    if ($Environment -eq 'local') {
        $connectParams.Local = $true
    }

    Connect-PSU @connectParams | Out-Null

    $removalModel = Get-CIEMPSUScriptRemovalModel -ModulePath $ModulePath
    $existingJobs = @(Get-CIEMPSUJobResources)
    $ownedJobs = @($existingJobs | Where-Object { Test-CIEMOwnedPSUJob -Job $_ -RemovalModel $removalModel })
    $activeOwnedJobs = @($ownedJobs | Where-Object { Test-CIEMActivePSUJob -Job $_ })
    $queuedOwnedJobs = @($ownedJobs | Where-Object { Test-CIEMQueuedPSUJob -Job $_ })
    $historyOwnedJobs = @($ownedJobs | Where-Object {
            -not (Test-CIEMActivePSUJob -Job $_) -and
            -not (Test-CIEMQueuedPSUJob -Job $_)
        })

    $stoppedJobs = 0
    foreach ($ownedJob in $activeOwnedJobs) {
        $jobIdProperty = $ownedJob.PSObject.Properties['Id']
        if (-not $jobIdProperty) {
            throw 'PSU job resource is missing Id.'
        }

        [long]$jobId = $jobIdProperty.Value
        $shouldStopJob = if ($WhatIfPreference) {
            $false
        }
        elseif ($Force) {
            $true
        }
        else {
            $PSCmdlet.ShouldProcess([string]$jobId, 'Stop active CIEM PSU job')
        }

        if ($shouldStopJob) {
            Stop-PSUJob -Id $jobId | Out-Null
            $stoppedJobs++
        }
    }

    $existingSchedules = @(Get-PSUSchedule)
    $ownedSchedules = @($existingSchedules | Where-Object { Test-CIEMOwnedPSUSchedule -Schedule $_ -RemovalModel $removalModel })

    $removedSchedules = 0
    foreach ($ownedSchedule in $ownedSchedules) {
        $scheduleName = [string]$ownedSchedule.Name
        if ([string]::IsNullOrWhiteSpace($scheduleName)) {
            $scheduleName = [string]$ownedSchedule.Id
        }

        $shouldRemoveSchedule = if ($WhatIfPreference) {
            $false
        }
        elseif ($Force) {
            $true
        }
        else {
            $PSCmdlet.ShouldProcess($scheduleName, 'Remove CIEM PSU schedule resource')
        }

        if ($shouldRemoveSchedule) {
            Remove-PSUSchedule -Schedule $ownedSchedule | Out-Null
            $removedSchedules++
        }
    }

    $existingApps = @(Get-PSUApp)
    $ownedApps = @($existingApps | Where-Object { Test-CIEMOwnedPSUApp -App $_ -ModuleName $ModuleName })

    $removedApps = 0
    foreach ($ownedApp in $ownedApps) {
        $appIdProperty = $ownedApp.PSObject.Properties['Id']
        if (-not $appIdProperty) {
            throw 'PSU app resource is missing Id.'
        }

        [long]$appId = $appIdProperty.Value
        $appName = [string]$ownedApp.Name
        if ([string]::IsNullOrWhiteSpace($appName)) {
            $appName = [string]$appId
        }

        $shouldRemoveApp = if ($WhatIfPreference) {
            $false
        }
        elseif ($Force) {
            $true
        }
        else {
            $PSCmdlet.ShouldProcess($appName, 'Remove CIEM PSU app resource')
        }

        if ($shouldRemoveApp) {
            Remove-PSUApp -Id $appId | Out-Null
            $removedApps++
        }
    }

    $existingScripts = @(Get-PSUScript)
    $ownedScripts = @($existingScripts | Where-Object { Test-CIEMOwnedPSUScript -Script $_ -RemovalModel $removalModel })

    $removedScripts = 0
    foreach ($ownedScript in $ownedScripts) {
        $scriptName = Normalize-CIEMPSUScriptName -Name ([string]$ownedScript.Name)
        $shouldRemoveScript = if ($WhatIfPreference) {
            $false
        }
        elseif ($Force) {
            $true
        }
        else {
            $PSCmdlet.ShouldProcess($scriptName, 'Remove CIEM PSU script resource')
        }

        if ($shouldRemoveScript) {
            Remove-PSUScript -Script $ownedScript | Out-Null
            $removedScripts++
        }
    }

    $removeModuleParams = @{
        Name        = $ModuleName
        Environment = $Environment
    }
    foreach ($moduleRemovalParameterName in @('EnvFilePath', 'Url', 'Token', 'ResourceGroup', 'WebAppName', 'Version')) {
        if ($PSBoundParameters.ContainsKey($moduleRemovalParameterName)) {
            $removeModuleParams[$moduleRemovalParameterName] = Get-Variable -Name $moduleRemovalParameterName -ValueOnly
        }
    }
    if ($Force -and -not $WhatIfPreference) {
        $removeModuleParams.Force = $true
    }

    $moduleRemoval = if ($WhatIfPreference) {
        [pscustomobject]@{
            Name   = $ModuleName
            Status = 'WhatIf'
        }
    }
    else {
        Remove-PSUModule @removeModuleParams
    }

    $removableResourcesRetained = (
        ($stoppedJobs -lt $activeOwnedJobs.Count) -or
        ($queuedOwnedJobs.Count -gt 0) -or
        ($removedSchedules -lt $ownedSchedules.Count) -or
        ($removedApps -lt $ownedApps.Count) -or
        ($removedScripts -lt $ownedScripts.Count)
    )
    $resourceActionCount = $stoppedJobs + $removedSchedules + $removedApps + $removedScripts

    $status = if ($WhatIfPreference) {
        'WhatIf'
    }
    elseif ($removableResourcesRetained) {
        'Partial'
    }
    elseif (-not $moduleRemoval) {
        if ($resourceActionCount -gt 0) {
            'Partial'
        }
        else {
            'Skipped'
        }
    }
    elseif ($moduleRemoval.PSObject.Properties['Status']) {
        [string]$moduleRemoval.Status
    }
    else {
        'Removed'
    }

    [pscustomobject]@{
        Environment                 = $Environment
        ModuleName                  = $ModuleName
        ManifestPath                = $removalModel.ManifestPath
        JobResourcesScanned         = $existingJobs.Count
        JobResourcesMatched         = $ownedJobs.Count
        JobResourcesStopped         = $stoppedJobs
        QueuedJobResourcesRetained  = $queuedOwnedJobs.Count
        JobHistoryRetained          = $historyOwnedJobs.Count
        ScheduleResourcesScanned    = $existingSchedules.Count
        ScheduleResourcesRemoved    = $removedSchedules
        AppResourcesScanned         = $existingApps.Count
        AppResourcesRemoved         = $removedApps
        ScriptResourcesScanned      = $existingScripts.Count
        ScriptResourcesRemoved      = $removedScripts
        ModuleRemoval               = $moduleRemoval
        Status                      = $status
    }
}
