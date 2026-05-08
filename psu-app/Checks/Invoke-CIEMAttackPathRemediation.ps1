param(
    [Parameter(Mandatory)]
    [string]$AttackPathId
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($AttackPathId)) {
    throw 'Cannot execute attack path remediation because AttackPathId is empty.'
}

Devolutions.CIEM\Invoke-CIEMAttackPathRemediation -AttackPathId $AttackPathId -Confirm:$false
