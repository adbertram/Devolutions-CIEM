function InvokeCIEMEntraPermissionCollection {
    param(
        [Parameter(Mandatory)]
        [PSObject[]]$ServicePrincipals
    )

    $now = (Get-Date).ToString('o')
    $totalSPs = $ServicePrincipals.Count

    # --- App Role Assignments (per SP) ---
    $spIndex = 0
    foreach ($sp in $ServicePrincipals) {
        $spIndex++
        Write-Progress -Activity 'Azure Discovery' -Status "Collecting app role assignments ($spIndex/$totalSPs)" -PercentComplete (70 + [math]::Floor(8 * $spIndex / $totalSPs)) -CurrentOperation $sp.DisplayName
        $assignments = @(Invoke-AzureApi -Api Graph -Path "/servicePrincipals/$($sp.Id)/appRoleAssignments" -ResourceName "AppRoleAssignments/$($sp.Id)")
        foreach ($a in $assignments) {
            $r = [CIEMAzureEntraResource]::new()
            # Composite key for uniqueness (junction records don't have globally-unique IDs)
            $r.Id          = "$($sp.Id)_$($a.id)"
            $r.Type        = 'appRoleAssignment'
            $r.DisplayName = $null
            $r.ParentId    = $sp.Id
            $r.Properties  = $a | ConvertTo-Json -Depth 5 -Compress
            $r.CollectedAt = $now
            $r
        }
    }

    # --- OAuth2 Permission Grants (single paginated call) ---
    Write-Progress -Activity 'Azure Discovery' -Status 'Collecting OAuth2 permission grants' -PercentComplete 78 -CurrentOperation 'Delegated permissions'
    $grants = @(Invoke-AzureApi -Api Graph -Path '/oauth2PermissionGrants' -ResourceName 'OAuth2PermissionGrants')
    foreach ($g in $grants) {
        $r = [CIEMAzureEntraResource]::new()
        $r.Id          = $g.id
        $r.Type        = 'oauth2PermissionGrant'
        $r.DisplayName = $null
        $r.ParentId    = $g.clientId
        $r.Properties  = $g | ConvertTo-Json -Depth 5 -Compress
        $r.CollectedAt = $now
        $r
    }
}
