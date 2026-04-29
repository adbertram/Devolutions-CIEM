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
                UpdateCIEMAzureEntity -Entity 'ArmResource' -Filters @{ Id = $obj.Id } -Values @{
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
                    CollectedAt = $obj.CollectedAt
                    LastSeenAt = $obj.LastSeenAt
                }
            }
            return
        }

        $values = @{}
        foreach ($paramName in @(
            'Type', 'Name', 'Location', 'ResourceGroup', 'SubscriptionId',
            'TenantId', 'Kind', 'Sku', 'Identity', 'ManagedBy', 'Plan',
            'Zones', 'Tags', 'Properties', 'CollectedAt'
        )) {
            if ($PSBoundParameters.ContainsKey($paramName)) {
                $values[$paramName] = $PSBoundParameters[$paramName]
            }
        }

        if ($values.Count -eq 0) {
            return
        }

        UpdateCIEMAzureEntity -Entity 'ArmResource' -Filters @{ Id = $Id } -Values $values

        if ($PassThru) {
            Get-CIEMAzureArmResource -Id $Id
        }
    }
}
