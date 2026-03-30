function Save-CIEMAzureEffectiveRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation for bulk data')]
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

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$ComputedAt,

        [Parameter()]
        $Connection,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        $ErrorActionPreference = 'Stop'
        $sql = "INSERT OR REPLACE INTO azure_effective_role_assignments (principal_id, principal_type, principal_display_name, original_principal_id, original_principal_type, role_definition_id, role_name, scope, permissions_json, computed_at) VALUES (@principal_id, @principal_type, @principal_display_name, @original_principal_id, @original_principal_type, @role_definition_id, @role_name, @scope, @permissions_json, @computed_at)"

        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $queryParams = @{
                    Query      = $sql
                    Parameters = @{
                        principal_id            = $obj.PrincipalId
                        principal_type          = $obj.PrincipalType
                        principal_display_name  = $obj.PrincipalDisplayName
                        original_principal_id   = $obj.OriginalPrincipalId
                        original_principal_type = $obj.OriginalPrincipalType
                        role_definition_id      = $obj.RoleDefinitionId
                        role_name               = $obj.RoleName
                        scope                   = $obj.Scope
                        permissions_json        = $obj.PermissionsJson
                        computed_at             = $obj.ComputedAt
                    }
                    AsNonQuery = $true
                }
                if ($Connection) { $queryParams.Connection = $Connection }
                Invoke-CIEMQuery @queryParams | Out-Null
            }
        } else {
            $queryParams = @{
                Query      = $sql
                Parameters = @{
                    principal_id            = $PrincipalId
                    principal_type          = $PrincipalType
                    principal_display_name  = $PrincipalDisplayName
                    original_principal_id   = $OriginalPrincipalId
                    original_principal_type = $OriginalPrincipalType
                    role_definition_id      = $RoleDefinitionId
                    role_name               = $RoleName
                    scope                   = $Scope
                    permissions_json        = $PermissionsJson
                    computed_at             = $ComputedAt
                }
                AsNonQuery = $true
            }
            if ($Connection) { $queryParams.Connection = $Connection }
            Invoke-CIEMQuery @queryParams | Out-Null
        }
    }
}
