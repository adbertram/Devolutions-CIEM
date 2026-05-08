function Invoke-CIEMAttackPathRemediation {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$AttackPathId
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($AttackPathId)) {
        throw 'Cannot remediate attack path because AttackPathId is empty.'
    }

    $attackPaths = @(Get-CIEMAttackPath | Where-Object { [string]$_.Id -eq $AttackPathId })
    if ($attackPaths.Count -ne 1) {
        throw "Cannot remediate attack path because attack path '$AttackPathId' was not found."
    }

    $attackPath = $attackPaths[0]
    $scriptText = Get-CIEMAttackPathRemediationScript -Id $AttackPathId
    if ([string]::IsNullOrWhiteSpace($scriptText)) {
        throw "Cannot remediate attack path '$AttackPathId' because rendered remediation script is empty."
    }

    $target = "$($attackPath.PatternName) [$($attackPath.PatternId)]"
    if ($PSCmdlet.ShouldProcess($target, 'Execute attack path remediation script')) {
        $startedAt = Get-Date
        & ([scriptblock]::Create($scriptText))
        $completedAt = Get-Date

        [pscustomobject]@{
            AttackPathId          = $AttackPathId
            PatternId             = $attackPath.PatternId
            PatternName           = $attackPath.PatternName
            RemediationScriptPath = $attackPath.RemediationScriptPath
            StartedAt             = $startedAt
            CompletedAt           = $completedAt
            DurationSeconds       = [Math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
            Status                = 'Completed'
        }
    }
}
