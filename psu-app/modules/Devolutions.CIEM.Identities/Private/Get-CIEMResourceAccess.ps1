function Get-CIEMResourceAccess {
    <#
    .SYNOPSIS
        Answers "Who can access this resource type?" by querying computed permission edges.

    .PARAMETER Graph
        The CIEMGraph to query.

    .PARAMETER TargetType
        The resource type to query (e.g., "KeyVault", "SqlServer", "StorageAccount").

    .PARAMETER Relationship
        Optional filter for specific permission level (CAN_READ, CAN_WRITE, CAN_MANAGE).

    .OUTPUTS
        [PSCustomObject[]] Objects with IdentityId, IdentityName, IdentityType, Relationship, Scopes.

    .EXAMPLE
        Get-CIEMResourceAccess -Graph $graph -TargetType "KeyVault"

    .EXAMPLE
        Get-CIEMResourceAccess -Graph $graph -TargetType "SqlServer" -Relationship CAN_MANAGE
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMGraph]$Graph,

        [Parameter(Mandatory)]
        [string]$TargetType,

        [Parameter()]
        [CIEMGraphRelationship]$Relationship
    )
    $ErrorActionPreference = 'Stop'

    $targetNodeId = "type:$TargetType"

    # Get all edges pointing to this resource type
    $edges = $Graph.GetEdgesTo($targetNodeId)

    if ($PSBoundParameters.ContainsKey('Relationship')) {
        $edges = @($edges | Where-Object { $_.Relationship -eq $Relationship })
    }
    else {
        $edges = @($edges | Where-Object {
            $_.Relationship -in @(
                [CIEMGraphRelationship]::CAN_READ
                [CIEMGraphRelationship]::CAN_WRITE
                [CIEMGraphRelationship]::CAN_MANAGE
            )
        })
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($edge in $edges) {
        $identity = $Graph.GetNode($edge.SourceId)
        if (-not $identity) { continue }

        $identityName = if ($identity.PSObject.Properties.Name -contains 'DisplayName') { $identity.DisplayName }
                        elseif ($identity.PSObject.Properties.Name -contains 'UserPrincipalName') { $identity.UserPrincipalName }
                        else { $identity.Id }

        $results.Add([PSCustomObject]@{
            IdentityId   = $identity.Id
            IdentityName = $identityName
            IdentityType = $identity.NodeType.ToString()
            Relationship = $edge.Relationship.ToString()
            TargetType   = $TargetType
            Scopes       = $edge.Properties['scopes']
        })
    }

    return $results
}
