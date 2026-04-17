class CIEMAttackPathRule {
    [string]$Id
    [string]$Name
    [string]$Severity
    [string]$Category
    [string]$Description
    [string]$Remediation
    [string]$RemediationScriptPath
    [string]$PsuScriptName
    [object[]]$Steps = @()
    [int]$StepCount
    [bool]$Disabled
    [string]$UpdatedAt

    CIEMAttackPathRule() {}
}
