function New-CIEMAzureManagedIdentity {
    <#
    .SYNOPSIS
        Configures an Azure Web App's managed identity with all permissions required for CIEM security checks.

    .DESCRIPTION
        Assigns all permissions required to run Devolutions CIEM security checks to an existing Azure Web App's
        system-assigned managed identity. This includes:
        - Microsoft Graph API application permissions (via admin consent)
        - Azure Resource Manager RBAC role assignment (Reader)
        - Key Vault data plane RBAC roles

        The function uses Get-CIEMRequiredPermission to determine the exact permissions needed.

        Unlike New-PSUAzureServicePrincipal, this function does not create credentials - managed identities
        authenticate automatically when running within Azure services.

    .PARAMETER WebAppName
        The name of the Azure Web App whose managed identity will be configured.

    .PARAMETER ResourceGroupName
        The resource group containing the Azure Web App.

    .PARAMETER Scope
        The scope for the ARM RBAC role assignment. Can be a subscription or management group.
        Examples:
        - "/subscriptions/<subscription-id>"
        - "/providers/Microsoft.Management/managementGroups/<mg-name>"

    .PARAMETER EnableSystemAssignedIdentity
        If the web app does not have a system-assigned managed identity enabled, enable it.
        Default: $true

    .PARAMETER SkipRoleAssignment
        Skip the ARM RBAC role assignment. Useful if you want to assign at a different scope later.

    .PARAMETER SkipAdminConsent
        Skip granting admin consent for Graph API permissions. You will need to grant consent manually
        in the Azure Portal.

    .OUTPUTS
        [PSCustomObject] Object containing:
        - WebAppName: The web app name
        - ResourceGroupName: The resource group name
        - PrincipalId: The managed identity's service principal object ID
        - TenantId: The Azure AD tenant ID
        - Permissions: The permissions configured

    .EXAMPLE
        New-CIEMAzureManagedIdentity -WebAppName "devolutions-ciem-psu" -ResourceGroupName "devolutions-ciem-rg" -Scope "/subscriptions/12345678-1234-1234-1234-123456789012"
        # Configures the managed identity for the specified web app

    .EXAMPLE
        New-CIEMAzureManagedIdentity -WebAppName "my-psu-app" -ResourceGroupName "my-rg" -Scope "/providers/Microsoft.Management/managementGroups/my-mg" -SkipAdminConsent
        # Configures at management group scope, skipping admin consent (grant manually later)

    .NOTES
        Required modules (auto-installed if not present):
        - Az.Accounts (for Connect-AzAccount)
        - Az.Resources (for role assignment cmdlets)
        - Az.Websites (for web app cmdlets)
        - Microsoft.Graph.Applications (for Graph API permission grants, unless -SkipAdminConsent)

        Required Azure permissions:
        - Global Administrator or Privileged Role Administrator role (for admin consent)
        - Owner or User Access Administrator role on the target scope (for role assignment)
        - Contributor on the web app (if enabling managed identity)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$WebAppName,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [ValidatePattern('^/(subscriptions/[a-f0-9-]+|providers/Microsoft\.Management/managementGroups/.+)$')]
        [string]$Scope,

        [Parameter()]
        [switch]$EnableSystemAssignedIdentity = $true,

        [Parameter()]
        [switch]$SkipRoleAssignment,

        [Parameter()]
        [switch]$SkipAdminConsent
    )

    $ErrorActionPreference = 'Stop'

    #region Prerequisites Check
    Write-Verbose "Checking prerequisites..."

    # Check Azure connection
    $context = Get-AzContext
    if (-not $context) {
        throw "Not connected to Azure. Run Connect-AzAccount first."
    }

    $tenantId = $context.Tenant.Id
    Write-Verbose "Connected to tenant: $tenantId"
    #endregion

    #region Get Required Permissions
    Write-Verbose "Getting required permissions from CIEM checks..."
    $permissions = Get-CIEMRequiredPermission
    Write-Verbose "Found $($permissions.CheckCount) checks requiring permissions"
    Write-Verbose "Graph permissions: $($permissions.Graph.Count)"
    Write-Verbose "ARM permissions: $($permissions.ARM.Count)"
    Write-Verbose "Key Vault data plane permissions: $($permissions.KeyVaultDataPlane.Count)"
    #endregion

    #region Get Web App and Managed Identity
    Write-Verbose "Getting web app: $WebAppName in resource group: $ResourceGroupName"
    $webApp = Get-AzWebApp -Name $WebAppName -ResourceGroupName $ResourceGroupName -ErrorAction Stop

    if (-not $webApp) {
        throw "Web app '$WebAppName' not found in resource group '$ResourceGroupName'."
    }

    # Check if system-assigned managed identity is enabled
    $principalId = $null
    if ($webApp.Identity) {
        $principalId = $webApp.Identity.PrincipalId
    }

    if (-not $principalId) {
        if ($EnableSystemAssignedIdentity) {
            if ($PSCmdlet.ShouldProcess($WebAppName, "Enable system-assigned managed identity")) {
                Write-Verbose "Enabling system-assigned managed identity on web app..."
                $webApp = Set-AzWebApp -Name $WebAppName -ResourceGroupName $ResourceGroupName -AssignIdentity $true
                $principalId = $webApp.Identity.PrincipalId

                if (-not $principalId) {
                    throw "Failed to enable system-assigned managed identity on web app '$WebAppName'."
                }

                Write-Verbose "System-assigned managed identity enabled. Principal ID: $principalId"

                # Wait for replication
                Write-Verbose "Waiting for Azure AD replication..."
                Start-Sleep -Seconds 15
            }
        }
        else {
            throw "Web app '$WebAppName' does not have a system-assigned managed identity enabled. Use -EnableSystemAssignedIdentity or enable it manually."
        }
    }
    else {
        Write-Verbose "Web app has system-assigned managed identity. Principal ID: $principalId"
    }
    #endregion

    #region Grant Graph API Permissions (Admin Consent)
    if ($permissions.Graph.Count -gt 0 -and -not $SkipAdminConsent) {
        if ($PSCmdlet.ShouldProcess($WebAppName, "Grant admin consent for Microsoft Graph API permissions")) {
            Write-Verbose "Granting admin consent for Microsoft Graph API permissions..."
            Write-Verbose "Getting access token from current Az context..."

            try {
                # Get Graph token from current Az context (admin user or SP with admin permissions)
                $graphToken = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -ErrorAction Stop

                # Handle both string and SecureString token formats (Az.Accounts version differences)
                if ($graphToken.Token -is [System.Security.SecureString]) {
                    $secureToken = $graphToken.Token
                } else {
                    $secureToken = ConvertTo-SecureString $graphToken.Token -AsPlainText -Force
                }

                Connect-MgGraph -AccessToken $secureToken -NoWelcome -ErrorAction Stop

                # Microsoft Graph service principal (well-known app ID)
                $graphAppId = "00000003-0000-0000-c000-000000000000"
                $graphSp = Get-MgServicePrincipal -Filter "appId eq '$graphAppId'"

                # Get the managed identity's service principal
                $miSp = Get-MgServicePrincipal -Filter "id eq '$principalId'"
                if (-not $miSp) {
                    Write-Warning "Could not find service principal for managed identity. Waiting and retrying..."
                    Start-Sleep -Seconds 10
                    $miSp = Get-MgServicePrincipal -Filter "id eq '$principalId'"
                }

                if (-not $miSp) {
                    throw "Could not find service principal for managed identity with ID '$principalId'."
                }

                $grantedCount = 0
                foreach ($permissionName in $permissions.Graph) {
                    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq $permissionName }
                    if (-not $appRole) {
                        Write-Warning "Could not find Graph permission: $permissionName"
                        continue
                    }

                    Write-Verbose "  Granting consent for: $permissionName"
                    try {
                        New-MgServicePrincipalAppRoleAssignment `
                            -ServicePrincipalId $miSp.Id `
                            -PrincipalId $miSp.Id `
                            -ResourceId $graphSp.Id `
                            -AppRoleId $appRole.Id `
                            -ErrorAction Stop | Out-Null
                        $grantedCount++
                    }
                    catch {
                        if ($_.Exception.Message -like "*already exists*") {
                            Write-Verbose "  Permission $permissionName already granted"
                            $grantedCount++
                        }
                        else {
                            Write-Warning "Failed to grant consent for $permissionName : $_"
                        }
                    }
                }

                Write-Verbose "Admin consent granted for $grantedCount Graph API permissions"

                Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            }
            catch {
                Write-Warning "Failed to grant admin consent: $_"
                Write-Warning "Ensure you are logged in as an admin user (Connect-AzAccount) with permission to grant consent."
                Write-Warning @"
To grant permissions manually via Azure Portal:
1. Go to Azure Portal > Enterprise applications
2. Search for the managed identity by its Principal ID: $principalId
3. Go to Permissions > Grant admin consent
Or use PowerShell with Microsoft.Graph module directly.
"@
            }
        }
    }
    elseif ($permissions.Graph.Count -gt 0) {
        Write-Warning @"
Admin consent was skipped. You must grant admin consent manually:
1. Go to Azure Portal > Enterprise applications
2. Search for the managed identity by its Principal ID: $principalId
3. Go to Permissions > Add a permission > Microsoft Graph > Application permissions
4. Add these permissions:
$($permissions.Graph | ForEach-Object { "   - $_" } | Out-String)
5. Grant admin consent

Or use PowerShell:
  Connect-MgGraph -Scopes 'AppRoleAssignment.ReadWrite.All'
  # Then grant app role assignments to the managed identity
"@
    }
    #endregion

    #region Assign Azure RBAC Roles
    if (-not $SkipRoleAssignment -and $permissions.AzureRoles.Count -gt 0) {
        foreach ($roleName in $permissions.AzureRoles) {
            if ($PSCmdlet.ShouldProcess($Scope, "Assign $roleName role to managed identity")) {
                Write-Verbose "Assigning $roleName role at scope: $Scope"

                $existingAssignment = Get-AzRoleAssignment `
                    -ObjectId $principalId `
                    -Scope $Scope `
                    -RoleDefinitionName $roleName `
                    -ErrorAction SilentlyContinue

                if ($existingAssignment) {
                    Write-Verbose "$roleName role already assigned at this scope"
                }
                else {
                    New-AzRoleAssignment `
                        -ObjectId $principalId `
                        -Scope $Scope `
                        -RoleDefinitionName $roleName | Out-Null
                    Write-Verbose "$roleName role assigned successfully"
                }
            }
        }

        # Note about Key Vault RBAC mode
        $kvRoles = $permissions.AzureRoles | Where-Object { $_ -like 'Key Vault*' }
        if ($kvRoles.Count -gt 0) {
            Write-Verbose "Key Vault RBAC roles assigned. Note: This only works for vaults using Azure RBAC authorization mode."
        }
    }
    elseif ($SkipRoleAssignment -and $permissions.AzureRoles.Count -gt 0) {
        Write-Warning @"
Role assignment was skipped. You must assign these roles manually:
$($permissions.AzureRoles | ForEach-Object { "  New-AzRoleAssignment -ObjectId '$principalId' -Scope '<scope>' -RoleDefinitionName '$_'" } | Out-String)
"@
    }
    #endregion

    #region Build Output
    $output = [PSCustomObject]@{
        WebAppName        = $WebAppName
        ResourceGroupName = $ResourceGroupName
        PrincipalId       = $principalId
        TenantId          = $tenantId
        Scope             = $Scope
        Permissions       = [PSCustomObject]@{
            Graph             = $permissions.Graph
            ARM               = $permissions.ARM
            KeyVaultDataPlane = $permissions.KeyVaultDataPlane
            AzureRoles        = $permissions.AzureRoles
            CheckCount        = $permissions.CheckCount
        }
        NextSteps         = @"
The managed identity for '$WebAppName' has been configured with CIEM permissions.

To use this managed identity in CIEM:
1. In your PSU instance, go to Configuration page
2. Select 'Managed Identity' as the authentication method
3. Save the configuration

The managed identity will automatically authenticate when running within Azure App Service.
No client secrets or certificates are needed.
"@
    }

    Write-Host "`nManaged identity configured successfully!" -ForegroundColor Green
    Write-Host "Web App: $WebAppName"
    Write-Host "Principal ID: $principalId"
    Write-Host "Tenant ID: $tenantId"
    Write-Host "Scope: $Scope"

    Write-Host "`nPermissions assigned:" -ForegroundColor Cyan
    Write-Host "  Graph API permissions: $($permissions.Graph.Count)"
    if ($permissions.AzureRoles.Count -gt 0) {
        Write-Host "  Azure RBAC roles: $(if (-not $SkipRoleAssignment) { $permissions.AzureRoles -join ', ' } else { 'Skipped' })"
    }

    Write-Host "`nTo use managed identity authentication in CIEM:" -ForegroundColor Yellow
    Write-Host "  1. Navigate to the PSU CIEM app Configuration page"
    Write-Host "  2. Select 'Managed Identity' as the authentication method"
    Write-Host "  3. Save the configuration"

    $output
    #endregion
}
