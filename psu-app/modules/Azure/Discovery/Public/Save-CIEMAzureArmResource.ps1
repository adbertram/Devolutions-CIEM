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

        [Parameter(ParameterSetName = 'ByProperties')]
        [long]$LastSeenAt = 0,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [Parameter()]
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    begin {
        $ErrorActionPreference = 'Stop'
        $items = [System.Collections.Generic.List[object]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $items.Add([pscustomobject]@{
                    Id = $obj.Id
                    Type = $obj.Type
                    Name = $obj.Name
                    Location = $obj.Location
                    ResourceGroup = $obj.ResourceGroup
                    SubscriptionId = $obj.SubscriptionId
                    TenantId = $obj.TenantId
                    Kind = $obj.Kind
                    Sku = $obj.Sku
                    Identity = $obj.Identity
                    ManagedBy = $obj.ManagedBy
                    Plan = $obj.Plan
                    Zones = $obj.Zones
                    Tags = $obj.Tags
                    Properties = $obj.Properties
                    CollectedAt = if ($obj.CollectedAt) { $obj.CollectedAt } else { (Get-Date).ToString('o') }
                    LastSeenAt = if ($obj.PSObject.Properties.Name -contains 'LastSeenAt') { [long]$obj.LastSeenAt } else { 0 }
                })
            }
            return
        }

        $items.Add([pscustomobject]@{
            Id = $Id
            Type = $Type
            Name = $Name
            Location = $Location
            ResourceGroup = $ResourceGroup
            SubscriptionId = $SubscriptionId
            TenantId = $TenantId
            Kind = $Kind
            Sku = $Sku
            Identity = $Identity
            ManagedBy = $ManagedBy
            Plan = $Plan
            Zones = $Zones
            Tags = $Tags
            Properties = $Properties
            CollectedAt = if ($CollectedAt) { $CollectedAt } else { (Get-Date).ToString('o') }
            LastSeenAt = $LastSeenAt
        })
    }

    end {
        if ($items.Count -eq 0) {
            return
        }

        SaveCIEMAzureTable -Entity 'ArmResource' -Items $items.ToArray() -Connection $Connection
    }
}
