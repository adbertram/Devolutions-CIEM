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

    # Load patterns from JSON files
    $patternDir = Join-Path $script:GraphRoot 'Data' 'attack_paths'
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
    $identityKinds = @('EntraUser', 'EntraServicePrincipal', 'EntraGroup', 'EntraManagedIdentity')
    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($pattern in $patterns) {
        $evalParams = @{ Pattern = $pattern }
        # Constrain seed nodes for identity-first patterns when PrincipalId is specified
        if ($PrincipalId) {
            $firstKinds = @($pattern.steps[0].kind)
            if ($firstKinds | Where-Object { $_ -in $identityKinds }) {
                $evalParams.SeedNodeId = $PrincipalId
            }
        }
        $results = @(InvokeCIEMAttackPathEvaluation @evalParams)
        foreach ($r in $results) {
            $findings.Add($r)
        }
    }

    # Post-filter: only return paths that include the specified principal
    if ($PrincipalId) {
        $findings = [System.Collections.Generic.List[PSCustomObject]]@(
            $findings | Where-Object {
                if (-not $_.Path) { return $false }
                $nodeIds = @($_.Path | ForEach-Object { $_.id })
                $PrincipalId -in $nodeIds
            }
        )
    }

    @($findings)
}
