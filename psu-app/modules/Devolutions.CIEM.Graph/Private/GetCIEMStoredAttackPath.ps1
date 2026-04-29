function GetCIEMStoredAttackPath {
    [CmdletBinding()]
    [OutputType('CIEMAttackPath[]')]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter()]
        [string]$PatternId,

        [Parameter()]
        [ValidateSet('critical', 'high', 'medium', 'low')]
        [string]$Severity
    )

    $ErrorActionPreference = 'Stop'

    $query = @"
SELECT ap.id, ap.rule_id, ap.pattern_name, ap.severity, ap.category, ap.remediation,
       ap.psu_script_name, ap.path_json, ap.edges_json, ap.path_chain, ap.evaluated_at,
       r.remediation_script_path
FROM attack_paths ap
JOIN attack_path_rules r ON r.id = ap.rule_id
"@
    $conditions = @()
    $parameters = @{}

    if ($Id) {
        $conditions += 'ap.id = @id'
        $parameters.id = $Id
    }
    if ($PatternId) {
        $conditions += 'ap.rule_id = @pattern_id'
        $parameters.pattern_id = $PatternId
    }
    if ($Severity) {
        $conditions += 'ap.severity = @severity'
        $parameters.severity = $Severity
    }

    if ($conditions.Count -gt 0) {
        $query += "`nWHERE " + ($conditions -join ' AND ')
    }
    $query += "`nORDER BY ap.severity, ap.pattern_name, ap.id"

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)
    @(foreach ($row in $rows) {
        ConvertFromCIEMAttackPathRow -Row $row
    })
}
