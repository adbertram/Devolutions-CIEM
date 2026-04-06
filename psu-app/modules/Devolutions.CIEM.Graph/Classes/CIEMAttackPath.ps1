class CIEMAttackPath {
    [string]$PatternId
    [string]$PatternName
    [string]$Severity
    [string]$Category
    [PSCustomObject[]]$Path = @()
    [PSCustomObject[]]$Edges = @()

    CIEMAttackPath() {}
}
