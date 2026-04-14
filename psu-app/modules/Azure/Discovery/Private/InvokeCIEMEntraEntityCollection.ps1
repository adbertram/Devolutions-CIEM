function InvokeCIEMEntraEntityCollection {
    $ErrorActionPreference = 'Stop'

    $now = (Get-Date).ToString('o')

    function MapEntraResource($type, $item) {
        $ErrorActionPreference = 'Stop'
        $r = [CIEMAzureEntraResource]::new()
        $r.Id          = $item.id
        $r.Type        = $type
        $r.DisplayName = $item.displayName
        $r.ParentId    = $null
        $r.Properties  = $item | ConvertTo-Json -Depth 10 -Compress
        $r.CollectedAt = $now
        $r
    }

    # --- Users (with signInActivity attempt) ---
    $userSelect = 'id,displayName,userPrincipalName,mail,accountEnabled,userType,createdDateTime,signInActivity'
    try {
        $users = @(Invoke-AzureApi -Api Graph -Path "/users?`$select=$userSelect" -ResourceName 'Users' -ErrorAction Stop)
    }
    catch {
        Write-Warning "InvokeCIEMEntraEntityCollection: signInActivity unavailable (Premium P1 / AuditLog.Read.All required) — collecting users without sign-in data"
        $users = @(Invoke-AzureApi -Api Graph -Path "/users?`$select=id,displayName,userPrincipalName,mail,accountEnabled,userType,createdDateTime" -ResourceName 'Users')
    }
    foreach ($u in $users) { MapEntraResource 'user' $u }

    # --- Groups ---
    $groups = @(Invoke-AzureApi -Api Graph -Path "/groups?`$select=id,displayName,mail,groupTypes,securityEnabled,mailEnabled,createdDateTime" -ResourceName 'Groups')
    foreach ($g in $groups) { MapEntraResource 'group' $g }

    # --- Service Principals (with signInActivity via /beta) ---
    $spSelect = 'id,displayName,appId,servicePrincipalType,accountEnabled,createdDateTime,signInActivity'
    try {
        $sps = @(Invoke-AzureApi -Api GraphBeta -Path "/servicePrincipals?`$select=$spSelect" -ResourceName 'ServicePrincipals' -ErrorAction Stop)
    }
    catch {
        Write-Warning "InvokeCIEMEntraEntityCollection: SP signInActivity unavailable — collecting SPs without sign-in data"
        $sps = @(Invoke-AzureApi -Api Graph -Path "/servicePrincipals?`$select=id,displayName,appId,servicePrincipalType,accountEnabled,createdDateTime" -ResourceName 'ServicePrincipals')
    }
    foreach ($sp in $sps) { MapEntraResource 'servicePrincipal' $sp }

    # --- Applications ---
    $apps = @(Invoke-AzureApi -Api Graph -Path "/applications?`$select=id,displayName,appId,createdDateTime,signInAudience" -ResourceName 'Applications')
    foreach ($app in $apps) { MapEntraResource 'application' $app }

    # --- Directory Roles (only activated roles) ---
    $roles = @(Invoke-AzureApi -Api Graph -Path "/directoryRoles?`$select=id,displayName,description,roleTemplateId" -ResourceName 'DirectoryRoles')
    foreach ($role in $roles) { MapEntraResource 'directoryRole' $role }
}
