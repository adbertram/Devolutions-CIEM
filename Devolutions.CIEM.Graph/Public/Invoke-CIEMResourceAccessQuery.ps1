function Invoke-CIEMResourceAccessQuery {
    <#
    .SYNOPSIS
        Queries resource access from raw graph cache data (no cross-module class issues).

    .DESCRIPTION
        Combines Import-CIEMGraph + Get-CIEMResourceAccess in a single module-scoped
        call. This avoids the PowerShell class type identity problem.

    .PARAMETER Data
        The PSCustomObject from Get-PSUCache (serialized graph).

    .PARAMETER TargetType
        The resource type to query (e.g., "KeyVault", "SqlServer").

    .PARAMETER Relationship
        Optional permission level filter (CAN_READ, CAN_WRITE, CAN_MANAGE).

    .OUTPUTS
        [PSCustomObject[]] Array of access results.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Data,

        [Parameter(Mandatory)]
        [string]$TargetType,

        [Parameter()]
        [string]$Relationship
    )
    $ErrorActionPreference = 'Stop'

    $graph = [CIEMGraph]::FromPSCustomObject($Data)

    $params = @{ Graph = $graph; TargetType = $TargetType }
    if ($Relationship) {
        $params.Relationship = [CIEMGraphRelationship]$Relationship
    }

    return @(Get-CIEMResourceAccess @params)
}
