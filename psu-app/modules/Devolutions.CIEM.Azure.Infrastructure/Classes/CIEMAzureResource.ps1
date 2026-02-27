class CIEMAzureResource {
    [string]$Id
    [string]$ProviderId
    [string]$Type
    [string]$ParentId
    [string]$Name
    [string]$Location
    [string]$Tags
    [datetime]$CollectedAt

    CIEMAzureResource() {
        $this.CollectedAt = Get-Date
    }
}
