# Attack path: {{PATTERN_NAME}}
# Finding: {{PATH_CHAIN}}
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Assert-CIEMAttackPathRemediationScriptResolved {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $scriptContent = $ScriptBlock.ToString()
    $tokenPattern = ([regex]::Escape((([char]123).ToString() + [char]123)) + '[A-Z0-9_]+' + [regex]::Escape((([char]125).ToString() + [char]125)))
    $unresolvedTokens = @([regex]::Matches($scriptContent, $tokenPattern) | ForEach-Object { $_.Value } | Sort-Object -Unique)
    if ($unresolvedTokens.Count -gt 0) {
        throw "CIEM remediation template contains unresolved tokens: $($unresolvedTokens -join ', '). Render the template from an attack path before execution."
    }
}

Assert-CIEMAttackPathRemediationScriptResolved -ScriptBlock $MyInvocation.MyCommand.ScriptBlock

az account show --only-show-errors | Out-Null

{{CIEM_ATTACK_PATH_SCRIPT_BODY}}

Write-Output 'Remediation commands completed. Rerun Azure discovery in CIEM.'
