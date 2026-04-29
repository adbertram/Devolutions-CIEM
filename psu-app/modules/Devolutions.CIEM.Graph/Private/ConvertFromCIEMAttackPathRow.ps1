function ConvertFromCIEMAttackPathRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Row
    )

    $ErrorActionPreference = 'Stop'

    $attackPath = [CIEMAttackPath]::new()
    $attackPath.Id = [string]$Row.id
    $attackPath.RuleId = [string]$Row.rule_id
    $attackPath.PatternId = [string]$Row.rule_id
    $attackPath.PatternName = [string]$Row.pattern_name
    $attackPath.Severity = [string]$Row.severity
    $attackPath.Category = [string]$Row.category
    $attackPath.Remediation = [string]$Row.remediation
    $attackPath.RemediationScriptPath = [string]$Row.remediation_script_path
    $attackPath.PsuScriptName = [string]$Row.psu_script_name
    $attackPath.PathChain = [string]$Row.path_chain
    $attackPath.EvaluatedAt = [string]$Row.evaluated_at
    $attackPath.Path = @($Row.path_json | ConvertFrom-Json -ErrorAction Stop)
    $attackPath.Edges = @($Row.edges_json | ConvertFrom-Json -ErrorAction Stop)
    $attackPath
}
