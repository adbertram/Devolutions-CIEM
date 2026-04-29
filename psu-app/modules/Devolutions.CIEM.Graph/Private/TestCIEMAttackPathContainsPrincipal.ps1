function TestCIEMAttackPathContainsPrincipal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$AttackPath,

        [Parameter(Mandatory)]
        [string]$PrincipalId
    )

    $ErrorActionPreference = 'Stop'

    $nodeIds = @($AttackPath.Path | ForEach-Object { [string]$_.id })
    $nodeIds -contains $PrincipalId
}
