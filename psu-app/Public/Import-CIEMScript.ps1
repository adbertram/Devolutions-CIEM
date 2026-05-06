function Import-CIEMScript {
    <#
    .SYNOPSIS
        Registers CIEM PSU automation scripts from the manifest.

    .DESCRIPTION
        Loads core script definitions and attack path remediation templates from
        data/psu-scripts.json and registers them as named PSU scripts.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [switch]$Integrated
    )

    $ErrorActionPreference = 'Stop'

    if (-not (Get-Command -Name 'New-PSUScript' -ErrorAction SilentlyContinue)) {
        throw 'Import-CIEMScript requires New-PSUScript in the current session.'
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
    $normalizeScriptName = {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$Name
        )
        $Name.Replace('\', '/').TrimStart('/')
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

    $scriptDefinitions = [System.Collections.Generic.List[object]]::new()
    $expectedScriptNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $expectedFolderPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($folder in @($manifest.folders)) {
        $folderPath = [string]$folder
        if ([string]::IsNullOrWhiteSpace($folderPath)) {
            throw 'CIEM script manifest contains an empty folder path.'
        }

        if ([System.IO.Path]::IsPathRooted($folderPath)) {
            throw "CIEM script manifest folder must use a relative path: $folderPath"
        }

        if ($folderPath -match '(^|[\\/])\.\.([\\/]|$)') {
            throw "CIEM script manifest folder contains invalid parent path traversal: $folderPath"
        }

        $normalizedFolderPath = & $normalizeScriptName -Name $folderPath
        if (-not $expectedFolderPaths.Add($normalizedFolderPath)) {
            throw "CIEM script manifest contains a duplicate folder path: $normalizedFolderPath"
        }

    }

    foreach ($scriptDef in @($manifest.scripts)) {
        $scriptName = [string]$scriptDef.name
        if ([string]::IsNullOrWhiteSpace($scriptName)) {
            throw 'CIEM script manifest contains an entry with an empty name.'
        }

        $normalizedScriptName = & $normalizeScriptName -Name $scriptName
        if ($normalizedScriptName -match '^Checks/AttackPathRemediation-') {
            throw "CIEM script manifest script name '$scriptName' is reserved for template scripts and must not be registered in PSU automation."
        }

        if (-not $expectedScriptNames.Add($normalizedScriptName)) {
            throw "CIEM script manifest contains a duplicate script name: $normalizedScriptName"
        }

        $path = [string]$scriptDef.path
        if ([string]::IsNullOrWhiteSpace($path)) {
            throw "CIEM script manifest entry '$normalizedScriptName' is missing path."
        }

        if ([System.IO.Path]::IsPathRooted($path)) {
            throw "CIEM script manifest entry '$normalizedScriptName' must use a relative path: $path"
        }

        if ($path -match '(^|[\\/])\.\.([\\/]|$)') {
            throw "CIEM script manifest entry '$normalizedScriptName' contains invalid parent path traversal: $path"
        }

        $absolutePath = Join-Path -Path $script:ModuleRoot -ChildPath $path
        if (-not (Test-Path -Path $absolutePath -PathType Leaf)) {
            throw "CIEM script not found for registration '$normalizedScriptName': $absolutePath"
        }

        $scriptDefinitions.Add([pscustomobject]@{
                Name                    = $normalizedScriptName
                AbsolutePath            = $absolutePath
                Description             = [string]$scriptDef.description
                Status                  = [string]$scriptDef.status
                Timeout                 = [double]$scriptDef.timeout
                DisableManualInvocation = [bool]$scriptDef.disableManualInvocation
                RepositoryPath          = $null
                Type                    = 'Core'
            })
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

    $templateNamePrefixProperty = $remediationTemplates.PSObject.Properties['namePrefix']
    if (-not $templateNamePrefixProperty) {
        throw 'CIEM script manifest remediationTemplates is missing namePrefix.'
    }

    $templateNamePrefix = [string]$templateNamePrefixProperty.Value
    $normalizedTemplateNamePrefix = & $normalizeScriptName -Name $templateNamePrefix
    if ($normalizedTemplateNamePrefix -ne '') {
        throw "CIEM script manifest remediationTemplates namePrefix must be empty so PSU attack path script names use the template file basename: $templateNamePrefix"
    }

    $templatePath = [string]$remediationTemplates.templatePath
    if ([string]::IsNullOrWhiteSpace($templatePath)) {
        throw 'CIEM script manifest remediationTemplates is missing templatePath.'
    }

    if ([System.IO.Path]::IsPathRooted($templatePath)) {
        throw "CIEM script manifest remediationTemplates templatePath must be relative: $templatePath"
    }

    if ($templatePath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "CIEM script manifest remediationTemplates templatePath contains invalid parent path traversal: $templatePath"
    }

    $absoluteTemplatePath = Join-Path -Path $script:ModuleRoot -ChildPath $templatePath
    if (-not (Test-Path -Path $absoluteTemplatePath -PathType Leaf)) {
        throw "CIEM attack path remediation script template not found: $absoluteTemplatePath"
    }

    $attackPathScriptTemplate = Get-Content -Path $absoluteTemplatePath -Raw
    if ([string]::IsNullOrWhiteSpace($attackPathScriptTemplate)) {
        throw "CIEM attack path remediation script template is empty: $absoluteTemplatePath"
    }

    $templateRoot = Join-Path -Path $script:ModuleRoot -ChildPath $templateRootPath
    if (-not (Test-Path -Path $templateRoot -PathType Container)) {
        throw "CIEM attack path remediation template folder not found: $templateRoot"
    }

    $templateFiles = @(Get-ChildItem -Path $templateRoot -Filter '*.ps1' -File | Sort-Object Name)
    if ($templateFiles.Count -eq 0) {
        throw "CIEM attack path remediation template folder contains no scripts: $templateRoot"
    }

    foreach ($templateFile in $templateFiles) {
        $normalizedScriptName = "$normalizedTemplateNamePrefix$([System.IO.Path]::GetFileNameWithoutExtension($templateFile.Name))"
        if (-not $expectedScriptNames.Add($normalizedScriptName)) {
            throw "CIEM script manifest contains a duplicate script name: $normalizedScriptName"
        }
        $repositoryPath = "Identities/AttackPaths/$normalizedScriptName.ps1"

        $scriptDefinitions.Add([pscustomobject]@{
                Name                    = $normalizedScriptName
                AbsolutePath            = $templateFile.FullName
                Description             = [string]$remediationTemplates.description
                Status                  = [string]$remediationTemplates.status
                Timeout                 = [double]$remediationTemplates.timeout
                DisableManualInvocation = [bool]$remediationTemplates.disableManualInvocation
                RepositoryPath          = $repositoryPath
                Type                    = 'AttackPath'
            })
    }

    $syncedFolders = 0

    $getScriptCommand = Get-Command -Name 'Get-PSUScript' -ErrorAction SilentlyContinue

    $coreScripts = 0
    $attackPathScripts = 0
    $setScriptCommand = Get-Command -Name 'Set-PSUScript' -ErrorAction SilentlyContinue
    $existingScripts = @()
    if ($getScriptCommand) {
        $existingScripts = @(Get-PSUScript @psuConnectionParameters)
    }

    foreach ($scriptDef in $scriptDefinitions) {
        $sourceContent = Get-Content -Path $scriptDef.AbsolutePath -Raw
        if ($scriptDef.Type -eq 'AttackPath') {
            $content = MergeCIEMAttackPathRemediationScriptTemplate `
                -TemplateContent $attackPathScriptTemplate `
                -ScriptBodyContent $sourceContent `
                -ScriptName $scriptDef.Name
        } else {
            $content = $sourceContent
        }

        if ([string]::IsNullOrWhiteSpace($content)) {
            throw "CIEM script content is empty for registration '$($scriptDef.Name)': $($scriptDef.AbsolutePath)"
        }

        $existingMatches = @()
        if ($getScriptCommand) {
            $expectedRepositoryPath = [string]$scriptDef.RepositoryPath
            $existingMatches = @($existingScripts | Where-Object {
                    if ($null -eq $_) {
                        return $false
                    }

                    if (-not [string]::IsNullOrWhiteSpace($expectedRepositoryPath)) {
                        $existingRepositoryPath = & $getExistingScriptPath -Script $_
                        return $existingRepositoryPath -eq $expectedRepositoryPath
                    }

                    $existingScriptName = & $normalizeScriptName -Name ([string]$_.Name)
                    $existingScriptName -eq [string]$scriptDef.Name
                })
        }

        if ($existingMatches.Count -gt 1) {
            throw "Multiple PSU scripts found for CIEM script name '$($scriptDef.Name)'."
        }

        if ($existingMatches.Count -eq 1) {
            $existingScript = $existingMatches[0]
            $existingManagedNotes = @(
                foreach ($propertyName in @('Notes', 'CommitNotes')) {
                    $property = $existingScript.PSObject.Properties[$propertyName]
                    if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                        [string]$property.Value
                    }
                }
            )
            if ($existingManagedNotes -notcontains $managedScriptNotes) {
                throw "PSU script conflict for '$($scriptDef.Name)': existing script is not marked as $managedScriptNotes."
            }

            if (-not $setScriptCommand) {
                throw 'Import-CIEMScript requires Set-PSUScript when existing scripts are present.'
            }

            if ($PSCmdlet.ShouldProcess($scriptDef.Name, 'Update PSU script')) {
                Set-PSUScript -Script $existingScript `
                    -Content $content `
                    -Description $scriptDef.Description `
                    -Status $scriptDef.Status `
                    -TimeOut $scriptDef.Timeout `
                    -DisableManualInvocation ([bool]$scriptDef.DisableManualInvocation) `
                    -Notes $managedScriptNotes `
                    @psuConnectionParameters | Out-Null
            }
        } else {
            if ($PSCmdlet.ShouldProcess($scriptDef.Name, 'Register PSU script')) {
                $newScriptParams = @{
                    Name                    = $scriptDef.Name
                    ScriptBlock             = [scriptblock]::Create($content)
                    Description             = $scriptDef.Description
                    Status                  = $scriptDef.Status
                    TimeOut                 = $scriptDef.Timeout
                    DisableManualInvocation = [bool]$scriptDef.DisableManualInvocation
                    Notes                   = $managedScriptNotes
                }
                if (-not [string]::IsNullOrWhiteSpace([string]$scriptDef.RepositoryPath)) {
                    $newScriptParams.Path = [string]$scriptDef.RepositoryPath
                }
                if ($Integrated) {
                    $newScriptParams.Integrated = $true
                }

                New-PSUScript @newScriptParams | Out-Null
            }
        }

        if ($scriptDef.Type -eq 'Core') {
            $coreScripts++
        } else {
            $attackPathScripts++
        }
    }

    [pscustomobject]@{
        ManifestPath       = $manifestPath
        SyncedFolders      = $syncedFolders
        CoreScripts        = $coreScripts
        AttackPathScripts  = $attackPathScripts
        RemediationScripts = $attackPathScripts
        TotalScripts       = $coreScripts + $attackPathScripts
        Status             = 'Registered'
    }
}
