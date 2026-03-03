function Get-CIEMIdentity {
    <#
    .SYNOPSIS
        Lists identity types that can be assigned permissions to resources.

    .DESCRIPTION
        Queries the identity_types table in SQLite and returns the canonical list
        of identity types for a given cloud provider. Each entry describes an
        entity that can appear as a security principal in role assignments.

    .PARAMETER Provider
        Filter by cloud provider (Azure, AWS).

    .PARAMETER Name
        Filter by identity type name (e.g., "EntraUser", "EntraServicePrincipal").

    .PARAMETER Type
        Filter by identity category (Human, Collection, Workload).

    .OUTPUTS
        [CIEMIdentity[]] Array of identity type objects.

    .EXAMPLE
        Get-CIEMIdentity -Provider Azure
        # Returns all Azure identity types

    .EXAMPLE
        Get-CIEMIdentity -Provider Azure -Type Workload
        # Returns workload identities (service principals, managed identities, applications)

    .EXAMPLE
        Get-CIEMIdentity -Provider Azure -Name EntraUser
        # Returns the Entra user identity type
    #>
    [CmdletBinding()]
    [OutputType('CIEMIdentity[]')]
    param(
        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('Human', 'Collection', 'Workload')]
        [string]$Type
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @()
    $params = @{}

    if ($PSBoundParameters.ContainsKey('Provider')) {
        $conditions += "provider = @provider"
        $params.provider = $Provider
    }
    if ($PSBoundParameters.ContainsKey('Name')) {
        $conditions += "name = @name"
        $params.name = $Name
    }
    if ($PSBoundParameters.ContainsKey('Type')) {
        $conditions += "type = @type"
        $params.type = $Type
    }

    $query = "SELECT * FROM identity_types"
    if ($conditions.Count -gt 0) {
        $query += " WHERE " + ($conditions -join ' AND ')
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)

    @(foreach ($row in $rows) {
        $obj = [CIEMIdentity]::new()
        $obj.Name          = $row.name
        $obj.DisplayName   = $row.display_name
        $obj.Type          = $row.type
        $obj.Provider      = $row.provider
        $obj.PrincipalType = $row.principal_type
        $obj.GraphNodeType = $row.graph_node_type
        $obj.Description   = $row.description
        $obj
    })
}
