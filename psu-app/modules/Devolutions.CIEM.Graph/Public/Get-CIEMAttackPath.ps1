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

function TestCIEMAttackPathContainsPrincipal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMAttackPath]$AttackPath,

        [Parameter(Mandatory)]
        [string]$PrincipalId
    )

    $ErrorActionPreference = 'Stop'

    $nodeIds = @($AttackPath.Path | ForEach-Object { [string]$_.id })
    $nodeIds -contains $PrincipalId
}

function Get-CIEMAttackPath {
    [CmdletBinding()]
    [OutputType('CIEMAttackPath')]
    param(
        [Parameter()]
        [string]$PatternId,

        [Parameter()]
        [ValidateSet('critical', 'high', 'medium', 'low')]
        [string]$Severity,

        [Parameter()]
        [string]$PrincipalId
    )

    $ErrorActionPreference = 'Stop'

    $storedParams = @{}
    if ($PatternId) {
        $storedParams.PatternId = $PatternId
    }
    if ($Severity) {
        $storedParams.Severity = $Severity
    }

    $findings = @(GetCIEMStoredAttackPath @storedParams)

    if ($PrincipalId) {
        $findings = @($findings | Where-Object { TestCIEMAttackPathContainsPrincipal -AttackPath $_ -PrincipalId $PrincipalId })
    }

    @($findings)
}
