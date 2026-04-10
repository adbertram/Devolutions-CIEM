function GetCIEMAttackPatternDefinition {
    <#
    .SYNOPSIS
        Loads raw attack path pattern definitions from shipped JSON files.
    .DESCRIPTION
        Tolerant reader — a single malformed file is logged and skipped, allowing
        siblings to load. Used by both Get-CIEMAttackPath (evaluator) and
        Get-CIEMAttackPathPattern (catalog projection).
    #>
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $patternDir = Join-Path $script:GraphRoot 'Data' 'attack_paths'
    $patternFiles = @(Get-ChildItem -Path $patternDir -Filter '*.json' -File)

    $patterns = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $patternFiles) {
        try {
            $raw = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $patterns.Add($raw)
        }
        catch {
            Write-CIEMLog -Message "GetCIEMAttackPatternDefinition: failed to parse $($file.Name): $($_.Exception.Message)" -Severity ERROR -Component 'Graph'
            continue
        }
    }
    @($patterns)
}
