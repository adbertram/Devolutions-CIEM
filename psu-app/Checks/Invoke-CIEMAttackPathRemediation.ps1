param(
    [Parameter(Mandatory)]
    [string]$AttackPathId
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($AttackPathId)) {
    throw 'Cannot execute attack path remediation because AttackPathId is empty.'
}

$attackPaths = @(Devolutions.CIEM\Get-CIEMAttackPath | Where-Object { $_.Id -eq $AttackPathId })
if ($attackPaths.Count -ne 1) {
    throw "Cannot execute attack path remediation because attack path '$AttackPathId' was not found."
}

$attackPath = $attackPaths[0]
$scriptText = Devolutions.CIEM\Get-CIEMAttackPathRemediationScript -Id $AttackPathId
$startedAt = Get-Date
& ([scriptblock]::Create($scriptText))
$completedAt = Get-Date

[pscustomobject]@{
    AttackPathId     = $AttackPathId
    PatternId        = $attackPath.PatternId
    PatternName      = $attackPath.PatternName
    StartedAt        = $startedAt
    CompletedAt      = $completedAt
    DurationSeconds  = [Math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
    Status           = 'Completed'
}
