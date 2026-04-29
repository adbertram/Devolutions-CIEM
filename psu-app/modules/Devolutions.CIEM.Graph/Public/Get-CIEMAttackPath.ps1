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

    $storedParams = @{}
    if ($PatternId) {
        $storedParams.PatternId = $PatternId
    }
    if ($Severity) {
        $storedParams.Severity = $Severity
    }

    $findings = @(GetCIEMStoredAttackPath @storedParams)

    if ($PrincipalId) {
        $findings = @($findings | Where-Object { TestCIEMAttackPathContainsPrincipal -AttackPath $_ -PrincipalId $PrincipalId })
    }

    @($findings)
}
