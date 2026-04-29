@{
    local = @{
        UrlVariable      = 'LOCAL_PSU_URL'
        TokenVariable    = 'LOCAL_PSU_TOKEN'
        IsAzure          = $false
        UsesPublishPoint = $true
    }
    azure = @{
        UrlVariable      = 'AZURE_PSU_URL'
        TokenVariable    = 'AZURE_PSU_TOKEN'
        IsAzure          = $true
        UsesPublishPoint = $false
        ResourceGroup    = 'devolutions-ciem-rg'
    }
}
