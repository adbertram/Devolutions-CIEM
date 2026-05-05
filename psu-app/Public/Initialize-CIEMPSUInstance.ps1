function Initialize-CIEMPSUInstance {
    <#
    .SYNOPSIS
        Bootstraps CIEM-owned PSU resources for an installed module.

    .DESCRIPTION
        Runs the complete CIEM PSU setup path: verifies the packaged app
        registration definition, registers editable CIEM PSU scripts, initializes
        the CIEM database, and verifies the resulting script and database state.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [switch]$Integrated
    )

    $ErrorActionPreference = 'Stop'

    $managedScriptNotes = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json'
    $psuConnectionParameters = @{}
    if ($Integrated) {
        $psuConnectionParameters.Integrated = $true
    }

    foreach ($commandName in @('Get-PSUApp', 'Get-PSUScript')) {
        if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            throw "Initialize-CIEMPSUInstance requires $commandName in the current PSU session."
        }
    }

    $dashboardResourcePath = Join-Path -Path $script:ModuleRoot -ChildPath '.universal/dashboards.ps1'
    if (-not (Test-Path -Path $dashboardResourcePath -PathType Leaf)) {
        throw "CIEM PSU app registration resource not found: $dashboardResourcePath"
    }

    $dashboardResourceContent = Get-Content -Path $dashboardResourcePath -Raw
    foreach ($requiredPattern in @(
            "New-PSUApp",
            "-Name\s+'Devolutions CIEM'",
            "-BaseUrl\s+'/ciem'",
            "-Module\s+'Devolutions\.CIEM'",
            "-Command\s+'New-DevolutionsCIEMApp'"
        )) {
        if ($dashboardResourceContent -notmatch $requiredPattern) {
            throw "CIEM PSU app registration resource is missing required pattern: $requiredPattern"
        }
    }

    $existingCiemApps = @(Get-PSUApp @psuConnectionParameters | Where-Object {
            $_.Name -eq 'Devolutions CIEM' -or $_.BaseUrl -eq '/ciem'
        })
    if ($existingCiemApps.Count -gt 1) {
        throw "Initialize-CIEMPSUInstance expected one or zero Devolutions CIEM app registrations before configuration completes, found $($existingCiemApps.Count)."
    }
    if ($existingCiemApps.Count -eq 1) {
        $app = $existingCiemApps[0]
        if ($app.Name -ne 'Devolutions CIEM') {
            throw "CIEM PSU app conflict: expected app name 'Devolutions CIEM', found '$($app.Name)'."
        }
        if ($app.BaseUrl -ne '/ciem') {
            throw "CIEM PSU app conflict: expected BaseUrl '/ciem', found '$($app.BaseUrl)'."
        }
        if ($app.PSObject.Properties['Module'] -and $app.Module -ne 'Devolutions.CIEM') {
            throw "CIEM PSU app conflict: expected module 'Devolutions.CIEM', found '$($app.Module)'."
        }
        if ($app.PSObject.Properties['Command'] -and $app.Command -ne 'New-DevolutionsCIEMApp') {
            throw "CIEM PSU app conflict: expected command 'New-DevolutionsCIEMApp', found '$($app.Command)'."
        }
    }

    $scriptRegistrationParams = @{}
    if ($Integrated) {
        $scriptRegistrationParams.Integrated = $true
    }
    $scriptRegistration = Import-CIEMScript @scriptRegistrationParams
    if (-not $scriptRegistration.PSObject.Properties['Status']) {
        throw 'CIEM PSU script registration returned no Status.'
    }
    if ($scriptRegistration.Status -ne 'Registered') {
        throw "CIEM PSU script registration failed with status '$($scriptRegistration.Status)'."
    }

    $databasePath = New-CIEMDatabase -PassThru
    if ([string]::IsNullOrWhiteSpace([string]$databasePath)) {
        throw 'New-CIEMDatabase did not return a database path.'
    }
    if (-not (Test-Path -Path $databasePath -PathType Leaf)) {
        throw "CIEM database was not created at '$databasePath'."
    }

    $manifestPath = Join-Path -Path $script:ModuleRoot -ChildPath 'data/psu-scripts.json'
    if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
        throw "CIEM PSU script manifest not found: $manifestPath"
    }
    $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json -Depth 10

    $expectedScriptNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($scriptDef in @($manifest.scripts)) {
        $scriptName = ([string]$scriptDef.name).Replace('\', '/').TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($scriptName)) {
            throw 'CIEM script manifest contains an empty script name.'
        }
        if (-not $expectedScriptNames.Add($scriptName)) {
            throw "CIEM script manifest contains a duplicate script name: $scriptName"
        }
    }

    $templateRootPath = [string]$manifest.remediationTemplates.path
    if ([string]::IsNullOrWhiteSpace($templateRootPath)) {
        throw 'CIEM script manifest remediationTemplates is missing path.'
    }
    $templateRoot = Join-Path -Path $script:ModuleRoot -ChildPath $templateRootPath
    if (-not (Test-Path -Path $templateRoot -PathType Container)) {
        throw "CIEM attack path remediation template folder not found: $templateRoot"
    }
    foreach ($templateFile in @(Get-ChildItem -Path $templateRoot -Filter '*.ps1' -File | Sort-Object Name)) {
        $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($templateFile.Name)
        if (-not $expectedScriptNames.Add($scriptName)) {
            throw "CIEM script manifest contains a duplicate script name: $scriptName"
        }
    }

    $registeredManagedScripts = @(Get-PSUScript @psuConnectionParameters | Where-Object {
            $_.Notes -eq $managedScriptNotes -or
            $_.CommitNotes -eq $managedScriptNotes
        })
    if ($registeredManagedScripts.Count -ne $expectedScriptNames.Count) {
        throw "Initialize-CIEMPSUInstance expected $($expectedScriptNames.Count) CIEM-managed PSU scripts, found $($registeredManagedScripts.Count)."
    }

    foreach ($expectedScriptName in @($expectedScriptNames)) {
        $matches = @($registeredManagedScripts | Where-Object {
                $registeredName = ([string]$_.Name).Replace('\', '/').TrimStart('/')
                $registeredName -eq $expectedScriptName
            })
        if ($matches.Count -ne 1) {
            throw "Initialize-CIEMPSUInstance expected one CIEM-managed PSU script named '$expectedScriptName', found $($matches.Count)."
        }
    }

    foreach ($tableName in @('providers', 'provider_auth_methods', 'checks', 'attack_path_rules')) {
        $tableRows = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'table' AND name = '$tableName'")
        if ($tableRows.Count -ne 1) {
            throw "CIEM database verification failed: table '$tableName' was not created."
        }

        $countRows = @(Invoke-CIEMQuery -Query "SELECT COUNT(*) AS RowCount FROM $tableName")
        if ($countRows.Count -ne 1 -or -not $countRows[0].PSObject.Properties['RowCount']) {
            throw "CIEM database verification failed: table '$tableName' did not return a row count."
        }
        if ([int]$countRows[0].RowCount -lt 1) {
            throw "CIEM database verification failed: table '$tableName' contains no rows."
        }
    }

    [pscustomobject]@{
        Status              = 'Ready'
        AppCount            = $existingCiemApps.Count
        ScriptCount         = $registeredManagedScripts.Count
        ExpectedScriptCount = $expectedScriptNames.Count
        DatabasePath        = $databasePath
        DatabaseInitialized = $true
    }
}
