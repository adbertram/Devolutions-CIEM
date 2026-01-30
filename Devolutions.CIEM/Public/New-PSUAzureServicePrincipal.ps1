function New-PSUAzureServicePrincipal {
    <#
    .SYNOPSIS
        Creates an Azure service principal with all permissions required for CIEM security checks.

    .DESCRIPTION
        Creates an Azure AD app registration and service principal configured with all permissions
        required to run Devolutions CIEM security checks. This includes:
        - Microsoft Graph API application permissions
        - Azure Resource Manager RBAC role assignment (Reader)
        - Key Vault data plane permissions (documented for manual configuration)

        The function uses Get-CIEMRequiredPermission to determine the exact permissions needed.

    .PARAMETER DisplayName
        The display name for the app registration and service principal.
        Default: "Devolutions-CIEM-Scanner"

    .PARAMETER Scope
        The scope for the ARM RBAC role assignment. Can be a subscription or management group.
        Examples:
        - "/subscriptions/<subscription-id>"
        - "/providers/Microsoft.Management/managementGroups/<mg-name>"

    .PARAMETER CredentialType
        The type of credential to create for authentication.
        - ClientSecret: Creates a client secret (default)
        - Certificate: Creates a self-signed certificate

    .PARAMETER CertificateValidityYears
        Number of years the certificate is valid. Only used when CredentialType is Certificate.
        Default: 1

    .PARAMETER SkipRoleAssignment
        Skip the ARM RBAC role assignment. Useful if you want to assign at a different scope later.

    .PARAMETER SkipAdminConsent
        Skip granting admin consent for Graph API permissions. You will need to grant consent manually
        in the Azure Portal.

    .OUTPUTS
        [PSCustomObject] Object containing:
        - ApplicationId: The app registration client ID
        - ObjectId: The app registration object ID
        - ServicePrincipalId: The service principal object ID
        - TenantId: The Azure AD tenant ID
        - ClientSecret: The client secret (if CredentialType is ClientSecret)
        - CertificateThumbprint: The certificate thumbprint (if CredentialType is Certificate)
        - Permissions: The permissions configured

    .EXAMPLE
        New-PSUAzureServicePrincipal -Scope "/subscriptions/12345678-1234-1234-1234-123456789012"
        # Creates a service principal with client secret for the specified subscription

    .EXAMPLE
        New-PSUAzureServicePrincipal -DisplayName "CIEM-Prod" -CredentialType Certificate -Scope "/subscriptions/12345678-1234-1234-1234-123456789012"
        # Creates a service principal with certificate authentication

    .EXAMPLE
        New-PSUAzureServicePrincipal -Scope "/providers/Microsoft.Management/managementGroups/my-mg" -SkipAdminConsent
        # Creates a service principal at management group scope, skipping admin consent

    .NOTES
        Required modules (auto-installed if not present):
        - Az.Accounts (for Connect-AzAccount)
        - Az.Resources (for app/SP/role cmdlets)
        - Microsoft.Graph.Applications (for Graph API permission grants, unless -SkipAdminConsent)

        Required Azure permissions:
        - Global Administrator or Privileged Role Administrator role (for admin consent)
        - Owner or User Access Administrator role on the target scope (for role assignment)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$DisplayName = "Devolutions-CIEM-Scanner",

        [Parameter(Mandatory)]
        [ValidatePattern('^/(subscriptions/[a-f0-9-]+|providers/Microsoft\.Management/managementGroups/.+)$')]
        [string]$Scope,

        [Parameter()]
        [ValidateSet('ClientSecret', 'Certificate')]
        [string]$CredentialType = 'ClientSecret',

        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$CertificateValidityYears = 1,

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

    #region Create App Registration
    if ($PSCmdlet.ShouldProcess($DisplayName, "Create Azure AD app registration")) {
        Write-Verbose "Creating app registration: $DisplayName"

        # Check if app already exists
        $existingApp = Get-AzADApplication -DisplayName $DisplayName -ErrorAction SilentlyContinue
        if ($existingApp) {
            throw "An app registration with name '$DisplayName' already exists (AppId: $($existingApp.AppId)). Choose a different name or remove the existing app."
        }

        # Create the app registration
        $appParams = @{
            DisplayName    = $DisplayName
            SignInAudience = 'AzureADMyOrg'
        }
        $app = New-AzADApplication @appParams
        Write-Verbose "Created app registration: $($app.AppId)"
    }
    #endregion

    #region Create Service Principal
    if ($PSCmdlet.ShouldProcess($DisplayName, "Create service principal")) {
        Write-Verbose "Creating service principal..."
        $sp = New-AzADServicePrincipal -ApplicationId $app.AppId
        Write-Verbose "Created service principal: $($sp.Id)"

        # Wait for replication
        Write-Verbose "Waiting for Azure AD replication..."
        Start-Sleep -Seconds 10
    }
    #endregion

    #region Create Credential
    $credential = $null
    $certificateThumbprint = $null

    if ($CredentialType -eq 'ClientSecret') {
        if ($PSCmdlet.ShouldProcess($DisplayName, "Create client secret")) {
            Write-Verbose "Creating client secret..."
            $endDate = (Get-Date).AddYears(1)
            $secretCredential = New-AzADAppCredential -ApplicationId $app.AppId -EndDate $endDate
            $credential = $secretCredential.SecretText
            Write-Verbose "Created client secret (expires: $endDate)"
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess($DisplayName, "Create self-signed certificate")) {
            Write-Verbose "Creating self-signed certificate..."
            $certName = "CN=$DisplayName"
            $endDate = (Get-Date).AddYears($CertificateValidityYears)

            # Create self-signed certificate
            $cert = New-SelfSignedCertificate `
                -Subject $certName `
                -CertStoreLocation "Cert:\CurrentUser\My" `
                -KeyExportPolicy Exportable `
                -KeySpec Signature `
                -KeyLength 2048 `
                -KeyAlgorithm RSA `
                -HashAlgorithm SHA256 `
                -NotAfter $endDate

            $certificateThumbprint = $cert.Thumbprint
            Write-Verbose "Created certificate with thumbprint: $certificateThumbprint"

            # Upload certificate to app registration
            $certBase64 = [System.Convert]::ToBase64String($cert.GetRawCertData())
            New-AzADAppCredential -ApplicationId $app.AppId -CertValue $certBase64 -EndDate $endDate
            Write-Verbose "Uploaded certificate to app registration"
        }
    }
    #endregion

    #region Add Graph API Permissions
    if ($permissions.Graph.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess($DisplayName, "Add Microsoft Graph API permissions")) {
            Write-Verbose "Adding Microsoft Graph API permissions..."

            # Microsoft Graph app ID (well-known)
            $graphAppId = "00000003-0000-0000-c000-000000000000"

            # Get Microsoft Graph service principal to look up permission IDs
            $graphSp = Get-AzADServicePrincipal -ApplicationId $graphAppId

            foreach ($permissionName in $permissions.Graph) {
                Write-Verbose "  Adding permission: $permissionName"

                # Find the permission ID from the Graph service principal's app roles
                $appRole = $graphSp.AppRole | Where-Object { $_.Value -eq $permissionName }
                if (-not $appRole) {
                    Write-Warning "Could not find Graph permission: $permissionName"
                    continue
                }

                # Add the permission to the app registration
                Add-AzADAppPermission `
                    -ApplicationId $app.AppId `
                    -ApiId $graphAppId `
                    -PermissionId $appRole.Id `
                    -Type Role
            }
            Write-Verbose "Added $($permissions.Graph.Count) Graph API permissions"
        }
    }
    #endregion

    #region Grant Admin Consent
    if (-not $SkipAdminConsent -and $permissions.Graph.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess($DisplayName, "Grant admin consent for Graph API permissions")) {
            Write-Verbose "Granting admin consent for Graph API permissions..."
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

                # Microsoft Graph service principal
                $graphAppId = "00000003-0000-0000-c000-000000000000"
                $graphSp = Get-MgServicePrincipal -Filter "appId eq '$graphAppId'"

                # Get our service principal
                $ourSp = Get-MgServicePrincipal -Filter "appId eq '$($app.AppId)'"

                foreach ($permissionName in $permissions.Graph) {
                    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq $permissionName }
                    if (-not $appRole) {
                        Write-Warning "Could not find Graph permission for consent: $permissionName"
                        continue
                    }

                    Write-Verbose "  Granting consent for: $permissionName"
                    try {
                        New-MgServicePrincipalAppRoleAssignment `
                            -ServicePrincipalId $ourSp.Id `
                            -PrincipalId $ourSp.Id `
                            -ResourceId $graphSp.Id `
                            -AppRoleId $appRole.Id `
                            -ErrorAction Stop | Out-Null
                    }
                    catch {
                        if ($_.Exception.Message -notlike "*already exists*") {
                            Write-Warning "Failed to grant consent for $permissionName : $_"
                        }
                    }
                }
                Write-Verbose "Admin consent granted for Graph API permissions"

                Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
            }
            catch {
                Write-Warning "Failed to grant admin consent: $_"
                Write-Warning "Ensure you are logged in as an admin user (Connect-AzAccount) with permission to grant consent."
                Write-Warning "Or grant admin consent manually: Azure Portal > App registrations > $DisplayName > API permissions > Grant admin consent"
            }
        }
    }
    elseif ($permissions.Graph.Count -gt 0) {
        Write-Warning @"
Admin consent was skipped. You must grant admin consent manually:
1. Go to Azure Portal > App registrations > $DisplayName > API permissions
2. Click 'Grant admin consent for <tenant>'

Or run: Connect-MgGraph -Scopes 'Application.ReadWrite.All' and grant consent programmatically.
"@
    }
    #endregion

    #region Assign Azure RBAC Roles
    if (-not $SkipRoleAssignment -and $permissions.AzureRoles.Count -gt 0) {
        foreach ($roleName in $permissions.AzureRoles) {
            if ($PSCmdlet.ShouldProcess($Scope, "Assign $roleName role to service principal")) {
                Write-Verbose "Assigning $roleName role at scope: $Scope"

                $existingAssignment = Get-AzRoleAssignment `
                    -ObjectId $sp.Id `
                    -Scope $Scope `
                    -RoleDefinitionName $roleName `
                    -ErrorAction SilentlyContinue

                if ($existingAssignment) {
                    Write-Verbose "$roleName role already assigned at this scope"
                }
                else {
                    New-AzRoleAssignment `
                        -ObjectId $sp.Id `
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
$($permissions.AzureRoles | ForEach-Object { "  New-AzRoleAssignment -ObjectId '$($sp.Id)' -Scope '<scope>' -RoleDefinitionName '$_'" } | Out-String)
"@
    }
    #endregion

    #region Store Credentials in PSU Secrets
    $secretsCreated = $false
    $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)

    if ($inPSUContext) {
        if ($PSCmdlet.ShouldProcess("PSU Secrets", "Create CIEM_Azure credentials")) {
            Write-Verbose "PSU context detected, creating secrets..."

            try {
                # Create secrets in Database vault
                New-PSUVariable -Name 'CIEM_Azure_TenantId' -Value $tenantId -Vault 'Database' -ErrorAction Stop
                New-PSUVariable -Name 'CIEM_Azure_ClientId' -Value $app.AppId -Vault 'Database' -ErrorAction Stop

                if ($CredentialType -eq 'ClientSecret') {
                    New-PSUVariable -Name 'CIEM_Azure_ClientSecret' -Value $credential -Vault 'Database' -ErrorAction Stop
                }
                else {
                    New-PSUVariable -Name 'CIEM_Azure_CertThumbprint' -Value $certificateThumbprint -Vault 'Database' -ErrorAction Stop
                }

                $secretsCreated = $true
                Write-Verbose "PSU secrets created successfully"
                Write-Host "`nSecrets stored in PSU Database vault:" -ForegroundColor Green
                Write-Host "  - CIEM_Azure_TenantId"
                Write-Host "  - CIEM_Azure_ClientId"
                if ($CredentialType -eq 'ClientSecret') {
                    Write-Host "  - CIEM_Azure_ClientSecret"
                }
                else {
                    Write-Host "  - CIEM_Azure_CertThumbprint"
                }
            }
            catch {
                Write-Warning "Failed to create PSU secrets: $_"
                Write-Warning "You may need to create secrets manually via PSU Admin UI."
            }
        }
    }
    else {
        # Write to .env file for local development
        $envPath = Join-Path -Path $script:ModuleRoot -ChildPath '.env'

        if ($PSCmdlet.ShouldProcess($envPath, "Update .env file with credentials")) {
            Write-Verbose "Writing credentials to .env file..."

            $envContent = @"
# CIEM Azure Service Principal Credentials
# This file is for local development only - do not commit to source control
# In PSU deployments, use PSU secrets instead (Platform > Variables > Secrets)

CIEM_AZURE_TENANT_ID=$tenantId
CIEM_AZURE_CLIENT_ID=$($app.AppId)
$(if ($CredentialType -eq 'ClientSecret') {
"CIEM_AZURE_CLIENT_SECRET=$credential"
} else {
"# CIEM_AZURE_CLIENT_SECRET=
CIEM_AZURE_CERT_THUMBPRINT=$certificateThumbprint"
})

# AWS credentials (future)
# CIEM_AWS_ACCESS_KEY_ID=
# CIEM_AWS_SECRET_ACCESS_KEY=
# CIEM_AWS_REGION=
"@
            Set-Content -Path $envPath -Value $envContent -Encoding UTF8
            $secretsCreated = $true
            Write-Host "`nCredentials written to .env file: $envPath" -ForegroundColor Green
        }

        Write-Host "`nFor PSU deployment, create these secrets in PSU Admin UI:" -ForegroundColor Yellow
        Write-Host "  Platform > Variables > Create Secret Variable (Database vault)" -ForegroundColor Gray
        Write-Host "  - CIEM_Azure_TenantId = $tenantId"
        Write-Host "  - CIEM_Azure_ClientId = $($app.AppId)"
        if ($CredentialType -eq 'ClientSecret') {
            Write-Host "  - CIEM_Azure_ClientSecret = <see .env file>"
        }
        else {
            Write-Host "  - CIEM_Azure_CertThumbprint = $certificateThumbprint"
        }
    }
    #endregion

    #region Build Output
    $output = [PSCustomObject]@{
        DisplayName           = $DisplayName
        ApplicationId         = $app.AppId
        ObjectId              = $app.Id
        ServicePrincipalId    = $sp.Id
        TenantId              = $tenantId
        ClientSecret          = $credential
        CertificateThumbprint = $certificateThumbprint
        Scope                 = $Scope
        SecretsCreated        = $secretsCreated
        Permissions           = [PSCustomObject]@{
            Graph             = $permissions.Graph
            ARM               = $permissions.ARM
            KeyVaultDataPlane = $permissions.KeyVaultDataPlane
            AzureRoles        = $permissions.AzureRoles
            CheckCount        = $permissions.CheckCount
        }
        PSUSecrets            = @"
# Credentials are stored as PSU secrets (Database vault):
#   - CIEM_Azure_TenantId
#   - CIEM_Azure_ClientId
#   - CIEM_Azure_ClientSecret (or CIEM_Azure_CertThumbprint)
#
# Connect-CIEM will automatically use these secrets when running in PSU.
# For local development, credentials fall back to config.json values.
"@
    }

    Write-Host "`nService principal created successfully!" -ForegroundColor Green
    Write-Host "Application (client) ID: $($app.AppId)"
    Write-Host "Tenant ID: $tenantId"

    if ($secretsCreated) {
        Write-Host "`nCredentials stored in PSU secrets - ready to use with Connect-CIEM" -ForegroundColor Green
    }
    elseif ($credential) {
        Write-Host "`nIMPORTANT: Save the client secret now - it cannot be retrieved later!" -ForegroundColor Yellow
        Write-Host "Client Secret: $credential"
    }

    if ($certificateThumbprint) {
        Write-Host "Certificate Thumbprint: $certificateThumbprint"
        Write-Host "Certificate Location: Cert:\CurrentUser\My\$certificateThumbprint"
    }

    $output
    #endregion
}
