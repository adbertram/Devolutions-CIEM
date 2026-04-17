function Get-CIEMAttackPathPattern {
    <#
    .SYNOPSIS
        Returns the attack path rule catalog stored in the CIEM database.
    .DESCRIPTION
        Reads active attack path rule definitions from attack_path_rules.
        Callers use Where-Object for filtering.
    .OUTPUTS
        CIEMAttackPathRule.
    .EXAMPLE
        Get-CIEMAttackPathPattern | Where-Object Severity -eq 'critical'
    #>
    [CmdletBinding()]
    [OutputType('CIEMAttackPathRule')]
    param()

    $ErrorActionPreference = 'Stop'

    @(GetCIEMAttackPatternDefinition)
}
