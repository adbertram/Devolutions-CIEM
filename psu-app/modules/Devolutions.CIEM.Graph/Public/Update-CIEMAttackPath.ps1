function Update-CIEMAttackPath {
    [CmdletBinding()]
    [OutputType('CIEMAttackPath[]')]
    param(
        [Parameter()]
        [string]$PatternId,

        [Parameter()]
        [ValidateSet('critical', 'high', 'medium', 'low')]
        [string]$Severity,

        [Parameter()]
        [switch]$PassThru
    )

    $ErrorActionPreference = 'Stop'

    $patterns = @(GetCIEMAttackPatternDefinition)
    if ($PatternId) {
        $patterns = @($patterns | Where-Object { $_.id -eq $PatternId })
    }
    if ($Severity) {
        $patterns = @($patterns | Where-Object { $_.severity -eq $Severity })
    }

    $refreshRuleIds = @($patterns | ForEach-Object { [string]$_.id })
    if ($refreshRuleIds.Count -gt 0) {
        $deleteParams = @{}
        $deletePlaceholders = @()
        for ($i = 0; $i -lt $refreshRuleIds.Count; $i++) {
            $key = "rule$i"
            $deleteParams[$key] = $refreshRuleIds[$i]
            $deletePlaceholders += "@$key"
        }

        Invoke-CIEMQuery -Query "DELETE FROM attack_paths WHERE rule_id IN ($($deletePlaceholders -join ', '))" -Parameters $deleteParams -AsNonQuery | Out-Null
    }

    $evaluatedAt = (Get-Date).ToString('o')
    $findings = [System.Collections.Generic.List[object]]::new()

    foreach ($pattern in $patterns) {
        foreach ($attackPath in @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)) {
            $attackPath.EvaluatedAt = $evaluatedAt
            $pathJson = @($attackPath.Path) | ConvertTo-Json -Depth 20 -Compress
            $edgesJson = @($attackPath.Edges) | ConvertTo-Json -Depth 20 -Compress

            if ([string]::IsNullOrWhiteSpace($pathJson)) {
                throw "Cannot store attack path '$($attackPath.Id)' because path JSON is empty."
            }

            if ([string]::IsNullOrWhiteSpace($edgesJson)) {
                throw "Cannot store attack path '$($attackPath.Id)' because edges JSON is empty."
            }

            Invoke-CIEMQuery -Query @"
INSERT OR REPLACE INTO attack_paths (
    id, rule_id, pattern_name, severity, category, remediation, psu_script_name,
    path_json, edges_json, path_chain, evaluated_at
) VALUES (
    @id, @rule_id, @pattern_name, @severity, @category, @remediation, @psu_script_name,
    @path_json, @edges_json, @path_chain, @evaluated_at
)
"@ -Parameters @{
                id              = $attackPath.Id
                rule_id         = $attackPath.PatternId
                pattern_name    = $attackPath.PatternName
                severity        = $attackPath.Severity
                category        = $attackPath.Category
                remediation     = $attackPath.Remediation
                psu_script_name = $attackPath.PsuScriptName
                path_json       = $pathJson
                edges_json      = $edgesJson
                path_chain      = $attackPath.PathChain
                evaluated_at    = $attackPath.EvaluatedAt
            } -AsNonQuery | Out-Null

            $findings.Add($attackPath)
        }
    }

    if ($PassThru) {
        @($findings)
    }
}
