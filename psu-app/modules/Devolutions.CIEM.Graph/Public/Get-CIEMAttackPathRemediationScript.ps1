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

    if ([string]::IsNullOrWhiteSpace($attackPath.PsuScriptName)) {
        throw "Cannot render attack path remediation script because attack path '$Id' has no PSU script reference."
    }

    $patterns = @(GetCIEMAttackPatternDefinition | Where-Object { $_.id -eq $attackPath.PatternId })
    if ($patterns.Count -ne 1) {
        throw "Cannot render attack path remediation script because rule '$($attackPath.PatternId)' was not found."
    }

    $scripts = @(Get-PSUScript -Integrated | Where-Object { $null -ne $_ })
    $matchingScripts = @($scripts | Where-Object {
        $names = @(
            [string]$_.Name
            [string]$_.FullPath
            [string]$_.Path
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $names | Where-Object {
            ($_ -replace '\.ps1$', '') -eq $attackPath.PsuScriptName
        }
    })
    if ($matchingScripts.Count -ne 1) {
        throw "Cannot render attack path remediation script because PSU script '$($attackPath.PsuScriptName)' was not found."
    }

    $content = [string]$matchingScripts[0].Content
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "Cannot render attack path remediation script because PSU script '$($attackPath.PsuScriptName)' has empty content."
    }

    ResolveCIEMAttackPathScriptContent -Pattern $patterns[0] -AttackPath $attackPath -ScriptContent $content
}
