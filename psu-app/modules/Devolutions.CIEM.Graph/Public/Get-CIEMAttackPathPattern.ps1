function Get-CIEMAttackPathPattern {
    <#
    .SYNOPSIS
        Returns the catalog of attack path patterns shipped with the module.
    .DESCRIPTION
        Reads pattern definitions from JSON files under
        modules/Devolutions.CIEM.Graph/Data/attack_paths and returns a flat
        projection suitable for catalog display. Tolerant of individual malformed
        files (logged and skipped). Callers use Where-Object for filtering.
    .OUTPUTS
        PSCustomObject with PSTypeName 'CIEMAttackPathPattern' and properties:
        Id, Name, Severity, Category, Description, StepCount.
    .EXAMPLE
        Get-CIEMAttackPathPattern | Where-Object Severity -eq 'critical'
    #>
    [CmdletBinding()]
    [OutputType('CIEMAttackPathPattern')]
    param()

    $ErrorActionPreference = 'Stop'

    $patterns = @(GetCIEMAttackPatternDefinition | ForEach-Object {
        $stepCount = if ($_.steps) { @($_.steps).Count } else { 0 }
        [pscustomobject]@{
            PSTypeName  = 'CIEMAttackPathPattern'
            Id          = $_.id
            Name        = $_.name
            Severity    = $_.severity
            Category    = $_.category
            Description = $_.description
            StepCount   = [int]$stepCount
        }
    })

    @($patterns)
}
