<#
.SYNOPSIS
    Removes CIEM from a PSU target.

.DESCRIPTION
    Connects to the selected PSU target, removes CIEM-owned PSU Automation
    scripts registered by Import-CIEMScript, and then removes the CIEM PSU
    module with Remove-PSUModule.

    Import-CIEMScript creates additional PSU script resources that can be
    invoked with Invoke-PSUScript. Those resources are separate from the basic
    module install and need a separate cleanup pass.

.EXAMPLE
    ./scripts/remove-psu.ps1 -Environment azure -Force

.EXAMPLE
    ./scripts/remove-psu.ps1 -Environment local -Force
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidateSet('local', 'azure')]
    [string]$Environment,

    [Parameter()]
    [string]$ModuleName,

    [Parameter()]
    [string]$ModulePath,

    [Parameter()]
    [string]$AdminModulePath,

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

$script:RemovePSURepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$script:RemovePSUDefaultModulePath = Join-Path $script:RemovePSURepoRoot 'psu-app'
$script:RemovePSUDefaultAdminModulePath = Join-Path $script:RemovePSURepoRoot 'Devolutions.CIEM.Admin/Devolutions.CIEM.Admin.psd1'

function Normalize-CIEMPSUScriptName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    $Name.Replace('\', '/').TrimStart('/')
}

function Get-CIEMPSURepositoryPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    $normalizedName = Normalize-CIEMPSUScriptName -Name $Name
    if ($normalizedName -match '\.ps1$') {
        return $normalizedName
    }

    "$normalizedName.ps1"
}

function Get-CIEMPSUScriptPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Script
    )

    $ErrorActionPreference = 'Stop'

    foreach ($propertyName in @('FullPath', 'Path')) {
        $property = $Script.PSObject.Properties[$propertyName]
        if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return (Normalize-CIEMPSUScriptName -Name ([string]$property.Value))
        }
    }

    ''
}

function Get-CIEMPSUScriptNotes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Script
    )

    $ErrorActionPreference = 'Stop'

    foreach ($propertyName in @('Notes', 'CommitNotes')) {
        $property = $Script.PSObject.Properties[$propertyName]
        if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }

    ''
}

function Get-CIEMPSUScriptRemovalModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModulePath
    )

    $ErrorActionPreference = 'Stop'

    $resolvedModulePath = Resolve-Path -Path $ModulePath -ErrorAction Stop
    $moduleRoot = $resolvedModulePath.Path
    $manifestPath = Join-Path -Path $moduleRoot -ChildPath 'data/psu-scripts.json'
    if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
        throw "CIEM PSU script manifest not found: $manifestPath"
    }

    $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json -Depth 10
    $coreScriptNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $repositoryPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($scriptDef in @($manifest.scripts)) {
        $scriptName = [string]$scriptDef.name
        if ([string]::IsNullOrWhiteSpace($scriptName)) {
            throw 'CIEM script manifest contains an entry with an empty name.'
        }

        $normalizedScriptName = Normalize-CIEMPSUScriptName -Name $scriptName
        $null = $coreScriptNames.Add($normalizedScriptName)
        $null = $repositoryPaths.Add((Get-CIEMPSURepositoryPath -Name $normalizedScriptName))
    }

    $remediationTemplates = $manifest.remediationTemplates
    if ($null -eq $remediationTemplates) {
        throw 'CIEM script manifest is missing remediationTemplates.'
    }

    $templateRootPath = [string]$remediationTemplates.path
    if ([string]::IsNullOrWhiteSpace($templateRootPath)) {
        throw 'CIEM script manifest remediationTemplates is missing path.'
    }
    if ([System.IO.Path]::IsPathRooted($templateRootPath)) {
        throw "CIEM script manifest remediationTemplates path must be relative: $templateRootPath"
    }
    if ($templateRootPath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "CIEM script manifest remediationTemplates path contains invalid parent path traversal: $templateRootPath"
    }

    $templateRoot = Join-Path -Path $moduleRoot -ChildPath $templateRootPath
    if (-not (Test-Path -Path $templateRoot -PathType Container)) {
        throw "CIEM attack path remediation template folder not found: $templateRoot"
    }

    foreach ($templateFile in @(Get-ChildItem -Path $templateRoot -Filter '*.ps1' -File | Sort-Object Name)) {
        $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($templateFile.Name)
        $null = $repositoryPaths.Add("Identities/AttackPaths/$scriptName.ps1")
    }

    [pscustomobject]@{
        ManifestPath          = $manifestPath
        ManagedScriptNotes   = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json'
        CoreScriptNames      = $coreScriptNames
        RepositoryPaths      = $repositoryPaths
        LegacyScriptNames    = @(
            'CIEMExecutor.ps1'
            'Devolutions.CIEM'
            'Devolutions.CIEM/New-CIEMScanRun'
            'Devolutions.CIEM/Start-CIEMAzureDiscovery'
            'Devolutions.CIEM/Invoke-CIEMIdentityGraphBuild'
            'Devolutions.CIEM/Invoke-CIEMAttackPathRefresh'
        )
        LegacyPathPatterns   = @(
            '.*/Devolutions-CIEM/psu-app/Checks/New-CIEMScanRun\.ps1$'
            '.*/Devolutions-CIEM/psu-app/Checks/Start-CIEMAzureDiscovery\.ps1$'
            '.*/Devolutions-CIEM/psu-app/modules/Devolutions\.CIEM\.Graph/Data/attack_path_remediation_scripts/[^/]+\.ps1$'
        )
    }
}

function Test-CIEMOwnedPSUScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Script,

        [Parameter(Mandatory)]
        [object]$RemovalModel
    )

    $ErrorActionPreference = 'Stop'

    $scriptName = [string]$Script.Name
    if ([string]::IsNullOrWhiteSpace($scriptName)) {
        return $false
    }

    $normalizedName = Normalize-CIEMPSUScriptName -Name $scriptName
    if ($RemovalModel.CoreScriptNames.Contains($normalizedName)) {
        return $true
    }

    $scriptPath = Get-CIEMPSUScriptPath -Script $Script
    if (-not [string]::IsNullOrWhiteSpace($scriptPath) -and $RemovalModel.RepositoryPaths.Contains($scriptPath)) {
        return $true
    }

    if ((Get-CIEMPSUScriptNotes -Script $Script) -eq $RemovalModel.ManagedScriptNotes) {
        return $true
    }

    if ($RemovalModel.LegacyScriptNames -contains $normalizedName) {
        return $true
    }

    if ($normalizedName -match '^Checks/AttackPathRemediation-') {
        return $true
    }

    if ($normalizedName -match '^Identities/AttackPaths/AttackPathRemediation-') {
        return $true
    }

    foreach ($pathPattern in @($RemovalModel.LegacyPathPatterns)) {
        if ($normalizedName -match $pathPattern) {
            return $true
        }
    }

    $false
}

function Get-CIEMPSUJobResources {
    [CmdletBinding()]
    param(
        [Parameter()]
        [uint64]$PageSize = 1000
    )

    $ErrorActionPreference = 'Stop'

    $jobs = [System.Collections.Generic.List[object]]::new()
    [uint64]$skip = 0

    do {
        $jobPage = @(Get-PSUJob -First $PageSize -Skip $skip -OrderDirection Descending -HideChildren $false -HideScheduled $false -HideTriggered $false)
        foreach ($job in $jobPage) {
            $jobs.Add($job)
        }
        $skip += [uint64]$jobPage.Count
    } while ($jobPage.Count -eq $PageSize)

    @($jobs)
}

function Test-CIEMOwnedPSUObjectReference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Value,

        [Parameter(Mandatory)]
        [object]$RemovalModel
    )

    $ErrorActionPreference = 'Stop'

    if ($Value -is [string]) {
        $normalizedValue = Normalize-CIEMPSUScriptName -Name $Value
        if ([string]::IsNullOrWhiteSpace($normalizedValue)) {
            return $false
        }

        $scriptLikeObject = [pscustomobject]@{
            Name     = $normalizedValue
            FullPath = $normalizedValue
        }
        return (Test-CIEMOwnedPSUScript -Script $scriptLikeObject -RemovalModel $RemovalModel)
    }

    Test-CIEMOwnedPSUScript -Script $Value -RemovalModel $RemovalModel
}

function Test-CIEMOwnedPSUJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Job,

        [Parameter(Mandatory)]
        [object]$RemovalModel
    )

    $ErrorActionPreference = 'Stop'

    $isOwned = $false
    foreach ($propertyName in @('Script', 'ScriptFullPath', 'ScriptPath', 'ScriptName')) {
        $property = $Job.PSObject.Properties[$propertyName]
        if ($property -and $null -ne $property.Value) {
            if (Test-CIEMOwnedPSUObjectReference -Value $property.Value -RemovalModel $RemovalModel) {
                $isOwned = $true
            }
        }
    }

    $isOwned
}

function Test-CIEMActivePSUJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Job
    )

    $ErrorActionPreference = 'Stop'

    $statusProperty = $Job.PSObject.Properties['Status']
    if (-not $statusProperty) {
        throw 'PSU job resource is missing Status.'
    }

    [int]$status = $statusProperty.Value
    $status -in @(1, 4)
}

function Test-CIEMOwnedPSUSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Schedule,

        [Parameter(Mandatory)]
        [object]$RemovalModel
    )

    $ErrorActionPreference = 'Stop'

    $isOwned = $false
    foreach ($propertyName in @('Script', 'ScriptFullPath', 'ScriptPath', 'ScriptName')) {
        $property = $Schedule.PSObject.Properties[$propertyName]
        if ($property -and $null -ne $property.Value) {
            if (Test-CIEMOwnedPSUObjectReference -Value $property.Value -RemovalModel $RemovalModel) {
                $isOwned = $true
            }
        }
    }

    $isOwned
}

function Invoke-CIEMPSURemoval {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('local', 'azure')]
        [string]$Environment,

        [Parameter()]
        [string]$ModuleName = 'Devolutions.CIEM',

        [Parameter()]
        [string]$ModulePath = $script:RemovePSUDefaultModulePath,

        [Parameter()]
        [string]$AdminModulePath = $script:RemovePSUDefaultAdminModulePath,

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

    if (-not (Test-Path -Path $AdminModulePath -PathType Leaf)) {
        throw "Devolutions.CIEM.Admin module manifest not found: $AdminModulePath"
    }

    Import-Module $AdminModulePath -ErrorAction Stop

    $connectParams = @{}
    foreach ($connectionParameterName in @('Url', 'Token', 'EnvFilePath', 'ResourceGroup', 'WebAppName')) {
        if ($PSBoundParameters.ContainsKey($connectionParameterName)) {
            $connectParams[$connectionParameterName] = Get-Variable -Name $connectionParameterName -ValueOnly
        }
    }
    if ($Environment -eq 'local') {
        $connectParams['Local'] = $true
    }

    Connect-PSU @connectParams | Out-Null

    $removalModel = Get-CIEMPSUScriptRemovalModel -ModulePath $ModulePath
    $existingJobs = @(Get-CIEMPSUJobResources)
    $ownedJobs = @($existingJobs | Where-Object { Test-CIEMOwnedPSUJob -Job $_ -RemovalModel $removalModel })
    $activeOwnedJobs = @($ownedJobs | Where-Object { Test-CIEMActivePSUJob -Job $_ })
    $queuedOwnedJobs = @($ownedJobs | Where-Object {
            $statusProperty = $_.PSObject.Properties['Status']
            if (-not $statusProperty) {
                throw 'PSU job resource is missing Status.'
            }

            [int]$statusProperty.Value -eq 0
        })

    $stoppedJobs = 0
    foreach ($ownedJob in $activeOwnedJobs) {
        $jobIdProperty = $ownedJob.PSObject.Properties['Id']
        if (-not $jobIdProperty) {
            throw 'PSU job resource is missing Id.'
        }

        [long]$jobId = $jobIdProperty.Value
        $shouldStopJob = if ($Force -and -not $WhatIfPreference) {
            $true
        } else {
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

        $shouldRemoveSchedule = if ($Force -and -not $WhatIfPreference) {
            $true
        } else {
            $PSCmdlet.ShouldProcess($scheduleName, 'Remove CIEM PSU schedule resource')
        }

        if ($shouldRemoveSchedule) {
            Remove-PSUSchedule -Schedule $ownedSchedule | Out-Null
            $removedSchedules++
        }
    }

    $existingScripts = @(Get-PSUScript)
    $ownedScripts = @($existingScripts | Where-Object { Test-CIEMOwnedPSUScript -Script $_ -RemovalModel $removalModel })

    $removedScripts = 0
    foreach ($ownedScript in $ownedScripts) {
        $scriptName = Normalize-CIEMPSUScriptName -Name ([string]$ownedScript.Name)
        $shouldRemoveScript = if ($Force -and -not $WhatIfPreference) {
            $true
        } else {
            $PSCmdlet.ShouldProcess($scriptName, 'Remove CIEM PSU script resource')
        }

        if ($shouldRemoveScript) {
            Remove-PSUScript -Script $ownedScript | Out-Null
            $removedScripts++
        }
    }

    $removeModuleParams = @{
        Name = $ModuleName
    }
    if ($PSBoundParameters.ContainsKey('Version')) {
        $removeModuleParams.Version = $Version
    }
    if ($Force -and -not $WhatIfPreference) {
        $removeModuleParams.Force = $true
    }

    $moduleRemoval = Remove-PSUModule @removeModuleParams

    [pscustomobject]@{
        Environment            = $Environment
        ModuleName             = $ModuleName
        ManifestPath           = $removalModel.ManifestPath
        JobResourcesScanned    = $existingJobs.Count
        JobResourcesMatched    = $ownedJobs.Count
        JobResourcesStopped    = $stoppedJobs
        QueuedJobResourcesRetained = $queuedOwnedJobs.Count
        JobHistoryRetained     = $ownedJobs.Count
        ScheduleResourcesScanned = $existingSchedules.Count
        ScheduleResourcesRemoved = $removedSchedules
        ScriptResourcesScanned = $existingScripts.Count
        ScriptResourcesRemoved = $removedScripts
        ModuleRemoval          = $moduleRemoval
        Status                 = 'Removed'
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if (-not $PSBoundParameters.ContainsKey('Environment')) {
        throw 'scripts/remove-psu.ps1 requires -Environment local or -Environment azure.'
    }

    Invoke-CIEMPSURemoval @PSBoundParameters
}
