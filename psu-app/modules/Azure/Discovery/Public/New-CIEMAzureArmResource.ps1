function New-CIEMAzureArmResource {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a data record in database')]
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
        [PSObject[]]$InputObject
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                New-CIEMAzureArmResource `
                    -Id $obj.Id `
                    -Type $obj.Type `
                    -Name $obj.Name `
                    -Location $obj.Location `
                    -ResourceGroup $obj.ResourceGroup `
                    -SubscriptionId $obj.SubscriptionId `
                    -TenantId $obj.TenantId `
                    -Kind $obj.Kind `
                    -Sku $obj.Sku `
                    -Identity $obj.Identity `
                    -ManagedBy $obj.ManagedBy `
                    -Plan $obj.Plan `
                    -Zones $obj.Zones `
                    -Tags $obj.Tags `
                    -Properties $obj.Properties `
                    -CollectedAt $obj.CollectedAt
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

        Invoke-CIEMQuery -Query @"
INSERT INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, kind, sku, identity, managed_by, plan, zones, tags, properties, collected_at)
VALUES (@id, @type, @name, @location, @resource_group, @subscription_id, @tenant_id, @kind, @sku, @identity, @managed_by, @plan, @zones, @tags, @properties, @collected_at)
"@ -Parameters $parameters -AsNonQuery | Out-Null

        Get-CIEMAzureArmResource -Id $Id
    }
}
