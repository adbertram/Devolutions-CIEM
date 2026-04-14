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
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    begin {
        $ErrorActionPreference = 'Stop'
        $items = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $items.Add([pscustomobject]@{
                    PrincipalId = $item.PrincipalId
                    PrincipalType = $item.PrincipalType
                    PrincipalDisplayName = $item.PrincipalDisplayName
                    OriginalPrincipalId = $item.OriginalPrincipalId
                    OriginalPrincipalType = $item.OriginalPrincipalType
                    RoleDefinitionId = $item.RoleDefinitionId
                    RoleName = $item.RoleName
                    Scope = $item.Scope
                    PermissionsJson = $item.PermissionsJson
                    ComputedAt = $item.ComputedAt
                })
            }
            return
        }

        $items.Add([pscustomobject]@{
            PrincipalId = $PrincipalId
            PrincipalType = $PrincipalType
            PrincipalDisplayName = $PrincipalDisplayName
            OriginalPrincipalId = $OriginalPrincipalId
            OriginalPrincipalType = $OriginalPrincipalType
            RoleDefinitionId = $RoleDefinitionId
            RoleName = $RoleName
            Scope = $Scope
            PermissionsJson = $PermissionsJson
            ComputedAt = $ComputedAt
        })
    }

    end {
        if ($items.Count -eq 0) {
            return
        }

        SaveCIEMAzureTable -Entity 'EffectiveRoleAssignment' -Items $items.ToArray() -Connection $Connection
    }
}
