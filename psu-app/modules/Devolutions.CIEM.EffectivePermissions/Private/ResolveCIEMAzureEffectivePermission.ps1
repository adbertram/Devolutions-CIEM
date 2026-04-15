function ResolveCIEMAzureEffectivePermission {
    [CmdletBinding()]
    [OutputType([CIEMEffectivePermission[]])]
    param(
        [Parameter()]
        [bool]$IncludeInherited = $true
    )

    $ErrorActionPreference = 'Stop'

    function NewEvidence {
        param(
            [Parameter(Mandatory)]
            [string]$Id,

            [Parameter(Mandatory)]
            [string]$SourceApi,

            [Parameter(Mandatory)]
            [string]$SourceRecordId,

            [Parameter()]
            [AllowNull()]
            [string]$DataJson,

            [Parameter()]
            [AllowNull()]
            [string]$CollectedAt
        )

        $ErrorActionPreference = 'Stop'

        $e = [CIEMEffectivePermissionEvidence]::new()
        $e.Id = $Id
        $e.SourceSystem = 'Azure'
        $e.SourceApi = $SourceApi
        $e.SourceRecordId = $SourceRecordId
        $e.CollectedAt = $CollectedAt
        $e.DataJson = $DataJson
        $e
    }

    function NewPrincipal {
        param([object]$Row)
        $ErrorActionPreference = 'Stop'
        $p = [CIEMEffectivePrincipal]::new()
        $p.Id = $Row.principal_id
        $p.DisplayName = $Row.principal_name
        $p.Type = ResolveCIEMPrincipalType -Kind $Row.principal_kind
        $p.NativeType = $Row.principal_kind
        $p.ProviderAccountId = $Row.principal_subscription_id
        $p.PropertiesJson = $Row.principal_properties
        $p
    }

    function NewTarget {
        param([object]$Row)
        $ErrorActionPreference = 'Stop'

        $region = $null
        if ($Row.target_properties) {
            $targetProperties = $Row.target_properties | ConvertFrom-Json -ErrorAction Stop
            $region = $targetProperties.location
        }

        $r = [CIEMEffectiveResource]::new()
        $r.Id = $Row.target_id
        $r.DisplayName = $Row.target_name
        $r.Type = $Row.target_kind
        $r.ProviderAccountId = $Row.target_subscription_id
        $r.Region = $region
        $r.PropertiesJson = $Row.target_properties
        $r
    }

    function NewPathStep {
        param(
            [Parameter(Mandatory)]
            [CIEMPermissionPathType]$Type,
            [Parameter()]
            [AllowNull()]
            [string]$SourceId,
            [Parameter()]
            [AllowNull()]
            [string]$SourceName,
            [Parameter()]
            [AllowNull()]
            [string]$TargetId,
            [Parameter()]
            [AllowNull()]
            [string]$TargetName,
            [Parameter(Mandatory)]
            [string]$Description,
            [Parameter(Mandatory)]
            [string]$EvidenceId
        )

        $ErrorActionPreference = 'Stop'

        $s = [CIEMEffectivePermissionPathStep]::new()
        $s.Order = 1
        $s.Type = $Type
        $s.SourceId = $SourceId
        $s.SourceName = $SourceName
        $s.TargetId = $TargetId
        $s.TargetName = $TargetName
        $s.Description = $Description
        $s.EvidenceId = $EvidenceId
        $s
    }

    $results = [System.Collections.Generic.List[object]]::new()

    $roleKinds = if ($IncludeInherited) { "'HasRole','InheritedRole'" } else { "'HasRole'" }
    $sql = @"
SELECT
    e.id AS edge_id,
    e.kind AS edge_kind,
    e.properties AS edge_properties,
    e.collected_at AS edge_collected_at,
    p.id AS principal_id,
    p.kind AS principal_kind,
    p.display_name AS principal_name,
    p.subscription_id AS principal_subscription_id,
    p.properties AS principal_properties,
    t.id AS target_id,
    t.kind AS target_kind,
    t.display_name AS target_name,
    t.subscription_id AS target_subscription_id,
    t.properties AS target_properties
FROM graph_edges e
JOIN graph_nodes p ON p.id = e.source_id
JOIN graph_nodes t ON t.id = e.target_id
WHERE e.kind IN ($roleKinds)
"@

    foreach ($row in @(Invoke-CIEMQuery -Query $sql)) {
        $props = if ($row.edge_properties) { $row.edge_properties | ConvertFrom-Json -ErrorAction Stop } else { [pscustomobject]@{} }
        $evidenceId = "azure-graph-edge-$($row.edge_id)"
        $privileged = if ($null -ne $props.privileged) { [bool]$props.privileged } else { $false }

        $permission = [CIEMEffectivePermission]::new()
        $permission.Provider = [CIEMEffectivePermissionProvider]::Azure
        $permission.Principal = NewPrincipal -Row $row
        $target = NewTarget -Row $row
        $permission.Target = $target
        $permission.Privileged = $privileged
        $permission.CollectedAt = $row.edge_collected_at

        $entitlement = [CIEMEffectiveEntitlement]::new()
        $entitlement.Id = $props.role_definition_id
        $entitlement.Name = $props.role_name
        $entitlement.Type = [CIEMEntitlementType]::RoleAssignment
        $entitlement.NativeType = 'AzureRBAC'
        $entitlement.ScopeId = $row.target_id
        $entitlement.ScopeType = $row.target_kind
        $entitlement.PropertiesJson = $row.edge_properties
        $permission.Entitlement = $entitlement

        $permission.Actions = @(ConvertCIEMEffectivePermissionAction -Provider Azure -PermissionsJson $props.permissions_json -EntitlementName $props.role_name -Privileged:$privileged -TargetType $target.Type)

        if ($row.edge_kind -eq 'InheritedRole') {
            $permission.Path = @(
                NewPathStep -Type GroupInherited `
                    -SourceId $props.inherited_from `
                    -SourceName $props.inherited_from_name `
                    -TargetId $row.target_id `
                    -TargetName $row.target_name `
                    -Description "Inherited role assignment through group '$($props.inherited_from_name)'" `
                    -EvidenceId $evidenceId
            )
        } else {
            $permission.Path = @(
                NewPathStep -Type Direct `
                    -SourceId $row.principal_id `
                    -SourceName $row.principal_name `
                    -TargetId $row.target_id `
                    -TargetName $row.target_name `
                    -Description 'Direct role assignment' `
                    -EvidenceId $evidenceId
            )
        }

        $permission.Evidence = @(
            NewEvidence -Id $evidenceId -SourceApi 'graph_edges' -SourceRecordId ([string]$row.edge_id) -DataJson $row.edge_properties -CollectedAt $row.edge_collected_at
        )

        $results.Add($permission)
    }

    $directorySql = @"
SELECT
    e.id AS edge_id,
    e.kind AS edge_kind,
    e.properties AS edge_properties,
    e.collected_at AS edge_collected_at,
    p.id AS principal_id,
    p.kind AS principal_kind,
    p.display_name AS principal_name,
    p.subscription_id AS principal_subscription_id,
    p.properties AS principal_properties,
    t.id AS target_id,
    t.kind AS target_kind,
    t.display_name AS target_name,
    t.subscription_id AS target_subscription_id,
    t.properties AS target_properties
FROM graph_edges e
JOIN graph_nodes p ON p.id = e.source_id
JOIN graph_nodes t ON t.id = e.target_id
WHERE e.kind = 'HasRoleMember'
"@

    foreach ($row in @(Invoke-CIEMQuery -Query $directorySql)) {
        $evidenceId = "azure-graph-edge-$($row.edge_id)"
        $target = NewTarget -Row $row
        $actions = @(ConvertCIEMEffectivePermissionAction -Provider Azure -EntitlementName $row.target_name -NativeAction @($row.target_name) -TargetType $target.Type)
        $privileged = @($actions | Where-Object { $_.AccessLevel -eq [CIEMAccessLevel]::PermissionAdmin }).Count -gt 0

        $permission = [CIEMEffectivePermission]::new()
        $permission.Provider = [CIEMEffectivePermissionProvider]::Azure
        $permission.Principal = NewPrincipal -Row $row
        $permission.Target = $target
        $permission.Actions = $actions
        $permission.Privileged = $privileged
        $permission.CollectedAt = $row.edge_collected_at

        $entitlement = [CIEMEffectiveEntitlement]::new()
        $entitlement.Id = $row.target_id
        $entitlement.Name = $row.target_name
        $entitlement.Type = [CIEMEntitlementType]::DirectoryRole
        $entitlement.NativeType = 'EntraDirectoryRole'
        $entitlement.ScopeId = $row.target_id
        $entitlement.ScopeType = $row.target_kind
        $entitlement.PropertiesJson = $row.target_properties
        $permission.Entitlement = $entitlement

        $permission.Path = @(
            NewPathStep -Type Direct -SourceId $row.principal_id -SourceName $row.principal_name -TargetId $row.target_id -TargetName $row.target_name -Description 'Directory role membership' -EvidenceId $evidenceId
        )
        $permission.Evidence = @(
            NewEvidence -Id $evidenceId -SourceApi 'graph_edges' -SourceRecordId ([string]$row.edge_id) -DataJson $row.edge_properties -CollectedAt $row.edge_collected_at
        )

        $results.Add($permission)
    }

    $consentSql = @"
SELECT
    e.id AS edge_id,
    e.kind AS edge_kind,
    e.properties AS edge_properties,
    e.collected_at AS edge_collected_at,
    p.id AS principal_id,
    p.kind AS principal_kind,
    p.display_name AS principal_name,
    p.subscription_id AS principal_subscription_id,
    p.properties AS principal_properties,
    t.id AS target_id,
    t.kind AS target_kind,
    t.display_name AS target_name,
    t.subscription_id AS target_subscription_id,
    t.properties AS target_properties
FROM graph_edges e
JOIN graph_nodes p ON p.id = e.source_id
JOIN graph_nodes t ON t.id = e.target_id
WHERE e.kind IN ('HasAppRoleAssignment','HasOAuthGrant')
"@

    foreach ($row in @(Invoke-CIEMQuery -Query $consentSql)) {
        $props = if ($row.edge_properties) { $row.edge_properties | ConvertFrom-Json -ErrorAction Stop } else { [pscustomobject]@{} }
        $evidenceId = "azure-graph-edge-$($row.edge_id)"
        $isOAuth = $row.edge_kind -eq 'HasOAuthGrant'
        $nativeActions = if ($isOAuth -and $props.scope) { @($props.scope -split '\s+' | Where-Object { $_ }) } elseif ($props.app_role_id) { @($props.app_role_id) } else { @() }

        $permission = [CIEMEffectivePermission]::new()
        $permission.Provider = [CIEMEffectivePermissionProvider]::Azure
        $permission.Principal = NewPrincipal -Row $row
        $target = NewTarget -Row $row
        $permission.Target = $target
        $permission.Actions = @(ConvertCIEMEffectivePermissionAction -Provider Azure -EntitlementName $row.edge_kind -NativeAction $nativeActions -TargetType $target.Type)
        $permission.Privileged = @($permission.Actions | Where-Object { $_.AccessLevel -in @([CIEMAccessLevel]::Manage, [CIEMAccessLevel]::PermissionAdmin, [CIEMAccessLevel]::SecretAccess) }).Count -gt 0
        $permission.CollectedAt = $row.edge_collected_at

        $entitlement = [CIEMEffectiveEntitlement]::new()
        $entitlement.Id = if ($isOAuth) { $props.grant_id } else { $props.assignment_id }
        $entitlement.Name = if ($isOAuth) { 'OAuth Grant' } else { 'App Role Assignment' }
        $entitlement.Type = if ($isOAuth) { [CIEMEntitlementType]::OAuthGrant } else { [CIEMEntitlementType]::AppRoleAssignment }
        $entitlement.NativeType = if ($isOAuth) { 'oauth2PermissionGrant' } else { 'appRoleAssignment' }
        $entitlement.ScopeId = $row.target_id
        $entitlement.ScopeType = $row.target_kind
        $entitlement.PropertiesJson = $row.edge_properties
        $permission.Entitlement = $entitlement

        $permission.Path = @(
            NewPathStep -Type $(if ($isOAuth) { [CIEMPermissionPathType]::OAuthGrant } else { [CIEMPermissionPathType]::AppRole }) `
                -SourceId $row.principal_id `
                -SourceName $row.principal_name `
                -TargetId $row.target_id `
                -TargetName $row.target_name `
                -Description $entitlement.Name `
                -EvidenceId $evidenceId
        )
        $permission.Evidence = @(
            NewEvidence -Id $evidenceId -SourceApi 'graph_edges' -SourceRecordId ([string]$row.edge_id) -DataJson $row.edge_properties -CollectedAt $row.edge_collected_at
        )

        $results.Add($permission)
    }

    @($results)
}
