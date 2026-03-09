function Get-CIEMIdentityResourceAccess {
    <#
    .SYNOPSIS
        Retrieves identity-resource access mappings from the database.
    .DESCRIPTION
        Queries the identity_resource_access table with optional filters.
        Returns typed CIEMIdentityResourceAccess objects.
    .PARAMETER ProviderId
        Filter by provider (e.g. 'azure').
    .PARAMETER IdentityId
        Filter by identity ID.
    .PARAMETER ResourceId
        Filter by resource ARM ID.
    .PARAMETER ResourceType
        Filter by resource type (e.g. 'VirtualMachine').
    .PARAMETER Relationship
        Filter by access level (CAN_READ, CAN_WRITE, CAN_MANAGE).
    .OUTPUTS
        [CIEMIdentityResourceAccess[]]
    .EXAMPLE
        Get-CIEMIdentityResourceAccess -ProviderId azure
    .EXAMPLE
        Get-CIEMIdentityResourceAccess -IdentityId $userId
    .EXAMPLE
        Get-CIEMIdentityResourceAccess -ResourceId $vmArmId
    #>
    [CmdletBinding()]
    [OutputType('CIEMIdentityResourceAccess[]')]
    param(
        [Parameter()]
        [string]$ProviderId,

        [Parameter()]
        [string]$IdentityId,

        [Parameter()]
        [string]$ResourceId,

        [Parameter()]
        [string]$ResourceType,

        [Parameter()]
        [ValidateSet('CAN_READ', 'CAN_WRITE', 'CAN_MANAGE')]
        [string]$Relationship
    )

    $where  = @('1=1')
    $params = @{}

    if ($ProviderId)   { $where += 'provider_id = @provider_id';   $params.provider_id   = $ProviderId }
    if ($IdentityId)   { $where += 'identity_id = @identity_id';   $params.identity_id   = $IdentityId }
    if ($ResourceId)   { $where += 'resource_id = @resource_id';   $params.resource_id   = $ResourceId }
    if ($ResourceType) { $where += 'resource_type = @resource_type'; $params.resource_type = $ResourceType }
    if ($Relationship) { $where += 'relationship = @relationship'; $params.relationship   = $Relationship }

    $query = "SELECT * FROM identity_resource_access WHERE $($where -join ' AND ') ORDER BY identity_id, resource_type, relationship"
    $rows  = Invoke-CIEMQuery -Query $query -Parameters $params

    foreach ($row in $rows) {
        $obj = [CIEMIdentityResourceAccess]::new()
        $obj.Id                    = $row.id
        $obj.ProviderId            = $row.provider_id
        $obj.IdentityId            = $row.identity_id
        $obj.IdentityName          = $row.identity_name
        $obj.IdentityType          = $row.identity_type
        $obj.ResourceId            = $row.resource_id
        $obj.ResourceName          = $row.resource_name
        $obj.ResourceType          = $row.resource_type
        $obj.Relationship          = $row.relationship
        $obj.Scope                 = $row.scope
        $obj.IsInherited           = [bool]$row.is_inherited
        $obj.EffectiveIdentityId   = $row.effective_identity_id
        $obj.EffectiveIdentityName = $row.effective_identity_name
        $obj.RoleName              = $row.role_name
        $obj.ComputedAt            = $row.computed_at
        $obj
    }
}
