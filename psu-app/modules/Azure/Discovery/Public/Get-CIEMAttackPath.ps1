function Get-CIEMAttackPath {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$PatternId,

        [Parameter()]
        [ValidateSet('critical', 'high', 'medium', 'low')]
        [string]$Severity
    )

    $ErrorActionPreference = 'Stop'

    # Load patterns from JSON files
    $patternDir = Join-Path $script:AzureDiscoveryRoot 'Data' 'attack_paths'
    $patternFiles = @(Get-ChildItem -Path $patternDir -Filter '*.json' -File -ErrorAction Stop)

    $patterns = @($patternFiles | ForEach-Object {
        Get-Content $_.FullName -Raw | ConvertFrom-Json
    })

    # Filter patterns by requested criteria
    if ($PatternId) {
        $patterns = @($patterns | Where-Object { $_.id -eq $PatternId })
    }
    if ($Severity) {
        $patterns = @($patterns | Where-Object { $_.severity -eq $Severity })
    }

    # Evaluate each pattern against the graph
    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($pattern in $patterns) {
        $results = @(InvokeCIEMAttackPathEvaluation -Pattern $pattern)
        foreach ($r in $results) {
            $findings.Add($r)
        }
    }

    @($findings)
}
