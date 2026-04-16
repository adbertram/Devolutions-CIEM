class CIEMAttackPath {
    [string]$PatternId
    [string]$PatternName
    [string]$Severity
    [string]$Category
    [string]$Remediation
    [string]$RemediationScript
    [string]$RemediationScriptPath
    [PSCustomObject[]]$Path = @()
    [PSCustomObject[]]$Edges = @()

    CIEMAttackPath() {}
}
