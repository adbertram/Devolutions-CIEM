function Get-CIEMPSUScriptDefinition {
    <#
    .SYNOPSIS
        Returns CIEM-owned PSU script definitions from the packaged manifest.

    .DESCRIPTION
        Builds the script definitions used by PSU module resources and by
        explicit script registration. The definitions are derived from
        data/psu-scripts.json and the attack path remediation templates bundled
        with the module.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $ErrorActionPreference = 'Stop'

    $manifestPath = Join-Path -Path $script:ModuleRoot -ChildPath 'data/psu-scripts.json'
    if (-not (Test-Path -Path $manifestPath -PathType Leaf)) {
        throw "CIEM PSU script manifest not found: $manifestPath"
    }

    $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json -Depth 10

    $normalizeScriptName = {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$Name
        )
        $Name.Replace('\', '/').TrimStart('/')
    }

    $expectedScriptNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

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

        $content = Get-Content -Path $absolutePath -Raw
        if ([string]::IsNullOrWhiteSpace($content)) {
            throw "CIEM script content is empty for registration '$normalizedScriptName': $absolutePath"
        }

        [pscustomobject]@{
            Name                    = $normalizedScriptName
            Content                 = $content
            Description             = [string]$scriptDef.description
            Status                  = [string]$scriptDef.status
            Timeout                 = [double]$scriptDef.timeout
            DisableManualInvocation = [bool]$scriptDef.disableManualInvocation
            Type                    = 'Core'
        }
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

    $templateNamePrefixProperty = $remediationTemplates.PSObject.Properties['namePrefix']
    if (-not $templateNamePrefixProperty) {
        throw 'CIEM script manifest remediationTemplates is missing namePrefix.'
    }

    $normalizedTemplateNamePrefix = & $normalizeScriptName -Name ([string]$templateNamePrefixProperty.Value)
    if ($normalizedTemplateNamePrefix -ne '') {
        throw "CIEM script manifest remediationTemplates namePrefix must be empty so PSU attack path script names use the template file basename: $($templateNamePrefixProperty.Value)"
    }

    foreach ($templateFile in @(Get-ChildItem -Path $templateRoot -Filter '*.ps1' -File | Sort-Object Name)) {
        $normalizedScriptName = [System.IO.Path]::GetFileNameWithoutExtension($templateFile.Name)
        if (-not $expectedScriptNames.Add($normalizedScriptName)) {
            throw "CIEM script manifest contains a duplicate script name: $normalizedScriptName"
        }

        $content = MergeCIEMAttackPathRemediationScriptTemplate `
            -TemplateContent $attackPathScriptTemplate `
            -ScriptBodyContent (Get-Content -Path $templateFile.FullName -Raw) `
            -ScriptName $normalizedScriptName

        if ([string]::IsNullOrWhiteSpace($content)) {
            throw "CIEM script content is empty for registration '$normalizedScriptName': $($templateFile.FullName)"
        }

        [pscustomobject]@{
            Name                    = $normalizedScriptName
            Content                 = $content
            Description             = [string]$remediationTemplates.description
            Status                  = [string]$remediationTemplates.status
            Timeout                 = [double]$remediationTemplates.timeout
            DisableManualInvocation = [bool]$remediationTemplates.disableManualInvocation
            Type                    = 'AttackPath'
        }
    }
}
