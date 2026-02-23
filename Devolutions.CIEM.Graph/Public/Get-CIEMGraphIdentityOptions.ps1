function Get-CIEMGraphIdentityOptions {
    <#
    .SYNOPSIS
        Returns identity nodes as simple strings for UI autocomplete/select controls.

    .DESCRIPTION
        Deserializes the graph from a PSCustomObject and returns identities of the
        specified type as "DisplayName [Id]" strings. This avoids cross-module class
        type identity issues by keeping all class operations inside the module scope.

    .PARAMETER Data
        The PSCustomObject from Get-PSUCache (serialized graph).

    .PARAMETER NodeType
        The identity type to list: EntraUser, EntraGroup, or EntraServicePrincipal.

    .OUTPUTS
        [string[]] Array of "DisplayName [Id]" strings, sorted alphabetically.

    .EXAMPLE
        $options = Get-CIEMGraphIdentityOptions -Data $graphData -NodeType 'EntraUser'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Data,

        [Parameter(Mandatory)]
        [string]$NodeType
    )
    $ErrorActionPreference = 'Stop'

    # Work directly from serialized PSCustomObject to avoid costly full graph deserialization
    $nodeValues = if ($Data.Nodes -is [hashtable]) {
        $Data.Nodes.Values
    } else {
        $Data.Nodes.PSObject.Properties | ForEach-Object { $_.Value }
    }

    $options = @($nodeValues | Where-Object { [string]$_.NodeType -eq $NodeType } | ForEach-Object {
        $name = if ($_.PSObject.Properties.Name -contains 'DisplayName' -and $_.DisplayName) {
            $_.DisplayName
        } else {
            $id = [string]$_.Id
            $id.Substring(0, [Math]::Min(12, $id.Length))
        }
        "$name [$([string]$_.Id)]"
    } | Sort-Object)

    return $options
}
