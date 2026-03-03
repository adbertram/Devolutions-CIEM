function Get-CIEMPermissionRelationship {
    <#
    .SYNOPSIS
        Queries permission_relationships table and returns grouped entries for graph edge computation.
    .DESCRIPTION
        Returns objects with targetType, relationship, and permissions (array) properties,
        matching the structure previously loaded from permission_relationships.json.
        Grouped so Add-ComputedPermissionEdges receives one entry per (targetType, relationship) pair.
    .PARAMETER TargetType
        Filter by resource target type (e.g., VirtualMachine, Subscription).
    .PARAMETER Relationship
        Filter by relationship type (CAN_READ, CAN_WRITE, CAN_MANAGE).
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$TargetType,

        [Parameter()]
        [ValidateSet('CAN_READ', 'CAN_WRITE', 'CAN_MANAGE')]
        [string]$Relationship
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @()
    $params = @{}

    if ($PSBoundParameters.ContainsKey('TargetType')) {
        $conditions += "target_type = @target_type"
        $params.target_type = $TargetType
    }
    if ($PSBoundParameters.ContainsKey('Relationship')) {
        $conditions += "relationship = @relationship"
        $params.relationship = $Relationship
    }

    $query = "SELECT target_type, permission, relationship FROM permission_relationships"
    if ($conditions.Count -gt 0) {
        $query += " WHERE " + ($conditions -join ' AND ')
    }
    $query += " ORDER BY target_type, relationship"

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)

    # Group flat rows into (targetType, relationship, permissions[]) shape
    # to match the structure Add-ComputedPermissionEdges expects
    $grouped = [ordered]@{}
    foreach ($row in $rows) {
        $key = "$($row.target_type)|$($row.relationship)"
        if (-not $grouped.Contains($key)) {
            $grouped[$key] = [PSCustomObject]@{
                targetType   = $row.target_type
                relationship = $row.relationship
                permissions  = [System.Collections.Generic.List[string]]::new()
            }
        }
        $grouped[$key].permissions.Add($row.permission)
    }

    @($grouped.Values | ForEach-Object {
        [PSCustomObject]@{
            targetType   = $_.targetType
            relationship = $_.relationship
            permissions  = @($_.permissions)
        }
    })
}
