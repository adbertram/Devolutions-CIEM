function Save-CIEMAzureServiceData {
    <#
    .SYNOPSIS
        Upserts one or more azure_service_data rows.
    .DESCRIPTION
        Inserts or replaces rows in azure_service_data. Accepts individual parameters
        (ByProperties) or a pipeline/array of CIEMAzureServiceData objects (InputObject).
        The id is derived deterministically from provider_id + subscription_id + service_name
        + resource_type + resource_id so repeated scans are idempotent.
    .PARAMETER ProviderId
        Provider identifier (e.g. 'azure').
    .PARAMETER SubscriptionId
        Azure subscription GUID. Null/empty for tenant-scoped resources.
    .PARAMETER ServiceName
        Service name: 'Defender', 'Monitor', 'Network', 'Policy', 'Vm'.
    .PARAMETER ResourceType
        Resource type within the service (e.g. 'Pricing', 'AlertRule', 'VirtualMachine').
    .PARAMETER ResourceId
        ARM resource ID or natural key (e.g. pricing name for Defender Pricings).
    .PARAMETER ResourceName
        Human-readable display name.
    .PARAMETER Data
        The raw data object (PSCustomObject/hashtable). Serialized to JSON internally.
    .PARAMETER InputObject
        One or more CIEMAzureServiceData objects (pipeline-compatible).
    .EXAMPLE
        Save-CIEMAzureServiceData -ProviderId azure -ServiceName Defender -ResourceType Pricing -ResourceId VirtualMachines -ResourceName VirtualMachines -Data $pricingObj -SubscriptionId $sub
    .EXAMPLE
        $items | Save-CIEMAzureServiceData
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$ProviderId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$SubscriptionId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$ServiceName,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$ResourceType,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$ResourceId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ResourceName,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [object]$Data,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureServiceData[]]$InputObject
    )

    process {
        $now = (Get-Date).ToString('o')

        $rows = if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            $InputObject
        } else {
            @([CIEMAzureServiceData]::new(
                "$ProviderId|$SubscriptionId|$ServiceName|$ResourceType|$ResourceId",
                $ProviderId, $SubscriptionId, $ServiceName, $ResourceType,
                $ResourceId, $ResourceName, $Data, $now
            ))
        }

        foreach ($row in $rows) {
            $id = if ($row.Id) { $row.Id } else {
                "$($row.ProviderId)|$($row.SubscriptionId)|$($row.ServiceName)|$($row.ResourceType)|$($row.ResourceId)"
            }
            $dataJson = if ($row.Data -is [string]) { $row.Data } else {
                $row.Data | ConvertTo-Json -Depth 20 -Compress
            }
            $collectedAt = if ($row.CollectedAt) { $row.CollectedAt } else { $now }

            Invoke-CIEMQuery -Query @"
INSERT OR REPLACE INTO azure_service_data
    (id, provider_id, subscription_id, service_name, resource_type, resource_id, resource_name, data, collected_at)
VALUES
    (@id, @provider_id, @subscription_id, @service_name, @resource_type, @resource_id, @resource_name, @data, @collected_at)
"@ -Parameters @{
                id              = $id
                provider_id     = $row.ProviderId
                subscription_id = $row.SubscriptionId
                service_name    = $row.ServiceName
                resource_type   = $row.ResourceType
                resource_id     = $row.ResourceId
                resource_name   = $row.ResourceName
                data            = $dataJson
                collected_at    = $collectedAt
            } -AsNonQuery | Out-Null
        }
    }
}
