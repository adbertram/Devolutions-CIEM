function InvokeCIEMGraphComputedEdgeBuild {
    <#
    .SYNOPSIS
        Derives computed graph edges from resource properties.
    .DESCRIPTION
        Analyzes ARM resources, Entra resources, and collected relationships to derive computed
        edges that represent inferred relationships not directly collected from APIs:
        - HasRole: identity -> scope (from role assignments)
        - InheritedRole: group member -> scope (expanded from group role assignments)
          - HasAppRoleAssignment: service principal -> resource service principal
          - HasOAuthGrant: service principal -> resource service principal
          - HasManagedIdentity: ARM resource -> managed identity service principal
          - AttachedTo: NIC -> VM
          - HasPublicIP: NIC -> Public IP
          - InSubnet: NIC -> VNet (with subnet_id in properties)
          - AllowsInbound: Internet -> NSG (aggregated open ports per NSG)
          - ContainedIn: resource -> subscription
        All computed edges are saved with computed=1.
    .PARAMETER ArmResources
        Array of ARM resource objects.
    .PARAMETER EntraResources
        Array of Entra resource objects.
    .PARAMETER Relationships
        Array of collected relationship objects (used for group membership expansion).
    .PARAMETER Connection
        SQLite connection for transaction support. Pass $null for standalone operations.
    .PARAMETER CollectedAt
        ISO 8601 timestamp for the collection time.
    .OUTPUTS
        [int] Total number of computed edges created.
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
        [AllowEmptyCollection()]
        [object[]]$Relationships,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Connection,

        [Parameter(Mandatory)]
        [string]$CollectedAt
    )

    $ErrorActionPreference = 'Stop'

    $edgeCount = 0

    # Node existence cache to avoid repeated DB queries
    $nodeExistsCache = @{}

    # Build Save-CIEMGraphEdge splat base
    $baseSplat = @{ Computed = 1; CollectedAt = $CollectedAt }
    if ($Connection) { $baseSplat.Connection = $Connection }

    # ===== Helper: check if node exists in graph =====
    # Must use same $Connection to see uncommitted nodes within a transaction
    function NodeExists([string]$nodeId) {
        $ErrorActionPreference = 'Stop'
        if (-not $nodeId) { return $false }
        if ($nodeExistsCache.ContainsKey($nodeId)) { return $nodeExistsCache[$nodeId] }
        $fkParams = @{ Query = "SELECT 1 FROM graph_nodes WHERE id = @id"; Parameters = @{ id = $nodeId } }
        if ($Connection) { $fkParams.Connection = $Connection }
        $exists = (@(Invoke-CIEMQuery @fkParams).Count -gt 0)
        $nodeExistsCache[$nodeId] = $exists
        $exists
    }

    function ConvertFromJsonStrict([string]$Json, [string]$Context) {
        $ErrorActionPreference = 'Stop'
        try {
            $value = $Json | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            throw "$Context contains invalid JSON: $($_.Exception.Message)"
        }

        if ($null -eq $value) {
            throw "$Context contains empty JSON."
        }

        $value
    }

    function SaveEdgeStrict([hashtable]$splat) {
        $ErrorActionPreference = 'Stop'
        Save-CIEMGraphEdge @splat
        $true
    }

    # ===== 1. Build lookups from ARM resources =====

    # Role definition lookup: roleDefId -> { RoleName, PermissionsJson }
    $roleDefLookup = @{}
    foreach ($r in $ArmResources) {
        if ($r.Type -eq 'microsoft.authorization/roledefinitions' -and $r.Properties) {
            $props = ConvertFromJsonStrict -Json $r.Properties -Context "Role definition '$($r.Id)' properties"
            if ($props) {
                $roleDefLookup[$r.Id] = @{
                    RoleName       = $props.roleName
                    PermissionsJson = if ($props.permissions) { $props.permissions | ConvertTo-Json -Depth 10 -Compress } else { $null }
                }
            }
        }
    }

    # Display name lookup: entraId -> displayName
    $displayNameLookup = @{}
    foreach ($e in $EntraResources) {
        if ($e.Id -and $e.DisplayName) { $displayNameLookup[$e.Id] = $e.DisplayName }
    }

    # Transitive membership lookup: groupId -> list of { Id, Type }
    $groupMembersLookup = @{}
    foreach ($rel in $Relationships) {
        if ($rel.Relationship -eq 'transitive_member_of') {
            $groupId = $rel.TargetId
            if (-not $groupMembersLookup.ContainsKey($groupId)) {
                $groupMembersLookup[$groupId] = [System.Collections.Generic.List[object]]::new()
            }
            $groupMembersLookup[$groupId].Add(@{ Id = $rel.SourceId; Type = $rel.SourceType })
        }
    }

    # ===== 2. HasRole + InheritedRole edges =====
    $roleAssignments = @($ArmResources | Where-Object {
        $_.Type -eq 'microsoft.authorization/roleassignments' -and $_.Properties
    })

    foreach ($ra in $roleAssignments) {
        $raProps = ConvertFromJsonStrict -Json $ra.Properties -Context "Role assignment '$($ra.Id)' properties"

        $principalId      = $raProps.principalId
        $principalType    = $raProps.principalType
        $roleDefinitionId = $raProps.roleDefinitionId
        $scope            = $raProps.scope
        if (-not $principalId -or -not $roleDefinitionId -or -not $scope) { continue }

        $roleDef         = $roleDefLookup[$roleDefinitionId]
        $roleName        = if ($roleDef) { $roleDef.RoleName } else { $null }
        $permissionsJson = if ($roleDef) { $roleDef.PermissionsJson } else { $null }
        # TestCIEMAzurePrivilegedRole requires non-empty RoleName; default to 'Unknown' when missing
        $roleNameForCheck = if ($roleName) { $roleName } else { 'Unknown' }
        $isPrivileged    = TestCIEMAzurePrivilegedRole -RoleName $roleNameForCheck -PermissionsJson $permissionsJson

        $edgePropsHash = @{
            role_name          = $roleName
            role_definition_id = $roleDefinitionId
            role_assignment_id = $ra.Id
            permissions_json   = $permissionsJson
            privileged         = $isPrivileged
            principal_type     = $principalType
        }
        $edgePropsJson = $edgePropsHash | ConvertTo-Json -Depth 3 -Compress

        # Direct HasRole edge
        if ((NodeExists $principalId) -and (NodeExists $scope)) {
            $splat = $baseSplat.Clone()
            $splat.SourceId   = $principalId
            $splat.TargetId   = $scope
            $splat.Kind       = 'HasRole'
            $splat.Properties = $edgePropsJson
            if (SaveEdgeStrict $splat) { $edgeCount++ }
        }

        # InheritedRole: expand group memberships
        if ($principalType -eq 'Group') {
            $members = $groupMembersLookup[$principalId]
            if ($members) {
                foreach ($member in $members) {
                    if ((NodeExists $member.Id) -and (NodeExists $scope)) {
                        $inheritedPropsHash = @{
                            role_name          = $roleName
                            role_definition_id = $roleDefinitionId
                            role_assignment_id = $ra.Id
                            permissions_json   = $permissionsJson
                            privileged         = $isPrivileged
                            principal_type     = $member.Type
                            inherited_from     = $principalId
                            inherited_from_name = $displayNameLookup[$principalId]
                        }
                        $inheritedPropsJson = $inheritedPropsHash | ConvertTo-Json -Depth 3 -Compress

                        $splat = $baseSplat.Clone()
                        $splat.SourceId   = $member.Id
                        $splat.TargetId   = $scope
                        $splat.Kind       = 'InheritedRole'
                        $splat.Properties = $inheritedPropsJson
                        if (SaveEdgeStrict $splat) { $edgeCount++ }
                    }
                }
            }
        }
    }

    # ===== 3. HasManagedIdentity edges =====
    # ===== 3. App role and OAuth grant edges =====
    foreach ($e in $EntraResources) {
        if (-not $e.Properties) { continue }

        if ($e.Type -eq 'appRoleAssignment') {
            $assignmentProps = ConvertFromJsonStrict -Json $e.Properties -Context "App role assignment '$($e.Id)' properties"

            $sourceId = $assignmentProps.principalId
            if (-not $sourceId) { $sourceId = $e.ParentId }
            $targetId = $assignmentProps.resourceId
            if (-not $sourceId -or -not $targetId) { continue }
            if ((NodeExists $sourceId) -and (NodeExists $targetId)) {
                $edgePropsJson = @{
                    assignment_id = $assignmentProps.id
                    app_role_id = $assignmentProps.appRoleId
                    principal_type = $assignmentProps.principalType
                    resource_display_name = $assignmentProps.resourceDisplayName
                    discovered_resource_id = $e.Id
                } | ConvertTo-Json -Depth 5 -Compress

                $splat = $baseSplat.Clone()
                $splat.SourceId = $sourceId
                $splat.TargetId = $targetId
                $splat.Kind = 'HasAppRoleAssignment'
                $splat.Properties = $edgePropsJson
                if (SaveEdgeStrict $splat) { $edgeCount++ }
            }
        }

        if ($e.Type -eq 'oauth2PermissionGrant') {
            $grantProps = ConvertFromJsonStrict -Json $e.Properties -Context "OAuth grant '$($e.Id)' properties"

            $sourceId = $grantProps.clientId
            if (-not $sourceId) { $sourceId = $e.ParentId }
            $targetId = $grantProps.resourceId
            if (-not $sourceId -or -not $targetId) { continue }
            if ((NodeExists $sourceId) -and (NodeExists $targetId)) {
                $edgePropsJson = @{
                    grant_id = $grantProps.id
                    scope = $grantProps.scope
                    consent_type = $grantProps.consentType
                    principal_id = $grantProps.principalId
                    discovered_resource_id = $e.Id
                } | ConvertTo-Json -Depth 5 -Compress

                $splat = $baseSplat.Clone()
                $splat.SourceId = $sourceId
                $splat.TargetId = $targetId
                $splat.Kind = 'HasOAuthGrant'
                $splat.Properties = $edgePropsJson
                if (SaveEdgeStrict $splat) { $edgeCount++ }
            }
        }
    }

    # ===== 4. HasManagedIdentity edges =====
    foreach ($r in $ArmResources) {
        if (-not $r.Identity) { continue }
        $identityJson = ConvertFromJsonStrict -Json $r.Identity -Context "Managed identity '$($r.Id)' identity"
        $principalId = $identityJson.principalId
        if ($principalId -and (NodeExists $r.Id) -and (NodeExists $principalId)) {
            $splat = $baseSplat.Clone()
            $splat.SourceId = $r.Id
            $splat.TargetId = $principalId
            $splat.Kind     = 'HasManagedIdentity'
            if (SaveEdgeStrict $splat) { $edgeCount++ }
        }
    }

    # ===== 5. Network topology edges (NIC -> VM, NIC -> PIP, NIC -> Subnet) =====
    $nics = @($ArmResources | Where-Object { $_.Type -eq 'microsoft.network/networkinterfaces' -and $_.Properties })
    foreach ($nic in $nics) {
        $nicProps = ConvertFromJsonStrict -Json $nic.Properties -Context "Network interface '$($nic.Id)' properties"

        # AttachedTo: NIC -> VM
        $vmId = $null
        if ($nicProps.virtualMachine -and $nicProps.virtualMachine.id) {
            $vmId = $nicProps.virtualMachine.id
            if ((NodeExists $nic.Id) -and (NodeExists $vmId)) {
                $splat = $baseSplat.Clone()
                $splat.SourceId = $nic.Id
                $splat.TargetId = $vmId
                $splat.Kind     = 'AttachedTo'
                if (SaveEdgeStrict $splat) { $edgeCount++ }
            }
        }

        # AttachedTo: NSG -> VM (derived from NIC having both NSG and VM references)
        if ($vmId -and $nicProps.networkSecurityGroup -and $nicProps.networkSecurityGroup.id) {
            $nsgId = $nicProps.networkSecurityGroup.id
            if ((NodeExists $nsgId) -and (NodeExists $vmId)) {
                $splat = $baseSplat.Clone()
                $splat.SourceId = $nsgId
                $splat.TargetId = $vmId
                $splat.Kind     = 'AttachedTo'
                if (SaveEdgeStrict $splat) { $edgeCount++ }
            }
        }

        # HasPublicIP + InSubnet from ipConfigurations
        if ($nicProps.ipConfigurations) {
            foreach ($ipConfig in $nicProps.ipConfigurations) {
                $ipProps = if ($ipConfig.properties) { $ipConfig.properties } else { $ipConfig }

                # HasPublicIP: NIC -> PublicIP
                if ($ipProps.publicIPAddress -and $ipProps.publicIPAddress.id) {
                    $pipId = $ipProps.publicIPAddress.id
                    if ((NodeExists $nic.Id) -and (NodeExists $pipId)) {
                        $splat = $baseSplat.Clone()
                        $splat.SourceId = $nic.Id
                        $splat.TargetId = $pipId
                        $splat.Kind     = 'HasPublicIP'
                        if (SaveEdgeStrict $splat) { $edgeCount++ }
                    }
                }

                # InSubnet: NIC -> VNet (extract VNet ID from subnet path)
                if ($ipProps.subnet -and $ipProps.subnet.id) {
                    $subnetId = $ipProps.subnet.id
                    # VNet ID = everything before /subnets/
                    $vnetId = $subnetId -replace '/subnets/[^/]+$', ''
                    if ($vnetId -ne $subnetId -and (NodeExists $nic.Id) -and (NodeExists $vnetId)) {
                        $splat = $baseSplat.Clone()
                        $splat.SourceId   = $nic.Id
                        $splat.TargetId   = $vnetId
                        $splat.Kind       = 'InSubnet'
                        $splat.Properties = @{ subnet_id = $subnetId } | ConvertTo-Json -Compress
                        if (SaveEdgeStrict $splat) { $edgeCount++ }
                    }
                }
            }
        }
    }

    # ===== 6. AllowsInbound edges: Internet -> NSG (aggregated per NSG) =====
    $nsgs = @($ArmResources | Where-Object { $_.Type -eq 'microsoft.network/networksecuritygroups' -and $_.Properties })
    foreach ($nsg in $nsgs) {
        $nsgProps = ConvertFromJsonStrict -Json $nsg.Properties -Context "Network security group '$($nsg.Id)' properties"

        $allRules = @()
        if ($nsgProps.securityRules) { $allRules += $nsgProps.securityRules }
        if ($nsgProps.defaultSecurityRules) { $allRules += $nsgProps.defaultSecurityRules }

        # Collect all inbound-allow-from-internet rules
        $openPorts = [System.Collections.Generic.List[object]]::new()
        foreach ($rule in $allRules) {
            $ruleProps = if ($rule.properties) { $rule.properties } else { $rule }
            if ($ruleProps.direction -eq 'Inbound' -and $ruleProps.access -eq 'Allow' -and $ruleProps.sourceAddressPrefix -in @('*', '0.0.0.0/0', 'Internet')) {
                # Azure uses destinationPortRange (singular) for single-port rules and
                # destinationPortRanges (plural array) for multi-port rules (singular is '' when plural is used)
                $portEntries = @()
                if ($ruleProps.destinationPortRanges -and $ruleProps.destinationPortRanges.Count -gt 0) {
                    $portEntries = $ruleProps.destinationPortRanges
                } elseif ($ruleProps.destinationPortRange) {
                    $portEntries = @($ruleProps.destinationPortRange)
                }
                foreach ($portEntry in $portEntries) {
                    $openPorts.Add(@{
                        port      = $portEntry
                        protocol  = $ruleProps.protocol
                        rule_name = $rule.name
                    })
                }
            }
        }

        if ($openPorts.Count -gt 0 -and (NodeExists '__internet__') -and (NodeExists $nsg.Id)) {
            $edgePropsJson = @{ open_ports = @($openPorts) } | ConvertTo-Json -Depth 5 -Compress
            $splat = $baseSplat.Clone()
            $splat.SourceId   = '__internet__'
            $splat.TargetId   = $nsg.Id
            $splat.Kind       = 'AllowsInbound'
            $splat.Properties = $edgePropsJson
            if (SaveEdgeStrict $splat) { $edgeCount++ }
        }
    }

    # ===== 7. ContainedIn: resource -> subscription =====
    # Build subscription node ID lookup: subscription_id -> node id
    $subNodeIds = @{}
    foreach ($r in $ArmResources) {
        if ($r.Type -eq 'microsoft.resources/subscriptions' -and $r.SubscriptionId) {
            $subNodeIds[$r.SubscriptionId] = $r.Id
        }
    }

    foreach ($r in $ArmResources) {
        if (-not $r.SubscriptionId) { continue }
        # Skip subscription-self and authorization resources
        if ($r.Type -eq 'microsoft.resources/subscriptions') { continue }
        if ($r.Type -match '^microsoft\.authorization/') { continue }

        $subNodeId = $subNodeIds[$r.SubscriptionId]
        if (-not $subNodeId) { continue }
        if ((NodeExists $r.Id) -and (NodeExists $subNodeId)) {
            $splat = $baseSplat.Clone()
            $splat.SourceId = $r.Id
            $splat.TargetId = $subNodeId
            $splat.Kind     = 'ContainedIn'
            if (SaveEdgeStrict $splat) { $edgeCount++ }
        }
    }

    Write-CIEMLog "Graph computed edge build: $edgeCount computed edges created" -Component 'GraphBuilder'
    $edgeCount
}
