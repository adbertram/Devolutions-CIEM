function Import-CIEMProviderMigration {
    <#
    .SYNOPSIS
        One-time migration from old config-based provider storage to CIEM:Providers cache.

    .DESCRIPTION
        Checks if CIEM:Providers cache is empty. If so, reads the old azure/aws
        sections from CIEM:Config and converts them to provider objects in the
        new CIEM:Providers cache format.

        This function is idempotent — it only runs when the providers cache is empty.
    #>
    [CmdletBinding()]
    param()

    # Check if providers cache already populated
    $existing = $null
    try {
        $existing = Get-PSUCache -Key 'CIEM:Providers' -ErrorAction SilentlyContinue
    }
    catch {
        # Not in PSU context — nothing to migrate
        return
    }

    # If providers already exist, skip migration
    if ($existing -and @($existing).Count -gt 0 -and $null -ne $existing[0]) {
        return
    }

    Write-Verbose "CIEM: Running one-time provider migration from CIEM:Config..."

    # Read old config
    $oldConfig = $null
    try {
        $oldConfig = Get-PSUCache -Key 'CIEM:Config' -ErrorAction SilentlyContinue
    }
    catch {
        return
    }

    if (-not $oldConfig) {
        return
    }

    $providers = @()

    # Migrate Azure if present in old config
    if ($oldConfig.PSObject.Properties['azure']) {
        $azure = $oldConfig.azure
        $azureAuth = if ($azure.PSObject.Properties['authentication']) { $azure.authentication } else { $null }

        $authObj = [PSCustomObject]@{
            Provider = 'Azure'
            Enabled  = [bool]$azure.enabled
            Method   = if ($azureAuth -and $azureAuth.PSObject.Properties['method']) { $azureAuth.method } else { 'ServicePrincipalSecret' }
            TenantId = if ($azureAuth -and $azureAuth.PSObject.Properties['tenantId']) { $azureAuth.tenantId } else { $null }
            ClientId = if ($azureAuth -and $azureAuth.PSObject.Properties['servicePrincipal'] -and $azureAuth.servicePrincipal.PSObject.Properties['clientId']) { $azureAuth.servicePrincipal.clientId } else { $null }
            ManagedIdentityClientId = if ($azureAuth -and $azureAuth.PSObject.Properties['managedIdentity'] -and $azureAuth.managedIdentity.PSObject.Properties['clientId']) { $azureAuth.managedIdentity.clientId } else { $null }
        }

        $endpoints = if ($azure.PSObject.Properties['endpoints']) {
            $azure.endpoints
        }
        else {
            [PSCustomObject]@{
                graphApi = 'https://graph.microsoft.com/v1.0'
                armApi   = 'https://management.azure.com'
            }
        }

        $resourceFilter = if ($azure.PSObject.Properties['subscriptionFilter']) { @($azure.subscriptionFilter) } else { @() }

        $isDefault = if ($oldConfig.PSObject.Properties['cloudProvider']) { $oldConfig.cloudProvider -eq 'Azure' } else { $true }

        $providers += [PSCustomObject]@{
            Name           = 'Azure'
            Enabled        = [bool]$azure.enabled
            IsDefault      = $isDefault
            Authentication = $authObj
            Endpoints      = $endpoints
            ResourceFilter = $resourceFilter
        }
    }

    # Migrate AWS if present in old config
    if ($oldConfig.PSObject.Properties['aws']) {
        $aws = $oldConfig.aws
        $awsAuth = if ($aws.PSObject.Properties['authentication']) { $aws.authentication } else { $null }

        $authObj = [PSCustomObject]@{
            Provider = 'AWS'
            Enabled  = [bool]$aws.enabled
            Method   = if ($awsAuth -and $awsAuth.PSObject.Properties['method']) { $awsAuth.method } else { 'CurrentProfile' }
            Profile  = if ($awsAuth -and $awsAuth.PSObject.Properties['profile']) { $awsAuth.profile } else { $null }
            Region   = if ($awsAuth -and $awsAuth.PSObject.Properties['region']) { $awsAuth.region } else { $null }
        }

        $resourceFilter = if ($aws.PSObject.Properties['accountFilter']) { @($aws.accountFilter) } else { @() }

        $isDefault = if ($oldConfig.PSObject.Properties['cloudProvider']) { $oldConfig.cloudProvider -eq 'AWS' } else { $false }

        $providers += [PSCustomObject]@{
            Name           = 'AWS'
            Enabled        = [bool]$aws.enabled
            IsDefault      = $isDefault
            Authentication = $authObj
            Endpoints      = [PSCustomObject]@{}
            ResourceFilter = $resourceFilter
        }
    }

    if ($providers.Count -gt 0) {
        Set-PSUCache -Key 'CIEM:Providers' -Value $providers -ErrorAction SilentlyContinue
        Write-Verbose "CIEM: Migrated $($providers.Count) provider(s) to CIEM:Providers cache"
    }
}
