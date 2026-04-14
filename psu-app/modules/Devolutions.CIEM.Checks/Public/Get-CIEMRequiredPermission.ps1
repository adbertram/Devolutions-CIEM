function Get-CIEMRequiredPermission {
    <#
    .SYNOPSIS
        Gets the required permissions for running CIEM security checks and discovery endpoints.

    .DESCRIPTION
        Aggregates all unique permissions required across all enabled checks and discovery
        endpoints registered in azure_provider_apis. Returns permissions grouped by type,
        depending on the provider:
        - Azure: Microsoft Graph API, Azure Resource Manager RBAC, Key Vault data plane, Azure Roles
        - AWS: IAM actions (e.g., iam:ListUsers, s3:GetBucketPolicy)

        Discovery endpoint permissions (e.g., Directory.Read.All for Entra entity collection)
        are always included for the relevant provider, regardless of check filters.

    .PARAMETER Provider
        Filter to permissions for a specific cloud provider (Azure, AWS).

    .PARAMETER Service
        Filter to permissions required for a specific service (e.g., Entra, IAM, KeyVault, Storage, iam, s3).

    .PARAMETER CheckId
        Filter to permissions required for specific check IDs.

    .OUTPUTS
        [PSCustomObject] Object containing provider-appropriate permission properties:
        Azure: Graph, ARM, KeyVaultDataPlane, AzureRoles, CheckCount, DiscoveryEndpointCount, Summary
        AWS: IAM, CheckCount, Summary

    .EXAMPLE
        Get-CIEMRequiredPermission -Provider Azure
        # Returns all Azure permissions required for Azure checks and discovery endpoints

    .EXAMPLE
        Get-CIEMRequiredPermission -Provider AWS
        # Returns all IAM actions required for AWS checks

    .EXAMPLE
        Get-CIEMRequiredPermission -Service Entra
        # Returns permissions required for Entra ID checks and discovery endpoints
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateSet('Azure', 'AWS')]
        [string]$Provider,

        [Parameter()]
        [string]$Service,

        [Parameter()]
        [string[]]$CheckId
    )

    $ErrorActionPreference = 'Stop'

    # Get checks based on filters
    $getCheckParams = @{}
    if ($Provider) { $getCheckParams.Provider = $Provider }
    if ($Service) { $getCheckParams.Service = $Service }

    $checks = Get-CIEMCheck @getCheckParams

    if ($CheckId) {
        $checks = $checks | Where-Object { $CheckId -contains $_.Id }
    }

    # Aggregate unique permissions using List for efficient collection
    $graphPermissions = [System.Collections.Generic.List[string]]::new()
    $armPermissions = [System.Collections.Generic.List[string]]::new()
    $kvPermissions = [System.Collections.Generic.List[string]]::new()
    $iamPermissions = [System.Collections.Generic.List[string]]::new()
    $endpointAzureRoles = [System.Collections.Generic.List[string]]::new()

    # Aggregate from checks
    $checkCount = 0
    if ($checks) {
        $checkCount = @($checks).Count
        foreach ($check in $checks) {
            $perms = $check.Permissions
            if ($perms.Graph) {
                foreach ($p in $perms.Graph) { $graphPermissions.Add($p) }
            }
            if ($perms.ARM) {
                foreach ($p in $perms.ARM) { $armPermissions.Add($p) }
            }
            if ($perms.KeyVaultDataPlane) {
                foreach ($p in $perms.KeyVaultDataPlane) { $kvPermissions.Add($p) }
            }
            if ($perms.IAM) {
                foreach ($p in $perms.IAM) { $iamPermissions.Add($p) }
            }
        }
    }

    # Aggregate discovery endpoint permissions from azure_provider_apis (scoped rows)
    $discoveryEndpointCount = 0
    if ($Provider -ne 'AWS') {
        $endpointParams = @{ HasPermissions = $true }
        if ($Service) { $endpointParams.Service = $Service }
        $endpoints = @(GetCIEMAzureProviderApi @endpointParams)
        $discoveryEndpointCount = $endpoints.Count

        foreach ($endpoint in $endpoints) {
            $perms = $endpoint.Permissions
            if ($perms.Graph) {
                foreach ($p in $perms.Graph) { $graphPermissions.Add($p) }
            }
            if ($perms.ARM) {
                foreach ($p in $perms.ARM) { $armPermissions.Add($p) }
            }
            if ($perms.KeyVaultDataPlane) {
                foreach ($p in $perms.KeyVaultDataPlane) { $kvPermissions.Add($p) }
            }
            if ($perms.AzureRoles) {
                foreach ($p in $perms.AzureRoles) { $endpointAzureRoles.Add($p) }
            }
        }
    }

    if (-not $checks -and $discoveryEndpointCount -eq 0) {
        Write-Warning "No checks or discovery endpoints found matching the specified criteria."
        return [PSCustomObject]@{
            Graph                  = @()
            ARM                    = @()
            KeyVaultDataPlane      = @()
            AzureRoles             = @()
            IAM                    = @()
            CheckCount             = 0
            DiscoveryEndpointCount = 0
            Summary                = "No checks or discovery endpoints found."
        }
    }

    # Get unique and sort (wrap in @() to ensure arrays)
    $graphPermissions = @($graphPermissions | Select-Object -Unique | Sort-Object)
    $armPermissions = @($armPermissions | Select-Object -Unique | Sort-Object)
    $kvPermissions = @($kvPermissions | Select-Object -Unique | Sort-Object)
    $iamPermissions = @($iamPermissions | Select-Object -Unique | Sort-Object)

    # Determine required Azure RBAC roles based on check permissions + endpoint permissions
    $azureRoles = @()
    if ($graphPermissions.Count -gt 0 -or $armPermissions.Count -gt 0 -or $kvPermissions.Count -gt 0 -or $endpointAzureRoles.Count -gt 0) {
        # Subscription Reader is always required for subscription discovery (ARM REST API)
        $azureRoles = @('Reader')

        # ARM permissions: Reader role covers all */read actions
        if ($armPermissions.Count -gt 0) {
            $nonReadPermissions = @($armPermissions | Where-Object { $_ -notmatch '/read$' })
            if ($nonReadPermissions.Count -gt 0) {
                Write-Warning "Some ARM permissions require write access. Review permissions and assign appropriate roles."
            }
        }

        # Key Vault data plane permissions: Map to specific RBAC roles
        if ($kvPermissions -contains 'secrets/list' -or $kvPermissions -contains 'secrets/get') {
            $azureRoles += 'Key Vault Secrets User'
        }
        if ($kvPermissions -contains 'keys/list' -or $kvPermissions -contains 'keys/get') {
            $azureRoles += 'Key Vault Crypto User'
        }

        # Merge explicit AzureRoles from discovery endpoints
        foreach ($role in $endpointAzureRoles) {
            $azureRoles += $role
        }

        $azureRoles = @($azureRoles | Select-Object -Unique | Sort-Object)
    }

    # Build summary
    $summaryParts = @()
    $summaryParts += "Permissions required for $checkCount check(s) and $discoveryEndpointCount discovery endpoint(s):"

    if ($graphPermissions.Count -gt 0) {
        $summaryParts += ""
        $summaryParts += "Microsoft Graph API Permissions (Application):"
        foreach ($perm in $graphPermissions) {
            $summaryParts += "  - $perm"
        }
    }

    if ($armPermissions.Count -gt 0) {
        $summaryParts += ""
        $summaryParts += "Azure Resource Manager RBAC Actions:"
        foreach ($perm in $armPermissions) {
            $summaryParts += "  - $perm"
        }
    }

    if ($kvPermissions.Count -gt 0) {
        $summaryParts += ""
        $summaryParts += "Key Vault Data Plane Permissions:"
        foreach ($perm in $kvPermissions) {
            $summaryParts += "  - $perm"
        }
    }

    if ($azureRoles.Count -gt 0) {
        $summaryParts += ""
        $summaryParts += "Required Azure RBAC Roles (assign at subscription scope):"
        $summaryParts += "  - Reader (required for subscription discovery)"
        foreach ($role in @($azureRoles | Where-Object { $_ -ne 'Reader' })) {
            $summaryParts += "  - $role"
        }
    }

    if ($discoveryEndpointCount -gt 0) {
        $summaryParts += ""
        $summaryParts += "Discovery Endpoint Permissions ($discoveryEndpointCount endpoints):"
        $summaryParts += "  Permissions above include requirements for data collection endpoints"
        $summaryParts += "  registered in azure_provider_apis (Entra, ResourceGraph, IAM)."
    }

    if ($iamPermissions.Count -gt 0) {
        $summaryParts += ""
        $summaryParts += "AWS IAM Actions:"
        foreach ($perm in $iamPermissions) {
            $summaryParts += "  - $perm"
        }
    }

    [PSCustomObject]@{
        Graph                  = @($graphPermissions)
        ARM                    = @($armPermissions)
        KeyVaultDataPlane      = @($kvPermissions)
        AzureRoles             = @($azureRoles)
        IAM                    = @($iamPermissions)
        CheckCount             = $checkCount
        DiscoveryEndpointCount = $discoveryEndpointCount
        Summary                = $summaryParts -join "`n"
    }
}
