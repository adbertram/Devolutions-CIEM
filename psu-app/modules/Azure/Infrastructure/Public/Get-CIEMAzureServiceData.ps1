function Get-CIEMAzureServiceData {
    <#
    .SYNOPSIS
        Retrieves rows from azure_service_data with optional filters.
    .DESCRIPTION
        Queries the azure_service_data table and returns typed CIEMAzureServiceData objects.
        The Data property is deserialized from JSON back to PSCustomObject.
    .PARAMETER ProviderId
        Filter by provider (e.g. 'azure').
    .PARAMETER ServiceName
        Filter by service name (e.g. 'Defender').
    .PARAMETER ResourceType
        Filter by resource type (e.g. 'Pricing').
    .PARAMETER SubscriptionId
        Filter by subscription GUID.
    .OUTPUTS
        [CIEMAzureServiceData[]]
    .EXAMPLE
        Get-CIEMAzureServiceData -ProviderId azure -ServiceName Defender -ResourceType Pricing
    .EXAMPLE
        Get-CIEMAzureServiceData -ProviderId azure -ServiceName Monitor
    #>
    [CmdletBinding()]
    [OutputType('CIEMAzureServiceData[]')]
    param(
        [Parameter()]
        [string]$ProviderId,

        [Parameter()]
        [string]$ServiceName,

        [Parameter()]
        [string]$ResourceType,

        [Parameter()]
        [string]$SubscriptionId
    )

    $where  = @('1=1')
    $params = @{}

    if ($ProviderId)     { $where += 'provider_id = @provider_id';         $params.provider_id     = $ProviderId }
    if ($ServiceName)    { $where += 'service_name = @service_name';       $params.service_name    = $ServiceName }
    if ($ResourceType)   { $where += 'resource_type = @resource_type';     $params.resource_type   = $ResourceType }
    if ($SubscriptionId) { $where += 'subscription_id = @subscription_id'; $params.subscription_id = $SubscriptionId }

    $query = "SELECT * FROM azure_service_data WHERE $($where -join ' AND ') ORDER BY service_name, resource_type, resource_id"
    $rows  = Invoke-CIEMQuery -Query $query -Parameters $params

    foreach ($row in $rows) {
        $obj = [CIEMAzureServiceData]::new()
        $obj.Id             = $row.id
        $obj.ProviderId     = $row.provider_id
        $obj.SubscriptionId = $row.subscription_id
        $obj.ServiceName    = $row.service_name
        $obj.ResourceType   = $row.resource_type
        $obj.ResourceId     = $row.resource_id
        $obj.ResourceName   = $row.resource_name
        $obj.Data           = $row.data | ConvertFrom-Json
        $obj.CollectedAt    = $row.collected_at
        $obj
    }
}
