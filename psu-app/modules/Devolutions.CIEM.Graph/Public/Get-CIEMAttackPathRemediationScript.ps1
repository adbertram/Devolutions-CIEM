function Get-CIEMAttackPathRemediationScript {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Id
    )

    $ErrorActionPreference = 'Stop'

    $attackPaths = @(GetCIEMStoredAttackPath -Id $Id)
    if ($attackPaths.Count -ne 1) {
        throw "Cannot render attack path remediation script because attack path '$Id' was not found."
    }
    $attackPath = $attackPaths[0]

    $patterns = @(GetCIEMAttackPatternDefinition | Where-Object { $_.id -eq $attackPath.PatternId })
    if ($patterns.Count -ne 1) {
        throw "Cannot render attack path remediation script because rule '$($attackPath.PatternId)' was not found."
    }

    $renderedScript = ResolveCIEMAttackPathRemediationScript -Pattern $patterns[0] -AttackPath $attackPath
    [string]$renderedScript.Content
}
