class CIEMAzureServiceData {
    [string]$Id
    [string]$ProviderId
    [string]$SubscriptionId
    [string]$ServiceName
    [string]$ResourceType
    [string]$ResourceId
    [string]$ResourceName
    [object]$Data
    [string]$CollectedAt

    CIEMAzureServiceData() {}

    CIEMAzureServiceData(
        [string]$id,
        [string]$providerId,
        [string]$subscriptionId,
        [string]$serviceName,
        [string]$resourceType,
        [string]$resourceId,
        [string]$resourceName,
        [object]$data,
        [string]$collectedAt
    ) {
        $this.Id             = $id
        $this.ProviderId     = $providerId
        $this.SubscriptionId = $subscriptionId
        $this.ServiceName    = $serviceName
        $this.ResourceType   = $resourceType
        $this.ResourceId     = $resourceId
        $this.ResourceName   = $resourceName
        $this.Data           = $data
        $this.CollectedAt    = $collectedAt
    }
}
