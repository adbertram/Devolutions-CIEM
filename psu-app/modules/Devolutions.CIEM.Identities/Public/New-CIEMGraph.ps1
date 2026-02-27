function New-CIEMGraph {
    <#
    .SYNOPSIS
        Builds a CIEM identity-to-resource relationship graph from Azure service data.

    .DESCRIPTION
        Main orchestrator that converts raw API data into a typed graph with identity,
        RBAC, app role, and computed permission relationships. Receives pre-fetched data
        from service cache — never makes API calls itself.

        Pipeline phases:
        1. Nodes — ConvertTo-GraphNode creates typed nodes from raw API objects
        2. Identity edges — REPORTS_TO, MEMBER_OF, OWNER_OF, HAS_SERVICE_PRINCIPAL
        3. RBAC edges — HAS_ROLE_ASSIGNMENT, USES_ROLE, HAS_PERMISSIONS
        4. App role edges — HAS_APP_ROLE, ASSIGNED_TO
        5. Computed RPR — CAN_READ/WRITE/MANAGE from permission evaluation

    .PARAMETER EntraData
        Hashtable from Entra service cache containing Users, Groups, GroupMembers,
        GroupOwners, ServicePrincipals, Applications, AppRoleAssignments.

    .PARAMETER IAMData
        Hashtable keyed by subscription ID from IAM service cache. Each value
        contains RoleDefinitions and RoleAssignments.

    .PARAMETER TenantId
        Azure AD tenant ID for the graph metadata.

    .OUTPUTS
        [CIEMGraph] The built relationship graph.

    .EXAMPLE
        $graph = New-CIEMGraph -EntraData $entraCache.CacheData -IAMData $iamData -TenantId $tid
    #>
    [CmdletBinding()]
    [OutputType([CIEMGraph])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$EntraData,

        [Parameter()]
        [hashtable]$IAMData = @{},

        [Parameter()]
        [string]$TenantId
    )
    $ErrorActionPreference = 'Stop'

    $graph = [CIEMGraph]::new()
    $graph.TenantId = $TenantId
    $graph.SubscriptionIds = @($IAMData.Keys)

    Write-Verbose "Building CIEM graph..."

    # Phase 1: Create nodes from raw data
    Write-Verbose "Phase 1: Creating nodes..."

    # Entra identity nodes
    if ($EntraData.Users) {
        $nodes = @(ConvertTo-GraphNode -RawData $EntraData.Users -NodeType EntraUser)
        foreach ($node in $nodes) { $graph.AddNode($node) }
        Write-Verbose "  Added $($nodes.Count) user nodes"
    }

    if ($EntraData.Groups) {
        $nodes = @(ConvertTo-GraphNode -RawData $EntraData.Groups -NodeType EntraGroup)
        foreach ($node in $nodes) { $graph.AddNode($node) }
        Write-Verbose "  Added $($nodes.Count) group nodes"
    }

    if ($EntraData.ServicePrincipals) {
        $nodes = @(ConvertTo-GraphNode -RawData $EntraData.ServicePrincipals -NodeType EntraServicePrincipal)
        foreach ($node in $nodes) { $graph.AddNode($node) }
        Write-Verbose "  Added $($nodes.Count) service principal nodes"
    }

    if ($EntraData.Applications) {
        $nodes = @(ConvertTo-GraphNode -RawData $EntraData.Applications -NodeType EntraApplication)
        foreach ($node in $nodes) { $graph.AddNode($node) }
        Write-Verbose "  Added $($nodes.Count) application nodes"
    }

    # App role assignment nodes (flattened from per-SP hashtable)
    if ($EntraData.ContainsKey('AppRoleAssignments') -and $EntraData.AppRoleAssignments -is [hashtable]) {
        $allAssignments = [System.Collections.Generic.List[object]]::new()
        foreach ($entry in $EntraData.AppRoleAssignments.GetEnumerator()) {
            if ($entry.Value) { foreach ($v in $entry.Value) { $allAssignments.Add($v) } }
        }
        if ($allAssignments.Count -gt 0) {
            $nodes = @(ConvertTo-GraphNode -RawData $allAssignments -NodeType EntraAppRoleAssignment)
            foreach ($node in $nodes) { $graph.AddNode($node) }
            Write-Verbose "  Added $($nodes.Count) app role assignment nodes"
        }
    }

    # RBAC nodes (per subscription)
    foreach ($subId in $IAMData.Keys) {
        $subData = $IAMData[$subId]

        if ($subData.RoleAssignments) {
            $nodes = @(ConvertTo-GraphNode -RawData $subData.RoleAssignments -NodeType AzureRoleAssignment)
            foreach ($node in $nodes) { $graph.AddNode($node) }
            Write-Verbose "  Added $($nodes.Count) role assignment nodes for subscription $subId"
        }

        if ($subData.RoleDefinitions) {
            $nodes = @(ConvertTo-GraphNode -RawData $subData.RoleDefinitions -NodeType AzureRoleDefinition)
            foreach ($node in $nodes) { $graph.AddNode($node) }
            Write-Verbose "  Added $($nodes.Count) role definition nodes for subscription $subId"

            # Create permission nodes from role definitions
            foreach ($roleDef in $subData.RoleDefinitions) {
                $permissions = $roleDef.properties.permissions
                if (-not $permissions) { continue }

                $permIndex = 0
                foreach ($perm in $permissions) {
                    $permData = @{
                        _permissionId  = "$($roleDef.id):perm:$permIndex"
                        actions        = @($perm.actions)
                        notActions     = @($perm.notActions)
                        dataActions    = @($perm.dataActions)
                        notDataActions = @($perm.notDataActions)
                    }
                    $permNodes = @(ConvertTo-GraphNode -RawData @($permData) -NodeType AzurePermissions)
                    foreach ($permNode in $permNodes) { $graph.AddNode($permNode) }
                    $permIndex++
                }
            }
            Write-Verbose "  Created permission nodes for role definitions"
        }
    }

    Write-Verbose "Phase 1 complete: $($graph.Nodes.Count) total nodes"

    # Phase 2: Identity edges
    Write-Verbose "Phase 2: Building identity edges..."
    Add-IdentityEdges -Graph $graph -EntraData $EntraData
    Write-Verbose "  Identity edges complete ($($graph.Edges.Count) total edges)"

    # Phase 3: RBAC edges
    Write-Verbose "Phase 3: Building RBAC edges..."
    Add-RBACEdges -Graph $graph
    Write-Verbose "  RBAC edges complete ($($graph.Edges.Count) total edges)"

    # Phase 4: App role edges
    Write-Verbose "Phase 4: Building app role edges..."
    Add-AppRoleEdges -Graph $graph
    Write-Verbose "  App role edges complete ($($graph.Edges.Count) total edges)"

    # Phase 5: Computed permission edges
    Write-Verbose "Phase 5: Computing permission relationships..."
    $rprPath = Join-Path $script:IdentitiesRoot 'Data/permission_relationships.json'
    if (Test-Path $rprPath) {
        $permRelationships = Get-Content -Path $rprPath -Raw | ConvertFrom-Json
        Add-ComputedPermissionEdges -Graph $graph -PermissionRelationships $permRelationships
        Write-Verbose "  Computed permission edges complete ($($graph.Edges.Count) total edges)"
    }
    else {
        Write-Warning "Permission relationships config not found at: $rprPath"
    }

    # Phase 6: Create resource type nodes from parent module's canonical vocabulary
    Write-Verbose "Phase 6: Creating resource type nodes..."
    $rtCount = 0
    # Determine provider from data: Azure if we have Entra data, AWS when supported
    if ($EntraData.Users -or $EntraData.Groups -or $EntraData.ServicePrincipals) {
        $azureResourceTypes = @(Get-CIEMResourceType -Provider 'Azure')
        foreach ($rt in $azureResourceTypes) {
            $rtNode = [CIEMAzureResourceTypeNode]::new()
            $rtNode.Id = "type:$($rt.Name)"
            $rtNode.ResourceTypeName = $rt.Name
            $rtNode.DisplayName = $rt.DisplayName
            $rtNode.ArmProviderPrefix = $rt.ArmProviderPrefix
            $graph.AddNode($rtNode)
            $rtCount++
        }
    }
    Write-Verbose "  Added $rtCount resource type nodes"

    Write-Verbose "Graph build complete: $($graph.Nodes.Count) nodes, $($graph.Edges.Count) edges"

    return $graph
}
