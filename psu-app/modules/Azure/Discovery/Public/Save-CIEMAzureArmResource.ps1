function Save-CIEMAzureArmResource {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation for bulk data')]
    [OutputType('CIEMAzureArmResource[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Type,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
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

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [Parameter()]
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $collectedAt = if ($obj.CollectedAt) { $obj.CollectedAt } else { (Get-Date).ToString('o') }
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
                    collected_at    = $collectedAt
                }

                $sql = @"
INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, kind, sku, identity, managed_by, plan, zones, tags, properties, collected_at)
VALUES (@id, @type, @name, @location, @resource_group, @subscription_id, @tenant_id, @kind, @sku, @identity, @managed_by, @plan, @zones, @tags, @properties, @collected_at)
"@

                if ($Connection) {
                    Invoke-PSUSQLiteQuery -Connection $Connection -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
                } else {
                    Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
                }
            }
            return
        }

        if (-not $CollectedAt) {
            $CollectedAt = (Get-Date).ToString('o')
        }

        $parameters = @{
            id              = $Id
            type            = $Type
            name            = $Name
            location        = $Location
            resource_group  = $ResourceGroup
            subscription_id = $SubscriptionId
            tenant_id       = $TenantId
            kind            = $Kind
            sku             = $Sku
            identity        = $Identity
            managed_by      = $ManagedBy
            plan            = $Plan
            zones           = $Zones
            tags            = $Tags
            properties      = $Properties
            collected_at    = $CollectedAt
        }

        $sql = @"
INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, kind, sku, identity, managed_by, plan, zones, tags, properties, collected_at)
VALUES (@id, @type, @name, @location, @resource_group, @subscription_id, @tenant_id, @kind, @sku, @identity, @managed_by, @plan, @zones, @tags, @properties, @collected_at)
"@

        if ($Connection) {
            Invoke-PSUSQLiteQuery -Connection $Connection -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
        } else {
            Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
        }
    }
}
