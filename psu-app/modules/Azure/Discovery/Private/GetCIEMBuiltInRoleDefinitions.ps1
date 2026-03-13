function GetCIEMBuiltInRoleDefinitions {
    $now = (Get-Date).ToString('o')

    $armApi = Get-CIEMAzureProviderApi -Name 'ARM'
    $uri = "$(($armApi.BaseUrl).TrimEnd('/'))/providers/Microsoft.Authorization/roleDefinitions?api-version=2022-05-01-preview&`$filter=type eq 'BuiltInRole'"

    $results = Invoke-AzureApi -Uri $uri -ResourceName 'BuiltInRoleDefinitions'

    foreach ($item in $results) {
        $resource = [CIEMAzureArmResource]::new()
        $resource.Id             = $item.id
        $resource.Type           = 'microsoft.authorization/roledefinitions'
        $resource.Name           = $item.name
        $resource.Kind           = 'BuiltInRole'
        $resource.Properties     = if ($item.properties) { $item.properties | ConvertTo-Json -Depth 10 -Compress } else { $null }
        $resource.CollectedAt    = $now
        $resource
    }
}
