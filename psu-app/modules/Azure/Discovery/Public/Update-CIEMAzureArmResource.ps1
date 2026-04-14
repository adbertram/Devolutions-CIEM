function Update-CIEMAzureArmResource {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureArmResource[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Type,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Location,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ResourceGroup,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$SubscriptionId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Kind,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Sku,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Identity,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ManagedBy,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Plan,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Zones,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Tags,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Properties,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(ParameterSetName = 'ByProperties')]
        [switch]$PassThru,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $parameters = @{
                    id              = $obj.Id
                    type            = $obj.Type
                    name            = $obj.Name
                    location        = $obj.Location
                    resource_group  = $obj.ResourceGroup
                    subscription_id = $obj.SubscriptionId
                    tenant_id       = $obj.TenantId
                    kind            = $obj.Kind
                    sku             = $obj.Sku
                    identity        = $obj.Identity
                    managed_by      = $obj.ManagedBy
                    plan            = $obj.Plan
                    zones           = $obj.Zones
                    tags            = $obj.Tags
                    properties      = $obj.Properties
                    collected_at    = $obj.CollectedAt
                }

                Invoke-CIEMQuery -Query @"
UPDATE azure_arm_resources
SET type = @type, name = @name, location = @location, resource_group = @resource_group,
    subscription_id = @subscription_id, tenant_id = @tenant_id, kind = @kind, sku = @sku,
    identity = @identity, managed_by = @managed_by, plan = @plan, zones = @zones,
    tags = @tags, properties = @properties, collected_at = @collected_at
WHERE id = @id
"@ -Parameters $parameters -AsNonQuery | Out-Null
            }
            return
        }

        $columnMap = @{
            Type           = 'type'
            Name           = 'name'
            Location       = 'location'
            ResourceGroup  = 'resource_group'
            SubscriptionId = 'subscription_id'
            TenantId       = 'tenant_id'
            Kind           = 'kind'
            Sku            = 'sku'
            Identity       = 'identity'
            ManagedBy      = 'managed_by'
            Plan           = 'plan'
            Zones          = 'zones'
            Tags           = 'tags'
            Properties     = 'properties'
            CollectedAt    = 'collected_at'
        }

        $setClauses = @()
        $parameters = @{ id = $Id }

        foreach ($paramName in $columnMap.Keys) {
            if ($PSBoundParameters.ContainsKey($paramName)) {
                $col = $columnMap[$paramName]
                $setClauses += "$col = @$col"
                $parameters[$col] = $PSBoundParameters[$paramName]
            }
        }

        if ($setClauses.Count -eq 0) {
            return
        }

        $sql = "UPDATE azure_arm_resources SET " + ($setClauses -join ', ') + " WHERE id = @id"
        Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null

        if ($PassThru) {
            Get-CIEMAzureArmResource -Id $Id
        }
    }
}