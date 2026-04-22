function Get-CIEMTestPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Unit', 'E2E')]
        [string]$Suite,

        [Parameter()]
        [string[]]$Path
    )

    $ErrorActionPreference = 'Stop'

    $patternsBySuite = @{
        Unit      = @(
            'Devolutions.CIEM.Admin/Tests/Unit'
            'psu-app/Tests/Unit'
            'psu-app/modules/*/Tests/Unit'
            'psu-app/modules/*/*/Tests/Unit'
        )
        E2E       = @(
            'psu-app/modules/*/Tests/E2E'
            'psu-app/modules/*/*/Tests/E2E'
        )
    }

    $candidates = if ($Path) { $Path } else { $patternsBySuite[$Suite] }
    $resolvedPaths = [System.Collections.Generic.List[string]]::new()

    foreach ($candidate in $candidates) {
        $candidatePath = if ([System.IO.Path]::IsPathRooted($candidate)) {
            $candidate
        }
        else {
            Join-Path $script:RepoRoot $candidate
        }

        if (Test-Path $candidatePath) {
            foreach ($resolvedPath in @(Resolve-Path $candidatePath)) {
                $resolvedPaths.Add($resolvedPath.Path)
            }
        }
    }

    $uniquePaths = @($resolvedPaths | Select-Object -Unique)
    if ($uniquePaths.Count -eq 0) {
        throw "No test paths resolved for suite '$Suite'."
    }

    $uniquePaths
}
