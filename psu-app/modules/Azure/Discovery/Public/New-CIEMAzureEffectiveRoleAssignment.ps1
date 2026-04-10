function New-CIEMAzureEffectiveRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a data record in database')]
    [OutputType('CIEMAzureEffectiveRoleAssignment[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$PrincipalId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$PrincipalType,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$PrincipalDisplayName,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$OriginalPrincipalId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$OriginalPrincipalType,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$RoleDefinitionId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$RoleName,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Scope,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$PermissionsJson,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ComputedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                New-CIEMAzureEffectiveRoleAssignment `
                    -PrincipalId $obj.PrincipalId `
                    -PrincipalType $obj.PrincipalType `
                    -PrincipalDisplayName $obj.PrincipalDisplayName `
                    -OriginalPrincipalId $obj.OriginalPrincipalId `
                    -OriginalPrincipalType $obj.OriginalPrincipalType `
                    -RoleDefinitionId $obj.RoleDefinitionId `
                    -RoleName $obj.RoleName `
                    -Scope $obj.Scope `
                    -PermissionsJson $obj.PermissionsJson `
                    -ComputedAt $obj.ComputedAt
            }
            return
        }

        if (-not $ComputedAt) { $ComputedAt = (Get-Date).ToString('o') }

        $inserted = Invoke-CIEMQuery -Query "INSERT INTO azure_effective_role_assignments (principal_id, principal_type, principal_display_name, original_principal_id, original_principal_type, role_definition_id, role_name, scope, permissions_json, computed_at) VALUES (@principal_id, @principal_type, @principal_display_name, @original_principal_id, @original_principal_type, @role_definition_id, @role_name, @scope, @permissions_json, @computed_at) RETURNING id" -Parameters @{ principal_id = $PrincipalId; principal_type = $PrincipalType; principal_display_name = $PrincipalDisplayName; original_principal_id = $OriginalPrincipalId; original_principal_type = $OriginalPrincipalType; role_definition_id = $RoleDefinitionId; role_name = $RoleName; scope = $Scope; permissions_json = $PermissionsJson; computed_at = $ComputedAt }

        Get-CIEMAzureEffectiveRoleAssignment -Id $inserted.id
    }
}
