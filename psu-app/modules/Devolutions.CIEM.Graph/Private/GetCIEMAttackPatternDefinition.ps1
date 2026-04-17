function GetCIEMAttackPatternDefinition {
    <#
    .SYNOPSIS
        Loads raw attack path pattern definitions from the CIEM database.
    .DESCRIPTION
        Reads the global attack_path_rules catalog. Used by both
        Get-CIEMAttackPath (evaluator) and Get-CIEMAttackPathPattern (catalog
        projection).
    #>
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $rows = @(Invoke-CIEMQuery -Query @"
SELECT id, name, severity, category, description, remediation,
       remediation_script_path, psu_script_name, steps_json, disabled, updated_at
FROM attack_path_rules
WHERE disabled = 0
ORDER BY id
"@)

    @(foreach ($row in $rows) {
        foreach ($field in @(
            @{ Name = 'id';                      Label = 'id' },
            @{ Name = 'name';                    Label = 'name' },
            @{ Name = 'severity';                Label = 'severity' },
            @{ Name = 'category';                Label = 'category' },
            @{ Name = 'description';             Label = 'description' },
            @{ Name = 'remediation';             Label = 'remediation' },
            @{ Name = 'remediation_script_path'; Label = 'remediation script path' },
            @{ Name = 'psu_script_name';         Label = 'PSU script reference' },
            @{ Name = 'steps_json';              Label = 'steps_json' }
        )) {
            if ([string]::IsNullOrWhiteSpace([string]$row.($field.Name))) {
                throw "Attack path rule '$($row.id)' has empty $($field.Label)."
            }
        }

        $steps = @($row.steps_json | ConvertFrom-Json -ErrorAction Stop)
        if ($steps.Count -eq 0) {
            throw "Attack path rule '$($row.id)' has no steps."
        }

        $rule = [CIEMAttackPathRule]::new()
        $rule.Id = [string]$row.id
        $rule.Name = [string]$row.name
        $rule.Severity = [string]$row.severity
        $rule.Category = [string]$row.category
        $rule.Description = [string]$row.description
        $rule.Remediation = [string]$row.remediation
        $rule.RemediationScriptPath = [string]$row.remediation_script_path
        $rule.PsuScriptName = [string]$row.psu_script_name
        $rule.Steps = $steps
        $rule.StepCount = [int]$steps.Count
        $rule.Disabled = [bool]$row.disabled
        $rule.UpdatedAt = [string]$row.updated_at
        $rule
    })
}
