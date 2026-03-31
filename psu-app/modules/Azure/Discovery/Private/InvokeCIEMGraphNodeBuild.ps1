function InvokeCIEMGraphNodeBuild {
    <#
    .SYNOPSIS
        Transforms ARM and Entra resources into graph_nodes rows.
    .DESCRIPTION
        Iterates over ARM and Entra resource collections, resolves each to a graph node kind,
        packs ARM-specific metadata into a properties JSON blob, and saves to the graph_nodes table.
        Also creates two singleton nodes: '__internet__' (global) and the Azure tenant node.
    .PARAMETER ArmResources
        Array of ARM resource objects (from azure_arm_resources or Resource Graph).
    .PARAMETER EntraResources
        Array of Entra resource objects (from azure_entra_resources or Graph API).
    .PARAMETER Connection
        SQLite connection for transaction support. Pass $null for standalone operations.
    .PARAMETER CollectedAt
        ISO 8601 timestamp for the collection time.
    .OUTPUTS
        [int] Total number of nodes created.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ArmResources,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$EntraResources,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Connection,

        [Parameter(Mandatory)]
        [string]$CollectedAt
    )

    $ErrorActionPreference = 'Stop'

    $nodeCount = 0
    $tenantId = $null

    # Build Save-CIEMGraphNode splat base (conditionally includes -Connection)
    $baseSplat = @{ CollectedAt = $CollectedAt }
    if ($Connection) { $baseSplat.Connection = $Connection }

    # Process ARM resources
    foreach ($r in $ArmResources) {
        $kind = ResolveCIEMNodeKind -Type $r.Type -Source 'ARM'

        # Pack ARM-specific fields into properties JSON
        $propsHash = @{}
        if ($r.Type)       { $propsHash['arm_type']    = $r.Type }
        if ($r.Location)   { $propsHash['location']    = $r.Location }
        if ($r.TenantId)   { $propsHash['tenant_id']   = $r.TenantId; if (-not $tenantId) { $tenantId = $r.TenantId } }
        if ($r.Kind)       { $propsHash['kind']        = $r.Kind }
        if ($r.Sku)        { $propsHash['sku']         = $r.Sku }
        if ($r.Identity)   { $propsHash['identity']    = $r.Identity }
        if ($r.ManagedBy)  { $propsHash['managed_by']  = $r.ManagedBy }
        if ($r.Plan)       { $propsHash['plan']        = $r.Plan }
        if ($r.Zones)      { $propsHash['zones']       = $r.Zones }
        if ($r.Tags)       { $propsHash['tags']        = $r.Tags }
        if ($r.Properties) { $propsHash['properties']  = $r.Properties }
        $propertiesJson = if ($propsHash.Count -gt 0) { $propsHash | ConvertTo-Json -Depth 3 -Compress } else { $null }

        $splat = $baseSplat.Clone()
        $splat.Id             = $r.Id
        $splat.Kind           = $kind
        $splat.DisplayName    = $r.Name
        $splat.Provider       = 'azure'
        $splat.SubscriptionId = $r.SubscriptionId
        $splat.ResourceGroup  = $r.ResourceGroup
        $splat.Properties     = $propertiesJson

        Save-CIEMGraphNode @splat
        $nodeCount++
    }

    # Process Entra resources
    foreach ($e in $EntraResources) {
        $kind = ResolveCIEMNodeKind -Type $e.Type -Source 'Entra' -PropertiesJson $e.Properties

        $splat = $baseSplat.Clone()
        $splat.Id          = $e.Id
        $splat.Kind        = $kind
        $splat.DisplayName = $e.DisplayName
        $splat.Provider    = 'azure'
        $splat.Properties  = $e.Properties

        Save-CIEMGraphNode @splat
        $nodeCount++
    }

    # Singleton: Internet node
    $splat = $baseSplat.Clone()
    $splat.Id          = '__internet__'
    $splat.Kind        = 'Internet'
    $splat.DisplayName = 'Internet'
    $splat.Provider    = 'global'
    Save-CIEMGraphNode @splat
    $nodeCount++

    # Singleton: Tenant node
    $tid = if ($tenantId) { $tenantId } else { 'unknown-tenant' }
    $splat = $baseSplat.Clone()
    $splat.Id          = $tid
    $splat.Kind        = 'AzureTenant'
    $splat.DisplayName = 'Tenant'
    $splat.Provider    = 'azure'
    Save-CIEMGraphNode @splat
    $nodeCount++

    Write-CIEMLog "Graph node build: $nodeCount nodes created" -Component 'GraphBuilder'
    $nodeCount
}
