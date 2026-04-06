function ResolveCIEMNodeKind {
    <#
    .SYNOPSIS
        Maps ARM type or Entra type to a graph node kind string.
    .DESCRIPTION
        Uses graph_kind_map.json to resolve resource types to human-readable graph node kinds.
        ARM resources map via arm_type_to_kind; unknown ARM types fall back to the default_arm_kind.
        Entra resources map via entra_type_to_kind; unknown Entra types return the raw type string.
        Special case: servicePrincipal with servicePrincipalType=ManagedIdentity returns the
        managed_identity_kind from the map.
    .PARAMETER Type
        The ARM resource type (lowercase, e.g. 'microsoft.compute/virtualmachines') or
        Entra resource type (e.g. 'user', 'servicePrincipal').
    .PARAMETER Source
        Whether the type comes from ARM or Entra.
    .PARAMETER PropertiesJson
        Optional JSON string of the resource's properties. Used for Entra servicePrincipal
        to detect managed identity type.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Type,

        [Parameter(Mandatory)]
        [ValidateSet('ARM', 'Entra')]
        [string]$Source,

        [Parameter()]
        [string]$PropertiesJson
    )

    $ErrorActionPreference = 'Stop'

    # Load kind map (cache in script scope for performance)
    if (-not $script:GraphKindMap) {
        $mapPath = Join-Path $script:AzureDiscoveryRoot 'Data/graph_kind_map.json'
        $script:GraphKindMap = Get-Content $mapPath -Raw | ConvertFrom-Json
    }

    if ($Source -eq 'ARM') {
        $kind = $script:GraphKindMap.arm_type_to_kind.$Type
        if ($kind) { return $kind }
        return $script:GraphKindMap.default_arm_kind
    }

    # Entra source
    # Special case: detect managed identity
    if ($Type -eq 'servicePrincipal' -and $PropertiesJson) {
        try {
            $props = $PropertiesJson | ConvertFrom-Json -ErrorAction Stop
            if ($props.servicePrincipalType -eq 'ManagedIdentity') {
                return $script:GraphKindMap.managed_identity_kind
            }
        } catch { }
    }

    $kind = $script:GraphKindMap.entra_type_to_kind.$Type
    if ($kind) { return $kind }
    return $Type
}
