function Sync-CIEMAttackPathRuleCatalog {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $ErrorActionPreference = 'Stop'

    $patternDir = Join-Path $script:GraphRoot 'Data' 'attack_paths'
    if (-not (Test-Path -Path $patternDir -PathType Container)) {
        throw "Attack path rule catalog directory not found: $patternDir"
    }

    $patternFiles = @(Get-ChildItem -Path $patternDir -Filter '*.json' -File | Sort-Object Name)
    if ($patternFiles.Count -eq 0) {
        throw "Attack path rule catalog directory contains no JSON rules: $patternDir"
    }

    $now = (Get-Date).ToString('o')
    $ruleIds = [System.Collections.Generic.List[string]]::new()

    foreach ($file in $patternFiles) {
        $rule = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -ErrorAction Stop

        foreach ($field in @('id', 'name', 'severity', 'category', 'description', 'remediation', 'remediation_script')) {
            if (-not $rule.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace([string]$rule.$field)) {
                throw "Attack path rule file '$($file.Name)' is missing required field '$field'."
            }
        }

        if (-not $rule.PSObject.Properties['steps'] -or @($rule.steps).Count -eq 0) {
            throw "Attack path rule file '$($file.Name)' is missing required field 'steps'."
        }

        $relativeScriptPath = [string]$rule.remediation_script
        $absoluteScriptPath = Join-Path $script:ModuleRoot $relativeScriptPath
        if (-not (Test-Path -Path $absoluteScriptPath -PathType Leaf)) {
            throw "Attack path rule '$($rule.id)' references missing remediation script '$relativeScriptPath'."
        }

        $psuScriptName = ConvertToCIEMAttackPathPsuScriptName -RemediationScriptPath $relativeScriptPath
        $stepsJson = $rule.steps | ConvertTo-Json -Depth 20 -Compress
        if ([string]::IsNullOrWhiteSpace($stepsJson)) {
            throw "Attack path rule '$($rule.id)' produced empty steps JSON."
        }

        $ruleIds.Add([string]$rule.id)

        Invoke-CIEMQuery -Query @"
INSERT OR REPLACE INTO attack_path_rules (
    id, name, severity, category, description, remediation,
    remediation_script_path, psu_script_name, steps_json, disabled, updated_at
) VALUES (
    @id, @name, @severity, @category, @description, @remediation,
    @remediation_script_path, @psu_script_name, @steps_json, 0, @updated_at
)
"@ -Parameters @{
            id                      = [string]$rule.id
            name                    = [string]$rule.name
            severity                = [string]$rule.severity
            category                = [string]$rule.category
            description             = [string]$rule.description
            remediation             = [string]$rule.remediation
            remediation_script_path = $relativeScriptPath
            psu_script_name         = $psuScriptName
            steps_json              = $stepsJson
            updated_at              = $now
        } -AsNonQuery | Out-Null
    }

    [pscustomobject]@{
        RuleCount  = $ruleIds.Count
        CatalogDir = $patternDir
        Status     = 'Synced'
    }
}
