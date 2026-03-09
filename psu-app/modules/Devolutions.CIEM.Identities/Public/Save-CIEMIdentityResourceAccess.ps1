function Save-CIEMIdentityResourceAccess {
    <#
    .SYNOPSIS
        Inserts identity-resource access rows into the database.
    .DESCRIPTION
        Persists computed identity-to-resource access mappings. Accepts individual
        parameters (ByProperties) or a pipeline/array of CIEMIdentityResourceAccess
        objects (InputObject). Uses INSERT (AUTOINCREMENT id).
    .PARAMETER ProviderId
        Provider identifier (e.g. 'azure').
    .PARAMETER IdentityId
        The identity's unique ID (Entra object ID).
    .PARAMETER IdentityName
        Display name of the identity.
    .PARAMETER IdentityType
        Type of identity (User, Group, ServicePrincipal).
    .PARAMETER ResourceId
        ARM resource ID of the specific resource instance.
    .PARAMETER ResourceName
        Display name of the resource.
    .PARAMETER ResourceType
        Resource type category (VirtualMachine, NetworkSecurityGroup, etc.).
    .PARAMETER Relationship
        Access level: CAN_READ, CAN_WRITE, or CAN_MANAGE.
    .PARAMETER Scope
        The role assignment scope that grants this access.
    .PARAMETER IsInherited
        Whether access is inherited via group membership.
    .PARAMETER EffectiveIdentityId
        The group through which access is inherited (null if direct).
    .PARAMETER EffectiveIdentityName
        Display name of the effective identity group.
    .PARAMETER RoleName
        The Azure role name (Reader, Contributor, etc.).
    .PARAMETER InputObject
        One or more CIEMIdentityResourceAccess objects (pipeline-compatible).
    .EXAMPLE
        Save-CIEMIdentityResourceAccess -ProviderId azure -IdentityId $userId -IdentityName 'John' -IdentityType User -ResourceId $vmId -ResourceName 'vm1' -ResourceType VirtualMachine -Relationship CAN_READ -Scope '/subscriptions/abc' -IsInherited $false -RoleName 'Reader'
    .EXAMPLE
        $rows | Save-CIEMIdentityResourceAccess
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Bulk insert operation')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$ProviderId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$IdentityId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$IdentityName,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$IdentityType,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$ResourceId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ResourceName,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$ResourceType,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [ValidateSet('CAN_READ', 'CAN_WRITE', 'CAN_MANAGE')]
        [string]$Relationship,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Scope,

        [Parameter(ParameterSetName = 'ByProperties')]
        [bool]$IsInherited = $false,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$EffectiveIdentityId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$EffectiveIdentityName,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$RoleName,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMIdentityResourceAccess[]]$InputObject
    )

    process {
        $now = (Get-Date).ToString('o')

        $rows = if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            $InputObject
        } else {
            $obj = [CIEMIdentityResourceAccess]::new()
            $obj.ProviderId = $ProviderId
            $obj.IdentityId = $IdentityId
            $obj.IdentityName = $IdentityName
            $obj.IdentityType = $IdentityType
            $obj.ResourceId = $ResourceId
            $obj.ResourceName = $ResourceName
            $obj.ResourceType = $ResourceType
            $obj.Relationship = $Relationship
            $obj.Scope = $Scope
            $obj.IsInherited = $IsInherited
            $obj.EffectiveIdentityId = $EffectiveIdentityId
            $obj.EffectiveIdentityName = $EffectiveIdentityName
            $obj.RoleName = $RoleName
            $obj.ComputedAt = $now
            @($obj)
        }

        foreach ($row in $rows) {
            $computedAt = if ($row.ComputedAt) { $row.ComputedAt } else { $now }

            Invoke-CIEMQuery -Query @"
INSERT INTO identity_resource_access
    (provider_id, identity_id, identity_name, identity_type, resource_id, resource_name, resource_type, relationship, scope, is_inherited, effective_identity_id, effective_identity_name, role_name, computed_at)
VALUES
    (@provider_id, @identity_id, @identity_name, @identity_type, @resource_id, @resource_name, @resource_type, @relationship, @scope, @is_inherited, @effective_identity_id, @effective_identity_name, @role_name, @computed_at)
"@ -Parameters @{
                provider_id             = $row.ProviderId
                identity_id             = $row.IdentityId
                identity_name           = $row.IdentityName
                identity_type           = $row.IdentityType
                resource_id             = $row.ResourceId
                resource_name           = $row.ResourceName
                resource_type           = $row.ResourceType
                relationship            = $row.Relationship
                scope                   = $row.Scope
                is_inherited            = [int]$row.IsInherited
                effective_identity_id   = $row.EffectiveIdentityId
                effective_identity_name = $row.EffectiveIdentityName
                role_name               = $row.RoleName
                computed_at             = $computedAt
            } -AsNonQuery | Out-Null
        }
    }
}
