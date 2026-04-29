function Invoke-CIEMAttackPathRemediation {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$AttackPath
    )

    process {
        $ErrorActionPreference = 'Stop'

        foreach ($item in $AttackPath) {
            if (-not $item) {
                throw 'Cannot remediate attack path because input object is null.'
            }

            if ([string]::IsNullOrWhiteSpace($item.PatternId)) {
                throw 'Cannot remediate attack path because PatternId is empty.'
            }

            if ([string]::IsNullOrWhiteSpace($item.RemediationScript)) {
                throw "Cannot remediate attack path '$($item.PatternId)' because RemediationScript is empty."
            }

            $target = if ([string]::IsNullOrWhiteSpace($item.PatternName)) {
                $item.PatternId
            } else {
                "$($item.PatternName) [$($item.PatternId)]"
            }

            if ($PSCmdlet.ShouldProcess($target, 'Execute attack path remediation script')) {
                $startedAt = Get-Date
                & ([scriptblock]::Create($item.RemediationScript))
                $completedAt = Get-Date

                [pscustomobject]@{
                    PatternId             = $item.PatternId
                    PatternName           = $item.PatternName
                    RemediationScriptPath = $item.RemediationScriptPath
                    StartedAt             = $startedAt
                    CompletedAt           = $completedAt
                    DurationSeconds       = [Math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
                    Status                = 'Completed'
                }
            }
        }
    }
}
