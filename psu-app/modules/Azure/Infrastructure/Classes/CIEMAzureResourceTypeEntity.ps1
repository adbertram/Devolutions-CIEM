class CIEMAzureResourceTypeEntity {
    [string]$Id
    [int]$ProviderApiId
    [string]$DisplayName
    [bool]$IsCollectible

    CIEMAzureResourceTypeEntity() {
        $this.IsCollectible = $true
    }
}
