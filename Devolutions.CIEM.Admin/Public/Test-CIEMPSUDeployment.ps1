function Test-CIEMPSUDeployment {
    <#
    .SYNOPSIS
        Validates the installed CIEM PSU deployment.

    .DESCRIPTION
        Runs one combined PSU runtime probe that verifies the CIEM module, app
        registration, registered automation scripts, and initialized database.
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
        [string]$EnvFilePath
    )

    $ErrorActionPreference = 'Stop'

    $runtimeScript = {
        $modules = @(Get-Module -Name 'Devolutions.CIEM')
        $moduleCount = $modules.Count
        $appCount = @(Get-PSUApp -Integrated | Where-Object { $_.Name -eq 'Devolutions CIEM' -and $_.BaseUrl -eq '/ciem' }).Count
        $managedScriptNotes = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json'
        $registeredManagedScripts = @(Get-PSUScript -Integrated | Where-Object {
                $_.Notes -eq $managedScriptNotes -or
                $_.CommitNotes -eq $managedScriptNotes
            })
        $scriptCount = $registeredManagedScripts.Count
        $expectedScriptCount = 0
        if ($moduleCount -eq 1) {
            $moduleBase = $modules[0].ModuleBase
            $manifestPath = Join-Path -Path $moduleBase -ChildPath 'data/psu-scripts.json'
            if (Test-Path -Path $manifestPath -PathType Leaf) {
                $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json -Depth 10
                $expectedScriptCount = @($manifest.scripts).Count
                $templatePath = [string]$manifest.remediationTemplates.path
                if (-not [string]::IsNullOrWhiteSpace($templatePath)) {
                    $templateRoot = Join-Path -Path $moduleBase -ChildPath $templatePath
                    if (Test-Path -Path $templateRoot -PathType Container) {
                        $expectedScriptCount += @(Get-ChildItem -Path $templateRoot -Filter '*.ps1' -File).Count
                    }
                }
            }
        }
        $databasePath = Get-CIEMDatabasePath
        $databaseInitialized = $false
        if (Test-Path -Path $databasePath -PathType Leaf) {
            $providerTable = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'providers'")
            $databaseInitialized = $providerTable.Count -eq 1
        }

        [pscustomobject]@{
            ModuleCount         = $moduleCount
            AppCount            = $appCount
            ScriptCount         = $scriptCount
            ExpectedScriptCount = $expectedScriptCount
            DatabasePath        = $databasePath
            DatabaseInitialized = $databaseInitialized
        } | ConvertTo-Json -Depth 5 -Compress
    }

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

    if ([int]$details.ModuleCount -lt 1) {
        throw "CIEM deployment validation failed: Devolutions.CIEM module is not installed on $Environment."
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
    if (-not [bool]$details.DatabaseInitialized) {
        throw "CIEM deployment validation failed: CIEM database is not initialized on $Environment. Path: $($details.DatabasePath)"
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

    [pscustomobject]@{
        Environment = $Environment
        Details     = $details
        Url         = $ciemUrl
        Status      = 'Healthy'
    }
}
