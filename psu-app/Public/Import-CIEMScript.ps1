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
    param()

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

    $scriptDefinitions = [System.Collections.Generic.List[object]]::new()
    $expectedScriptNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $expectedScriptPaths = @{}
    $folderPaths = [System.Collections.Generic.List[string]]::new()
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

        $folderPaths.Add($normalizedFolderPath)
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
        $expectedScriptPaths[$normalizedScriptName] = & $getPsuRepositoryPath -Name $normalizedScriptName

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
                DisableManualInvocation = $false
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
        $expectedScriptPaths[$normalizedScriptName] = $repositoryPath

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
    if ($folderPaths.Count -gt 0) {
        $getFolderCommand = Get-Command -Name 'Get-PSUFolder' -ErrorAction SilentlyContinue
        $newFolderCommand = Get-Command -Name 'New-PSUFolder' -ErrorAction SilentlyContinue
        if (-not $getFolderCommand) {
            throw 'Import-CIEMScript requires Get-PSUFolder to sync PSU script folders.'
        }
        if (-not $newFolderCommand) {
            throw 'Import-CIEMScript requires New-PSUFolder to sync PSU script folders.'
        }

        foreach ($folderPath in $folderPaths) {
            $folderName = @($folderPath -split '/')[-1]
            $matchingFolders = @(Get-PSUFolder -Name $folderName | Where-Object {
                    $pathProperty = $_.PSObject.Properties['Path']
                    $nameProperty = $_.PSObject.Properties['Name']
                    $existingFolderPath = if ($pathProperty -and -not [string]::IsNullOrWhiteSpace([string]$pathProperty.Value)) {
                        [string]$pathProperty.Value
                    } elseif ($nameProperty -and -not [string]::IsNullOrWhiteSpace([string]$nameProperty.Value)) {
                        [string]$nameProperty.Value
                    } else {
                        ''
                    }

                    -not [string]::IsNullOrWhiteSpace($existingFolderPath) -and
                    (& $normalizeScriptName -Name $existingFolderPath) -eq $folderPath
                })

            if ($matchingFolders.Count -gt 1) {
                throw "Multiple PSU script folders found for CIEM folder path '$folderPath'."
            }

            if ($matchingFolders.Count -eq 1) {
                continue
            }

            if ($PSCmdlet.ShouldProcess($folderPath, 'Create PSU script folder')) {
                New-PSUFolder -Path $folderPath -Type Script | Out-Null
            }
            $syncedFolders++
        }
    }

    $prunedScripts = 0
    $getScriptCommand = Get-Command -Name 'Get-PSUScript' -ErrorAction SilentlyContinue
    $removeScriptCommand = Get-Command -Name 'Remove-PSUScript' -ErrorAction SilentlyContinue
    if ($getScriptCommand -and $removeScriptCommand) {
        foreach ($existingScript in @(Get-PSUScript)) {
            $existingName = [string]$existingScript.Name
            if ([string]::IsNullOrWhiteSpace($existingName)) {
                continue
            }

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
                Remove-PSUScript -Script $existingScript | Out-Null
            }

            $prunedScripts++
        }
    }

    $coreScripts = 0
    $attackPathScripts = 0
    $setScriptCommand = Get-Command -Name 'Set-PSUScript' -ErrorAction SilentlyContinue
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
            $existingMatches = @(Get-PSUScript -Name $scriptDef.Name | Where-Object {
                    if ($null -eq $_) {
                        return $false
                    }

                    if ([string]::IsNullOrWhiteSpace([string]$scriptDef.RepositoryPath)) {
                        return $true
                    }

                    $existingRepositoryPath = & $getExistingScriptPath -Script $_
                    [string]::IsNullOrWhiteSpace($existingRepositoryPath) -or $existingRepositoryPath -eq [string]$scriptDef.RepositoryPath
                })
        }

        if ($existingMatches.Count -gt 1) {
            throw "Multiple PSU scripts found for CIEM script name '$($scriptDef.Name)'."
        }

        if ($existingMatches.Count -eq 1) {
            if (-not $setScriptCommand) {
                throw 'Import-CIEMScript requires Set-PSUScript when existing scripts are present.'
            }

            if ($PSCmdlet.ShouldProcess($scriptDef.Name, 'Update PSU script')) {
                Set-PSUScript -Script $existingMatches[0] `
                    -Content $content `
                    -Description $scriptDef.Description `
                    -Status $scriptDef.Status `
                    -TimeOut $scriptDef.Timeout `
                    -DisableManualInvocation ([bool]$scriptDef.DisableManualInvocation) `
                    -Notes $managedScriptNotes | Out-Null
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
        PrunedScripts      = $prunedScripts
        SyncedFolders      = $syncedFolders
        CoreScripts        = $coreScripts
        AttackPathScripts  = $attackPathScripts
        RemediationScripts = $attackPathScripts
        TotalScripts       = $coreScripts + $attackPathScripts
        Status             = 'Registered'
    }
}
