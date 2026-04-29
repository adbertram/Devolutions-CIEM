function Repair-CIEMLegacyScriptRegistration {
    <#
    .SYNOPSIS
        Removes CIEM PSU automation scripts registered by legacy naming schemes.

    .DESCRIPTION
        Prunes stale CIEM-owned scripts from older registration layouts. Current
        script registration is handled by Import-CIEMScript.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [switch]$Integrated
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Get-Command -Name 'Get-PSUScript' -ErrorAction SilentlyContinue)) {
        throw 'Repair-CIEMLegacyScriptRegistration requires Get-PSUScript in the current session.'
    }
    if (-not (Get-Command -Name 'Remove-PSUScript' -ErrorAction SilentlyContinue)) {
        throw 'Repair-CIEMLegacyScriptRegistration requires Remove-PSUScript in the current session.'
    }

    $manifestPath = Join-Path -Path $script:ModuleRoot -ChildPath 'data/psu-scripts.json'
    if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
        throw "CIEM PSU script manifest not found: $manifestPath"
    }

    $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json -Depth 10
    $managedScriptNotes = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json'
    $psuConnectionParameters = @{}
    if ($Integrated) {
        $psuConnectionParameters.Integrated = $true
    }

    $legacyScriptExactNames = @(
        'Devolutions.CIEM'
        'Devolutions.CIEM/New-CIEMScanRun'
        'Devolutions.CIEM/Start-CIEMAzureDiscovery'
        'Devolutions.CIEM/Invoke-CIEMIdentityGraphBuild'
        'Devolutions.CIEM/Invoke-CIEMAttackPathRefresh'
    )
    $legacyPathPatterns = @(
        '.*/Devolutions-CIEM/psu-app/Checks/New-CIEMScanRun\.ps1$'
        '.*/Devolutions-CIEM/psu-app/Checks/Start-CIEMAzureDiscovery\.ps1$'
        '.*/Devolutions-CIEM/psu-app/modules/Devolutions\.CIEM\.Graph/Data/attack_path_remediation_scripts/[^/]+\.ps1$'
    )

    $normalizeScriptName = {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$Name
        )
        $Name.Replace('\', '/').TrimStart('/')
    }

    $getPsuRepositoryPath = {
        param(
            [Parameter(Mandatory)]
            [string]$Name
        )

        $normalizedName = & $normalizeScriptName -Name $Name
        if ($normalizedName -match '\.ps1$') {
            $normalizedName
        } else {
            "$normalizedName.ps1"
        }
    }

    $getExistingScriptPath = {
        param(
            [Parameter(Mandatory)]
            [object]$Script
        )

        foreach ($propertyName in @('FullPath', 'Path')) {
            $property = $Script.PSObject.Properties[$propertyName]
            if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                & $normalizeScriptName -Name ([string]$property.Value)
                return
            }
        }

        ''
    }

    $getExistingScriptNotes = {
        param(
            [Parameter(Mandatory)]
            [object]$Script
        )

        foreach ($propertyName in @('Notes', 'CommitNotes')) {
            $property = $Script.PSObject.Properties[$propertyName]
            if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                [string]$property.Value
                return
            }
        }

        ''
    }

    $expectedScriptPaths = @{}
    foreach ($scriptDef in @($manifest.scripts)) {
        $scriptName = [string]$scriptDef.name
        if ([string]::IsNullOrWhiteSpace($scriptName)) {
            throw 'CIEM script manifest contains an entry with an empty name.'
        }

        $normalizedScriptName = & $normalizeScriptName -Name $scriptName
        $expectedScriptPaths[$normalizedScriptName] = & $getPsuRepositoryPath -Name $normalizedScriptName
    }

    $remediationTemplates = $manifest.remediationTemplates
    if ($null -eq $remediationTemplates) {
        throw 'CIEM script manifest is missing remediationTemplates.'
    }

    $templateRootPath = [string]$remediationTemplates.path
    if ([string]::IsNullOrWhiteSpace($templateRootPath)) {
        throw 'CIEM script manifest remediationTemplates is missing path.'
    }

    $templateRoot = Join-Path -Path $script:ModuleRoot -ChildPath $templateRootPath
    if (-not (Test-Path -Path $templateRoot -PathType Container)) {
        throw "CIEM attack path remediation template folder not found: $templateRoot"
    }

    foreach ($templateFile in @(Get-ChildItem -Path $templateRoot -Filter '*.ps1' -File)) {
        $normalizedScriptName = [System.IO.Path]::GetFileNameWithoutExtension($templateFile.Name)
        $expectedScriptPaths[$normalizedScriptName] = "Identities/AttackPaths/$normalizedScriptName.ps1"
    }

    $prunedScripts = 0
    $scannedScripts = 0
    foreach ($existingScript in @(Get-PSUScript @psuConnectionParameters)) {
        $existingName = [string]$existingScript.Name
        if ([string]::IsNullOrWhiteSpace($existingName)) {
            continue
        }

        $scannedScripts++
        $normalizedExistingName = & $normalizeScriptName -Name $existingName
        $isStaleScript = $false

        if ($expectedScriptPaths.ContainsKey($normalizedExistingName)) {
            $expectedRepositoryPath = [string]$expectedScriptPaths[$normalizedExistingName]
            $existingRepositoryPath = & $getExistingScriptPath -Script $existingScript
            if ([string]::IsNullOrWhiteSpace($existingRepositoryPath) -or $existingRepositoryPath -eq $expectedRepositoryPath) {
                continue
            }

            if ((& $getExistingScriptNotes -Script $existingScript) -eq $managedScriptNotes) {
                $isStaleScript = $true
            } else {
                throw "Existing PSU script '$normalizedExistingName' is stored at '$existingRepositoryPath' but CIEM expects '$expectedRepositoryPath'."
            }
        }

        if (-not $isStaleScript) {
            $isStaleScript = $legacyScriptExactNames -contains $normalizedExistingName
        }
        if (-not $isStaleScript -and $normalizedExistingName -match '^Checks/AttackPathRemediation-') {
            $isStaleScript = $true
        }
        if (-not $isStaleScript -and $normalizedExistingName -match '^Identities/AttackPaths/AttackPathRemediation-') {
            $isStaleScript = $true
        }

        if (-not $isStaleScript) {
            foreach ($pathPattern in $legacyPathPatterns) {
                if ($normalizedExistingName -match $pathPattern) {
                    $isStaleScript = $true
                    break
                }
            }
        }

        if (-not $isStaleScript) {
            if ((& $getExistingScriptNotes -Script $existingScript) -eq $managedScriptNotes) {
                $isStaleScript = $true
            }
        }

        if (-not $isStaleScript) {
            continue
        }

        if ($PSCmdlet.ShouldProcess($normalizedExistingName, 'Remove stale CIEM PSU script')) {
            Remove-PSUScript -Script $existingScript @psuConnectionParameters | Out-Null
        }

        $prunedScripts++
    }

    [pscustomobject]@{
        ManifestPath    = $manifestPath
        ScannedScripts  = $scannedScripts
        PrunedScripts   = $prunedScripts
        Status          = 'Repaired'
    }
}
