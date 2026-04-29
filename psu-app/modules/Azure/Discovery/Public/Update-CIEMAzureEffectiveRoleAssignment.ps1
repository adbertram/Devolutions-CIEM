function Update-CIEMAzureEffectiveRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureEffectiveRoleAssignment[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [int]$Id,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$PrincipalDisplayName,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$RoleName,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$PermissionsJson,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ComputedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [switch]$PassThru
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                UpdateCIEMAzureEntity -Entity 'EffectiveRoleAssignment' -Filters @{ Id = $obj.Id } -Values @{
                    PrincipalId = $obj.PrincipalId
                    PrincipalType = $obj.PrincipalType
                    PrincipalDisplayName = $obj.PrincipalDisplayName
                    OriginalPrincipalId = $obj.OriginalPrincipalId
                    OriginalPrincipalType = $obj.OriginalPrincipalType
                    RoleDefinitionId = $obj.RoleDefinitionId
                    RoleName = $obj.RoleName
                    Scope = $obj.Scope
                    PermissionsJson = $obj.PermissionsJson
                    ComputedAt = $obj.ComputedAt
                }
                if ($PassThru) { Get-CIEMAzureEffectiveRoleAssignment -Id $obj.Id }
            }
        } else {
            $values = @{}
            foreach ($paramName in @('PrincipalDisplayName', 'RoleName', 'PermissionsJson', 'ComputedAt')) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $values[$paramName] = $PSBoundParameters[$paramName]
                }
            }
            if ($values.Count -gt 0) {
                UpdateCIEMAzureEntity -Entity 'EffectiveRoleAssignment' -Filters @{ Id = $Id } -Values $values
            }
            if ($PassThru) { Get-CIEMAzureEffectiveRoleAssignment -Id $Id }
        }
    }
}
