class CIEMAttackPath {
    [string]$Id
    [string]$RuleId
    [string]$PatternId
    [string]$PatternName
    [string]$Severity
    [string]$Category
    [string]$Remediation
    [string]$RemediationScript
    [string]$RemediationScriptPath
    [string]$PsuScriptName
    [string]$PathChain
    [string]$EvaluatedAt
    [PSCustomObject[]]$Path = @()
    [PSCustomObject[]]$Edges = @()

    CIEMAttackPath() {}
}
