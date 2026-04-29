function Get-CIEMAzureEffectiveRoleAssignment {
    [CmdletBinding()]
    [OutputType('CIEMAzureEffectiveRoleAssignment[]')]
    param(
        [Parameter()]
        [int]$Id,

        [Parameter()]
        [string]$PrincipalId,

        [Parameter()]
        [string]$PrincipalType,

        [Parameter()]
        [string]$OriginalPrincipalId,

        [Parameter()]
        [string]$RoleDefinitionId,

        [Parameter()]
        [string]$Scope
    )

    $ErrorActionPreference = 'Stop'

    GetCIEMAzureEntity -Entity 'EffectiveRoleAssignment' -Filters $PSBoundParameters
}
