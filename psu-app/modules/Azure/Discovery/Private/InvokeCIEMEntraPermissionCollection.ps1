function InvokeCIEMEntraPermissionCollection {
    param(
        [Parameter(Mandatory)]
        [PSObject[]]$ServicePrincipals
    )

    $now = (Get-Date).ToString('o')
    $uniqueServicePrincipals = @($ServicePrincipals | Group-Object Id | ForEach-Object { $_.Group[0] })

    if ($uniqueServicePrincipals.Count -gt 0) {
        Write-Progress -Activity 'Azure Discovery' -Status "Collecting app role assignments ($($uniqueServicePrincipals.Count) service principals)" -PercentComplete 74

        $batchRequests = @(
            foreach ($servicePrincipal in $uniqueServicePrincipals) {
                @{
                    Id = $servicePrincipal.Id
                    Method = 'GET'
                    Path = "/servicePrincipals/$($servicePrincipal.Id)/appRoleAssignments"
                }
            }
        )

        $batchResults = Invoke-AzureApi -Api Graph -Requests $batchRequests -ResourceName 'AppRoleAssignmentBatch'
        foreach ($servicePrincipal in $uniqueServicePrincipals) {
            if (-not $batchResults.ContainsKey($servicePrincipal.Id)) {
                throw "InvokeCIEMEntraPermissionCollection missing batch response for '$($servicePrincipal.Id)'."
            }

            $batchResult = $batchResults[$servicePrincipal.Id]
            if (-not $batchResult.Success) {
                $errorDetail = if ($batchResult.Error) { $batchResult.Error } else { "Status $($batchResult.StatusCode)" }
                throw "InvokeCIEMEntraPermissionCollection failed for '$($servicePrincipal.Id)': $errorDetail"
            }

            foreach ($assignment in @($batchResult.Items)) {
                $resource = [CIEMAzureEntraResource]::new()
                $resource.Id = "$($servicePrincipal.Id)_$($assignment.id)"
                $resource.Type = 'appRoleAssignment'
                $resource.DisplayName = $null
                $resource.ParentId = $servicePrincipal.Id
                $resource.Properties = $assignment | ConvertTo-Json -Depth 5 -Compress
                $resource.CollectedAt = $now
                $resource
            }
        }
    }

    Write-Progress -Activity 'Azure Discovery' -Status 'Collecting OAuth2 permission grants' -PercentComplete 78 -CurrentOperation 'Delegated permissions'
    $grants = @(Invoke-AzureApi -Api Graph -Path '/oauth2PermissionGrants' -ResourceName 'OAuth2PermissionGrants')
    foreach ($grant in $grants) {
        $resource = [CIEMAzureEntraResource]::new()
        $resource.Id = $grant.id
        $resource.Type = 'oauth2PermissionGrant'
        $resource.DisplayName = $null
        $resource.ParentId = $grant.clientId
        $resource.Properties = $grant | ConvertTo-Json -Depth 5 -Compress
        $resource.CollectedAt = $now
        $resource
    }
}
