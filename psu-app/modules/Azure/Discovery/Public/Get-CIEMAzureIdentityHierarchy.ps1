function Get-CIEMAzureIdentityHierarchy {
    <#
    .SYNOPSIS
        Returns the identity-centric hierarchy as an ordered node list.
    .DESCRIPTION
        Builds a Tenant -> IdentityType -> Identity -> Role -> Scope tree
        from effective role assignments (Effective mode) or raw ARM role
        assignment resources (Direct mode).
        Each node is a [PSCustomObject] with properties:
          NodeId, NodeType, Depth, ParentNodeId, Relationship, Label.
        Throws a terminating error if no assignment data exists.
    .PARAMETER Mode
        Effective: uses pre-computed azure_effective_role_assignments (group-expanded).
        Direct: uses raw role assignment ARM resources (no group expansion).
    .PARAMETER SubscriptionId
        When specified, only includes assignments whose scope starts with this subscription.
    .EXAMPLE
        Get-CIEMAzureIdentityHierarchy -Mode Effective
    .EXAMPLE
        Get-CIEMAzureIdentityHierarchy -Mode Direct -SubscriptionId 'xxx'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateSet('Effective', 'Direct')]
        [string]$Mode = 'Effective',

        [Parameter()]
        [string]$SubscriptionId
    )

    $ErrorActionPreference = 'Stop'

    Write-CIEMLog -Message "IDENTITY HIERARCHY: building tree (Mode=$Mode, SubscriptionId=$(if ($SubscriptionId) { $SubscriptionId } else { 'all' }))" -Severity INFO -Component 'Discovery'

    # Build subscription name lookup for scope label resolution
    $subNameLookup = @{}
    $subResources = @(Get-CIEMAzureArmResource -Type 'microsoft.resources/subscriptions')
    foreach ($sub in $subResources) {
        if ($sub.SubscriptionId -and $sub.Name) {
            $subNameLookup[$sub.SubscriptionId] = $sub.Name
        }
    }

    # Build group/principal display name lookup from Entra resources
    $groupNameLookup = @{}
    $entraResources = @(Get-CIEMAzureEntraResource)
    foreach ($e in $entraResources) {
        if ($e.Id -and $e.DisplayName) {
            $groupNameLookup[$e.Id] = $e.DisplayName
        }
    }

    if ($Mode -eq 'Effective') {
        $assignments = @(Get-CIEMAzureEffectiveRoleAssignment)

        # Filter by subscription if specified
        if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
            $scopePrefix = "/subscriptions/$SubscriptionId"
            $assignments = @($assignments | Where-Object { $_.Scope -like "$scopePrefix*" })
        }

        if (-not $assignments -or $assignments.Count -eq 0) {
            throw "No effective role assignments found in the database. Run Azure discovery first."
        }

        Write-CIEMLog -Message "IDENTITY HIERARCHY: $($assignments.Count) effective assignments" -Severity INFO -Component 'Discovery'
    } else {
        # Direct mode — read raw role assignment ARM resources
        $roleAssignResources = @(Get-CIEMAzureArmResource -Type 'microsoft.authorization/roleassignments')

        # Filter by subscription if specified
        if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
            $roleAssignResources = @($roleAssignResources | Where-Object { $_.SubscriptionId -eq $SubscriptionId })
        }

        if (-not $roleAssignResources -or $roleAssignResources.Count -eq 0) {
            throw "No role assignment resources found in the database. Run Azure discovery first."
        }

        # Build role definition lookup for role name resolution
        $roleDefLookup = @{}
        $roleDefRows = @(Invoke-CIEMQuery -Query "SELECT id, json_extract(properties, '$.roleName') as role_name FROM azure_arm_resources WHERE type = 'microsoft.authorization/roledefinitions' AND properties IS NOT NULL")
        foreach ($row in $roleDefRows) {
            if ($row.id -and $row.role_name) { $roleDefLookup[$row.id] = $row.role_name }
        }

        # Normalize raw role assignments to the same shape as effective assignments
        $assignments = [System.Collections.Generic.List[PSObject]]::new()
        foreach ($ra in $roleAssignResources) {
            if (-not $ra.Properties) { continue }
            $props = $ra.Properties | ConvertFrom-Json -ErrorAction SilentlyContinue
            if (-not $props) { continue }
            if (-not $props.principalId -or -not $props.roleDefinitionId -or -not $props.scope) { continue }

            $roleName = $roleDefLookup[$props.roleDefinitionId]
            $displayName = $groupNameLookup[$props.principalId]
            if (-not $displayName) {
                $displayName = if ($props.principalId.Length -gt 8) {
                    $props.principalId.Substring(0, 8)
                } else { $props.principalId }
            }

            $assignments.Add([PSCustomObject]@{
                PrincipalId           = $props.principalId
                PrincipalType         = if ($props.principalType) { $props.principalType } else { 'Unknown' }
                PrincipalDisplayName  = $displayName
                OriginalPrincipalId   = $props.principalId
                OriginalPrincipalType = if ($props.principalType) { $props.principalType } else { 'Unknown' }
                RoleName              = if ($roleName) { $roleName } else { 'Unknown Role' }
                Scope                 = $props.scope
            })
        }

        if ($assignments.Count -eq 0) {
            throw "No valid role assignment resources found in the database."
        }

        Write-CIEMLog -Message "IDENTITY HIERARCHY: $($assignments.Count) direct assignments" -Severity INFO -Component 'Discovery'
    }

    $nodes = InvokeCIEMIdentityHierarchyBuild -Assignments $assignments -Mode $Mode -ScopeLabelLookup $subNameLookup -GroupNameLookup $groupNameLookup
    Write-CIEMLog -Message "IDENTITY HIERARCHY: built $($nodes.Count) tree nodes" -Severity INFO -Component 'Discovery'
    $nodes
}
