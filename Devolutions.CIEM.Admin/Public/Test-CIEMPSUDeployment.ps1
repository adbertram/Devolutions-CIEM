function Test-CIEMPSUDeployment {
    <#
    .SYNOPSIS
        Validates the installed CIEM PSU deployment.

    .DESCRIPTION
        Runs one combined PSU runtime probe that verifies the CIEM module, app
        registration, registered automation scripts, initialized database,
        schedule support, supported PSU version, and supported topology.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [ValidateSet('local', 'azure')]
        [string]$Environment = 'local',

        [Parameter()]
        [int]$TimeoutSeconds = 300,

        [Parameter()]
        [string]$EnvFilePath,

        [Parameter()]
        [ValidateSet('SingleInstance', 'MultiInstance')]
        [string]$Topology = 'SingleInstance',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ExpectedPsuVersion,

        [Parameter()]
        [switch]$ValidateManagedIdentityRead
    )

    $ErrorActionPreference = 'Stop'

    if ($Topology -eq 'MultiInstance') {
        throw 'CIEM deployment validation failed: multi-instance PSU topology has not been validated for the CIEM SQLite database path. Validate shared storage, database locking, and schedule ownership before using CIEM on more than one PSU instance.'
    }

    $validateManagedIdentityReadLiteral = if ($ValidateManagedIdentityRead) { '$true' } else { '$false' }
    $runtimeScriptText = @'
$validateManagedIdentityRead = __VALIDATE_MANAGED_IDENTITY_READ__

$psuInformation = Get-PSUInformation
if (-not $psuInformation.PSObject.Properties['Version']) {
    throw 'Get-PSUInformation did not return a Version property.'
}
$psuVersion = [string]$psuInformation.Version

$modules = @(Get-Module -Name 'Devolutions.CIEM')
$moduleCount = $modules.Count
$moduleVersion = $null
$moduleBase = $null
if ($moduleCount -eq 1) {
    $moduleVersion = [string]$modules[0].Version
    $moduleBase = [string]$modules[0].ModuleBase
}

$appCount = @(Get-PSUApp -Integrated | Where-Object { $_.Name -eq 'Devolutions CIEM' -and $_.BaseUrl -eq '/ciem' }).Count
$managedScriptNotes = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json'
$registeredManagedScripts = @(Get-PSUScript -Integrated | Where-Object {
        $_.Notes -eq $managedScriptNotes -or
        $_.CommitNotes -eq $managedScriptNotes
    })
$expectedScriptNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($commandName in @(
        'New-CIEMScanRun',
        'Start-CIEMAzureDiscovery',
        'Invoke-CIEMAttackPathRemediation'
    )) {
    $null = $expectedScriptNames.Add("Devolutions.CIEM/$commandName")
}
$expectedScriptCount = $expectedScriptNames.Count
$scriptCount = @($registeredManagedScripts | Where-Object {
        $scriptName = ([string]$_.Name).Replace('\', '/').TrimStart('/')
        $expectedScriptNames.Contains($scriptName)
    }).Count
$supportedDiscoveryScriptName = 'Devolutions.CIEM/Start-CIEMAzureDiscovery'
$discoveryCommandRegistered = @($registeredManagedScripts | Where-Object {
        ([string]$_.Name).Replace('\', '/').TrimStart('/') -eq $supportedDiscoveryScriptName
    }).Count -eq 1
$scheduleSupportAvailable = $null -ne (Get-Command -Name 'New-PSUSchedule' -ErrorAction SilentlyContinue)

$unsupportedScriptNames = @()
foreach ($script in @(Get-PSUScript -Integrated)) {
    $scriptName = ([string]$script.Name).Replace('\', '/').TrimStart('/')
    $isExpectedScript = $expectedScriptNames.Contains($scriptName)
    if ($isExpectedScript) {
        continue
    }

    $isManagedCiemScript = $script.Notes -eq $managedScriptNotes -or
        $script.CommitNotes -eq $managedScriptNotes
    $isUnsupportedCiemScript = $isManagedCiemScript -or
        $scriptName -eq 'Devolutions.CIEM' -or
        $scriptName -match '^Devolutions\.CIEM/' -or
        $scriptName -match '^Checks/' -or
        ($scriptName -match '^Users/' -and $scriptName -match '/Devolutions-CIEM/') -or
        $scriptName -match '^Identities/AttackPaths/AttackPathRemediation-'
    if ($isUnsupportedCiemScript) {
        $unsupportedScriptNames += $scriptName
    }
}

$databasePath = Get-CIEMDatabasePath
$databaseInitialized = $false
if (Test-Path -Path $databasePath -PathType Leaf) {
    $providerTable = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'providers'")
    $databaseInitialized = $providerTable.Count -eq 1
}

$managedIdentityReadStatus = 'NotRequested'
$managedIdentitySubscriptionCount = 0
if ($validateManagedIdentityRead) {
    $assignment = Get-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId 'Azure'
    if ($null -eq $assignment) {
        throw "Managed identity read validation requires ProviderDiscovery/Azure to have an assigned authentication profile."
    }

    $managedIdentityProfiles = @(Get-CIEMAuthenticationProfile -Id $assignment.AuthenticationProfileId | Where-Object {
        $_.Provider -eq 'Azure' -and $_.Method -eq 'ManagedIdentity'
    })
    if ($managedIdentityProfiles.Count -ne 1) {
        throw "Managed identity read validation requires the ProviderDiscovery/Azure assigned authentication profile to use Azure ManagedIdentity, found $($managedIdentityProfiles.Count)."
    }

    $managedIdentityContext = Connect-CIEMAzure -AuthenticationProfile $managedIdentityProfiles[0]
    $managedIdentitySubscriptionCount = @($managedIdentityContext.SubscriptionIds).Count
    if ($managedIdentitySubscriptionCount -lt 1) {
        throw 'Managed identity read validation found no enabled Azure subscriptions.'
    }

    $managedIdentityReadStatus = 'Validated'
}

[pscustomobject]@{
    PsuVersion                       = $psuVersion
    ModuleCount                      = $moduleCount
    ModuleVersion                    = $moduleVersion
    ModuleBase                       = $moduleBase
    AppCount                         = $appCount
    ScriptCount                      = $scriptCount
    ExpectedScriptCount              = $expectedScriptCount
    UnsupportedScriptCount           = @($unsupportedScriptNames).Count
    UnsupportedScriptNames           = @($unsupportedScriptNames)
    DiscoveryCommandRegistered       = $discoveryCommandRegistered
    ScheduleSupportAvailable         = $scheduleSupportAvailable
    DatabasePath                     = $databasePath
    DatabaseInitialized              = $databaseInitialized
    ManagedIdentityReadStatus        = $managedIdentityReadStatus
    ManagedIdentitySubscriptionCount = $managedIdentitySubscriptionCount
} | ConvertTo-Json -Depth 5 -Compress
'@
    $runtimeScript = [scriptblock]::Create(
        $runtimeScriptText.Replace('__VALIDATE_MANAGED_IDENTITY_READ__', $validateManagedIdentityReadLiteral)
    )

    $probe = Invoke-TestCommand -Environment $Environment -EnvFilePath $EnvFilePath -TimeoutSeconds $TimeoutSeconds -ScriptBlock $runtimeScript
    if ($probe.PSObject.Properties['Status'] -and $probe.Status -ne 'Completed') {
        throw "CIEM deployment probe failed with status $($probe.Status)."
    }

    $outputText = @($probe.Output | ForEach-Object {
            if ($_ -is [string]) {
                $_
            }
            elseif ($_.message) {
                $_.message
            }
            elseif ($_.data) {
                $_.data
            }
        }) -join "`n"

    $jsonLine = @($outputText -split "`r?`n" | Where-Object { $_ -match '^\s*[\{\[]' }) | Select-Object -Last 1
    if (-not $jsonLine) {
        throw 'CIEM deployment probe did not return JSON output.'
    }

    $details = $jsonLine | ConvertFrom-Json -Depth 10

    if ([string]::IsNullOrWhiteSpace([string]$details.PsuVersion)) {
        throw "CIEM deployment validation failed: PSU version could not be determined on $Environment."
    }
    if ($PSBoundParameters.ContainsKey('ExpectedPsuVersion') -and [string]$details.PsuVersion -ne $ExpectedPsuVersion) {
        throw "CIEM deployment validation failed: expected PSU version $ExpectedPsuVersion on $Environment, found $($details.PsuVersion)."
    }
    if ([int]$details.ModuleCount -ne 1) {
        throw "CIEM deployment validation failed: expected one Devolutions.CIEM module on $Environment, found $($details.ModuleCount)."
    }
    if ([string]::IsNullOrWhiteSpace([string]$details.ModuleBase)) {
        throw "CIEM deployment validation failed: Devolutions.CIEM module import path could not be determined on $Environment."
    }
    if ([int]$details.AppCount -ne 1) {
        throw "CIEM deployment validation failed: expected one Devolutions CIEM app at /ciem on $Environment, found $($details.AppCount)."
    }
    if ([int]$details.ExpectedScriptCount -lt 1) {
        throw "CIEM deployment validation failed: expected script count could not be determined on $Environment."
    }
    if ([int]$details.ScriptCount -ne [int]$details.ExpectedScriptCount) {
        throw "CIEM deployment validation failed: expected $($details.ExpectedScriptCount) CIEM-managed PSU scripts on $Environment, found $($details.ScriptCount)."
    }
    if ([int]$details.UnsupportedScriptCount -gt 0) {
        throw "CIEM deployment validation failed: unsupported CIEM PSU scripts on ${Environment}: $($details.UnsupportedScriptNames -join ', '). Remove CIEM from the PSU instance before installing the current module."
    }
    if (-not [bool]$details.DiscoveryCommandRegistered) {
        throw "CIEM deployment validation failed: Devolutions.CIEM\Start-CIEMAzureDiscovery is not registered on $Environment."
    }
    if (-not [bool]$details.ScheduleSupportAvailable) {
        throw "CIEM deployment validation failed: PSU schedule support is not available on $Environment."
    }
    if (-not [bool]$details.DatabaseInitialized) {
        throw "CIEM deployment validation failed: CIEM database is not initialized on $Environment. Path: $($details.DatabasePath)"
    }
    if ($ValidateManagedIdentityRead -and [string]$details.ManagedIdentityReadStatus -ne 'Validated') {
        throw "CIEM deployment validation failed: managed identity read permission was not validated on $Environment."
    }

    $target = GetCIEMRuntimeTarget -Name $Environment -EnvFilePath $EnvFilePath
    $ciemUrl = "$($target.Url)/ciem"
    $pageResponse = Invoke-WebRequest `
        -Uri $ciemUrl `
        -Headers @{ 'ngrok-skip-browser-warning' = 'true' } `
        -Method Get `
        -MaximumRedirection 5 `
        -SkipHttpErrorCheck `
        -TimeoutSec 20 `
        -ErrorAction Stop
    if ([int]$pageResponse.StatusCode -ne 200) {
        throw "CIEM deployment validation failed: $ciemUrl returned HTTP $($pageResponse.StatusCode)."
    }

    $pageContent = [string]$pageResponse.Content
    if ([string]::IsNullOrWhiteSpace($pageContent)) {
        throw "CIEM deployment validation failed: $ciemUrl returned an empty page."
    }
    if ($pageContent -match 'App is not running') {
        throw "CIEM deployment validation failed: CIEM app page is not running at $ciemUrl."
    }

    $managedIdentityCheckStatus = if ($ValidateManagedIdentityRead) { 'Healthy' } else { 'NotRequested' }
    $managedIdentityCheckDetail = if ($ValidateManagedIdentityRead) {
        "Validated with $($details.ManagedIdentitySubscriptionCount) enabled subscription(s)."
    }
    else {
        'Run with -ValidateManagedIdentityRead on the Azure PSU instance to prove managed identity subscription read access.'
    }

    [pscustomobject]@{
        Environment         = $Environment
        Details             = $details
        Url                 = $ciemUrl
        Status              = 'Healthy'
        ExpectedPsuVersion  = $ExpectedPsuVersion
        SupportedTopology   = 'SingleInstance'
        MultiInstanceStatus = 'NotValidated'
        SQLiteSupportStatus = 'SupportedForSingleInstance'
        Checklist           = @(
            [pscustomobject]@{ Name = 'PSU version'; Status = 'Healthy'; Detail = "PowerShell Universal $($details.PsuVersion)." }
            [pscustomobject]@{ Name = 'CIEM module import path'; Status = 'Healthy'; Detail = "$($details.ModuleVersion) at $($details.ModuleBase)." }
            [pscustomobject]@{ Name = 'CIEM app route'; Status = 'Healthy'; Detail = "$ciemUrl returned usable CIEM content." }
            [pscustomobject]@{ Name = 'CIEM automation scripts'; Status = 'Healthy'; Detail = "$($details.ScriptCount) managed script(s) registered, including Devolutions.CIEM\Start-CIEMAzureDiscovery." }
            [pscustomobject]@{ Name = 'Scheduled discovery support'; Status = 'Healthy'; Detail = 'New-PSUSchedule is available for the next scheduled-discovery phase.' }
            [pscustomobject]@{ Name = 'CIEM SQLite database'; Status = 'Healthy'; Detail = "Initialized at $($details.DatabasePath). Supported for the validated single-instance PSU topology." }
            [pscustomobject]@{ Name = 'PSU topology'; Status = 'Healthy'; Detail = 'Single PSU instance validated. Multi-instance remains blocked until CIEM SQLite sharing, locking, and schedule ownership are tested.' }
            [pscustomobject]@{ Name = 'Managed identity read permission'; Status = $managedIdentityCheckStatus; Detail = $managedIdentityCheckDetail }
        )
    }
}
