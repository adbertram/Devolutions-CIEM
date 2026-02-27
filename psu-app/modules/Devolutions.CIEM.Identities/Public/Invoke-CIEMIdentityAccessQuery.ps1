function Invoke-CIEMIdentityAccessQuery {
    <#
    .SYNOPSIS
        Queries identity access from raw graph cache data (no cross-module class issues).

    .DESCRIPTION
        Combines Import-CIEMGraph + Get-CIEMIdentityAccess in a single module-scoped
        call. This avoids the PowerShell class type identity problem where CIEMGraph
        from one module load cannot be passed to functions from another load.

    .PARAMETER Data
        The PSCustomObject from Get-PSUCache (serialized graph).

    .PARAMETER IdentityId
        The ID of the identity to query.

    .PARAMETER ExpandGroups
        Whether to include access inherited through group memberships.

    .OUTPUTS
        [PSCustomObject] With IdentityName (string) and Results (PSCustomObject array).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Data,

        [Parameter(Mandatory)]
        [string]$IdentityId,

        [Parameter()]
        [switch]$ExpandGroups
    )
    $ErrorActionPreference = 'Stop'

    $graph = [CIEMGraph]::FromPSCustomObject($Data)

    $params = @{ Graph = $graph; IdentityId = $IdentityId }
    if ($ExpandGroups) { $params.ExpandGroups = $true }

    $results = @(Get-CIEMIdentityAccess @params)

    # Resolve identity display name
    $identity = $graph.GetNode($IdentityId)
    $identityName = if ($identity -and $identity.PSObject.Properties.Name -contains 'DisplayName') {
        $identity.DisplayName
    } else { $IdentityId }

    return [PSCustomObject]@{
        IdentityName = $identityName
        Results      = $results
    }
}
