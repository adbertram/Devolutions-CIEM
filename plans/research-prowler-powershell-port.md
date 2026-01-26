# Technical Research: Prowler PowerShell Port

## Azure Identity Checks (46 total)

### Entra ID Checks (15)

| Check ID | Check Title | Severity | Graph API Endpoint | Permissions |
|----------|-------------|----------|-------------------|-------------|
| entra_conditional_access_policy_require_mfa_for_management_api | Ensure Multifactor Authentication is Required for Windows Azure Service Management API | medium | `/identity/conditionalAccess/policies` | Policy.Read.All |
| entra_global_admin_in_less_than_five_users | Ensure fewer than 5 users have global administrator assignment | high | `/directoryRoles` and `/users` with `memberOf` | RoleManagement.Read.Directory, User.Read.All |
| entra_non_privileged_user_has_mfa | Ensure that 'Multi-Factor Auth Status' is 'Enabled' for all Non-Privileged Users | high | `/users`, `/reports/authenticationMethods/userRegistrationDetails` | UserAuthenticationMethod.Read.All, User.Read.All, RoleManagement.Read.Directory |
| entra_policy_default_users_cannot_create_security_groups | Ensure that 'Users can create security groups in Azure portals, API or PowerShell' is set to 'No' | high | `/policies/authorizationPolicy` | Policy.Read.All |
| entra_policy_ensure_default_user_cannot_create_apps | Ensure That 'Users Can Register Applications' Is Set to 'No' | high | `/policies/authorizationPolicy` | Policy.Read.All |
| entra_policy_ensure_default_user_cannot_create_tenants | Ensure that 'Restrict non-admin users from creating tenants' is set to 'Yes' | high | `/policies/authorizationPolicy` | Policy.Read.All |
| entra_policy_guest_invite_only_for_admin_roles | Ensure that 'Guest invite restrictions' is set to 'Only users assigned to specific admin roles can invite guest users' | medium | `/policies/authorizationPolicy` | Policy.Read.All |
| entra_policy_guest_users_access_restrictions | Ensure That 'Guest users access restrictions' is set to 'Guest user access is restricted to properties and memberships of their own directory objects' | medium | `/policies/authorizationPolicy` | Policy.Read.All |
| entra_policy_restricts_user_consent_for_apps | Ensure 'User consent for applications' is set to 'Do not allow user consent' | high | `/policies/authorizationPolicy` | Policy.Read.All |
| entra_policy_user_consent_for_verified_apps | Ensure 'User consent for applications' Is Set To 'Allow for Verified Publishers' | high | `/policies/authorizationPolicy` | Policy.Read.All |
| entra_privileged_user_has_mfa | Ensure that 'Multi-Factor Auth Status' is 'Enabled' for all Privileged Users | high | `/users`, `/reports/authenticationMethods/userRegistrationDetails`, `/directoryRoles` with `members` | UserAuthenticationMethod.Read.All, User.Read.All, RoleManagement.Read.Directory |
| entra_security_defaults_enabled | Ensure Security Defaults is enabled on Microsoft Entra ID | high | `/policies/identitySecurityDefaultsEnforcementPolicy` | Policy.Read.All |
| entra_trusted_named_locations_exists | Ensure Trusted Locations Are Defined | medium | `/identity/conditionalAccess/namedLocations` | Policy.Read.All |
| entra_user_with_vm_access_has_mfa | Ensure only MFA enabled identities can access privileged Virtual Machine | medium | `/users`, `/reports/authenticationMethods/userRegistrationDetails` (needs integration with Azure RBAC) | UserAuthenticationMethod.Read.All, User.Read.All |
| entra_users_cannot_create_microsoft_365_groups | Ensure that 'Users can create Microsoft 365 groups in Azure portals, API or PowerShell' is set to 'No' | high | `/groupSettings` | Directory.Read.All |

### IAM/RBAC Checks (3)

| Check ID | Check Title | Severity | ARM Endpoint | Permissions |
|----------|-------------|----------|--------------|-------------|
| iam_custom_role_has_permissions_to_administer_resource_locks | Ensure an IAM custom role has permissions to administer resource locks | high | `/subscriptions/{subscriptionId}/providers/Microsoft.Authorization/roleDefinitions` | Microsoft.Authorization/roleDefinitions/read |
| iam_role_user_access_admin_restricted | Ensure 'User Access Administrator' role is restricted | high | `/subscriptions/{subscriptionId}/providers/Microsoft.Authorization/roleAssignments` | Microsoft.Authorization/roleAssignments/read |
| iam_subscription_roles_owner_custom_not_created | Ensure that no custom subscription owner roles are created | high | `/subscriptions/{subscriptionId}/providers/Microsoft.Authorization/roleDefinitions` | Microsoft.Authorization/roleDefinitions/read |

### KeyVault Checks (10)

| Check ID | Check Title | Severity | ARM Endpoint | Permissions |
|----------|-------------|----------|--------------|-------------|
| keyvault_access_only_through_private_endpoints | Ensure that public network access when using private endpoint is disabled | high | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{name}` | Microsoft.KeyVault/vaults/read |
| keyvault_key_expiration_set_in_non_rbac | Ensure that the Expiration Date is set for all Keys in Non-RBAC Key Vaults | high | KeyVault REST API: `/keys` on vault URI | keys/get, keys/list |
| keyvault_key_rotation_enabled | Ensure Automatic Key Rotation is Enabled Within Azure Key Vault for the Supported Services | high | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{name}` | Microsoft.KeyVault/vaults/read |
| keyvault_logging_enabled | Ensure that logging for Azure Key Vault is 'Enabled' | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Insights/diagnosticSettings` | Microsoft.Insights/diagnosticSettings/read |
| keyvault_non_rbac_secret_expiration_set | Ensure that the Expiration Date is set for all Secrets in Non-RBAC Key Vaults | high | KeyVault REST API: `/secrets` on vault URI | secrets/get, secrets/list |
| keyvault_private_endpoints | Ensure that Private Endpoints are Used for Azure Key Vault | high | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{name}/privateEndpointConnections` | Microsoft.KeyVault/vaults/read |
| keyvault_rbac_enabled | Enable Role Based Access Control for Azure Key Vault | high | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{name}` | Microsoft.KeyVault/vaults/read |
| keyvault_rbac_key_expiration_set | Ensure that the Expiration Date is set for all Keys in RBAC Key Vaults | high | KeyVault REST API: `/keys` on vault URI | keys/get, keys/list |
| keyvault_rbac_secret_expiration_set | Ensure that the Expiration Date is set for all Secrets in RBAC Key Vaults | high | KeyVault REST API: `/secrets` on vault URI | secrets/get, secrets/list |
| keyvault_recoverable | Ensure the Key Vault is Recoverable | high | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{name}` | Microsoft.KeyVault/vaults/read |

### Storage Checks (18)

| Check ID | Check Title | Severity | ARM Endpoint | Permissions |
|----------|-------------|----------|--------------|-------------|
| storage_account_key_access_disabled | Ensure allow storage account key access is disabled | high | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_blob_public_access_level_is_disabled | Ensure that the 'Public access level' is set to 'Private (no anonymous access)' for all blob containers | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}/blobServices/default/containers` | Microsoft.Storage/storageAccounts/blobServices/containers/read |
| storage_blob_versioning_is_enabled | Ensure Blob Versioning is Enabled on Azure Blob Storage Accounts | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}/blobServices/default` | Microsoft.Storage/storageAccounts/blobServices/read |
| storage_cross_tenant_replication_disabled | Ensure cross-tenant replication is disabled | high | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_default_network_access_rule_is_denied | Ensure Default Network Access Rule for Storage Accounts is Set to Deny | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_default_to_entra_authorization_enabled | Ensure Microsoft Entra authorization is enabled by default for Azure Storage Accounts | high | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_ensure_azure_services_are_trusted_to_access_is_enabled | Ensure that 'Allow trusted Microsoft services to access this storage account' is enabled | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_ensure_encryption_with_customer_managed_keys | Ensure that your Azure Storage accounts are using Customer Managed Keys (CMKs) | high | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_ensure_file_shares_soft_delete_is_enabled | Ensure soft delete for Azure File Shares is enabled | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}/fileServices/default` | Microsoft.Storage/storageAccounts/fileServices/read |
| storage_ensure_minimum_tls_version_12 | Ensure the 'Minimum TLS version' for storage accounts is set to 'Version 1.2' | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_ensure_private_endpoints_in_storage_accounts | Ensure Private Endpoints are used to access Storage Accounts | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}/privateEndpointConnections` | Microsoft.Storage/storageAccounts/read |
| storage_ensure_soft_delete_is_enabled | Ensure Soft Delete is Enabled for Azure Containers and Blob Storage | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}/blobServices/default` | Microsoft.Storage/storageAccounts/blobServices/read |
| storage_geo_redundant_enabled | Ensure geo-redundant storage (GRS) is enabled on critical Azure Storage Accounts | high | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_infrastructure_encryption_is_enabled | Ensure that 'Enable Infrastructure Encryption' for Each Storage Account is Set to 'enabled' | low | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_key_rotation_90_days | Ensure that Storage Account Access Keys are Periodically Regenerated | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_secure_transfer_required_is_enabled | Ensure that all data transferred between clients and your Azure Storage account is encrypted using HTTPS | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}` | Microsoft.Storage/storageAccounts/read |
| storage_smb_channel_encryption_with_secure_algorithm | Ensure SMB channel encryption uses a secure algorithm for SMB file shares | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}/fileServices/default` | Microsoft.Storage/storageAccounts/fileServices/read |
| storage_smb_protocol_version_is_latest | Ensure SMB protocol version for file shares is set to the latest version | medium | `/subscriptions/{subscriptionId}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}/fileServices/default` | Microsoft.Storage/storageAccounts/fileServices/read |

---

## Service Layer Analysis

### Prowler Service Pattern

Prowler uses a centralized service pattern where each Azure service has:

1. **Service Class** (e.g., `Entra`, `IAM`, `KeyVault`, `Storage`):
   - Inherits from `AzureService` base class
   - Initializes with provider credentials
   - Loads and caches all resources upfront in `__init__`
   - Exposes resources as class attributes (e.g., `self.users`, `self.roles`, `self.key_vaults`)

2. **Client Management**:
   - **Entra**: Uses `GraphServiceClient` (async/await pattern for Microsoft Graph)
   - **IAM/RBAC**: Uses `AuthorizationManagementClient` (Azure SDK)
   - **KeyVault**: Uses `KeyVaultManagementClient` (Azure SDK) + `KeyClient` for key/secret operations
   - **Storage**: Uses `StorageManagementClient` (Azure SDK)

3. **Resource Loading**:
   - Pre-loads all required resources in constructor
   - Caches in dictionaries keyed by subscription/tenant
   - Handles pagination for large result sets
   - Catches and logs errors but continues processing

4. **Authentication**:
   - Auto-detects: DefaultAzureCredential → tries Managed Identity → Env vars → CLI context → Interactive
   - Each service client receives the credential object
   - Per-subscription clients created for multi-subscription support

### PowerShell Translation

The PowerShell implementation should follow a singleton service pattern:

**Service Loading Model:**
```powershell
# In module initialization (Devolutions.CIEM.psm1)
$script:EntraService = @{
    Users = $null
    DirectoryRoles = $null
    SecurityDefaults = $null
    AuthorizationPolicy = $null
    ConditionalAccessPolicies = $null
    NamedLocations = $null
    GroupSettings = $null
    UserMFAStatus = $null
}

$script:IAMService = @{
    RoleDefinitions = $null
    CustomRoles = $null
    RoleAssignments = $null
}

$script:KeyVaultService = @{
    KeyVaults = $null
    DiagnosticSettings = $null
}

$script:StorageService = @{
    StorageAccounts = $null
    BlobServices = $null
    FileServices = $null
    BlobContainers = $null
}
```

**Resource Pre-Loading:**
- Call `Invoke-AzRestMethod` once per resource type at scan start
- Parse JSON responses into PowerShell objects
- Cache in script-scoped variables
- All checks reference cached data, not live API calls

**Authentication Pattern:**
```powershell
function Get-AzureAuthContext {
    # 1. Test managed identity: Invoke-AzRestMethod test call
    # 2. If fails, test Azure CLI context: Get-AzContext
    # 3. If fails, prompt for Connect-AzAccount
    # 4. Get subscriptions from authenticated context
}
```

**Invoke-AzRestMethod Usage:**
- All Azure REST calls use `Invoke-AzRestMethod` from Az.Accounts
- Avoids dependencies on specific modules (Az.Storage, Az.KeyVault, etc.)
- Supports both ARM and Graph API endpoints
- Handles pagination for large result sets

---

## Check Dependencies

**Result**: No checks have DependsOn relationships. All 46 checks are independent and can run in any order.

---

## API Permissions Required

### Microsoft Graph API (Entra ID Checks)

| Permission | Checks | Type |
|-----------|--------|------|
| `Policy.Read.All` | All authorization/conditional access/security defaults checks (11) | Application |
| `User.Read.All` | MFA-related checks (3) | Application |
| `RoleManagement.Read.Directory` | Global admin, privileged user checks (2) | Application |
| `UserAuthenticationMethod.Read.All` | MFA status checks (3) | Application (SP only) |
| `Directory.Read.All` | Group settings checks (1) | Application |

**Scopes for Invoke-AzRestMethod:**
- `https://graph.microsoft.com/.default`

### Azure Resource Manager API (IAM/KeyVault/Storage Checks)

| Permission | Checks | Resource |
|-----------|--------|----------|
| `Microsoft.Authorization/roleDefinitions/read` | IAM role checks (3) | Role Definitions |
| `Microsoft.Authorization/roleAssignments/read` | IAM role assignment checks (1) | Role Assignments |
| `Microsoft.KeyVault/vaults/read` | KeyVault checks (10) | Key Vault |
| `Microsoft.Storage/storageAccounts/read` | Storage checks (18) | Storage Account |
| `Microsoft.Insights/diagnosticSettings/read` | KeyVault logging check (1) | Diagnostic Settings |

**Scopes for Invoke-AzRestMethod:**
- `https://management.azure.com/.default`

**Tenant Information:**
- For Graph API: Requires tenant ID from Azure context
- For ARM API: Requires subscription IDs from authenticated context

---

## Architecture Doc Alignment

### Alignment with `docs/architecture-planning.md`

| Aspect | Architecture Doc | Discovery/Research | Status |
|--------|------------------|-------------------|--------|
| **Provider Scope** | Azure + AWS | Azure only for V1 | ✓ ALIGNED |
| **Check Approach** | Native PowerShell, no Python | Confirmed - Prowler uses Python SDK only for API access | ✓ ALIGNED |
| **V1 Service Count** | Unspecified | 46 identity-focused checks identified | ✓ COMPLETE |
| **API Strategy** | "As much as possible use Invoke-AzRestMethod" | Confirmed - Use Graph API + ARM REST APIs directly | ✓ ALIGNED |
| **Service Layer** | "Singleton services with pre-loaded resources" | Prowler loads all at init time in service classes | ✓ ALIGNED |
| **Check Definition** | "JSON file defines checks, single Invoke-CIEMScan executes them" | Metadata in .metadata.json per check | ✓ ALIGNED |
| **Check Files** | "One .ps1 file per check" | Prowler has one directory per check | ✓ ALIGNED |
| **Execution** | "ForEach-Object -Parallel" | Prowler uses threading; PS7+ supports -Parallel | ✓ ALIGNED |
| **Dependencies** | "Support DependsOn between checks" | No checks have DependsOn; still support if needed | ✓ ALIGNED |
| **Remediation** | "Link to Devolutions PAM only" | Full remediation metadata in Prowler; simplify to link | ⚠ PARTIAL |
| **Multi-Tenancy** | "-TenantId parameter, default to current" | Prowler iterates tenants automatically | ✓ ALIGNED |
| **Testing** | "Real environment integration tests only" | No mock fixtures; test against live | ✓ ALIGNED |
| **Module Dependencies** | Specific Az.* versions listed | Use only Az.Accounts (Invoke-AzRestMethod) | ✓ ALIGNED but REDUCED |

### Gaps and Conflicts

1. **Module Dependencies Reduction** (NOT A CONFLICT)
   - Architecture doc lists: Az.Accounts, Az.Resources, Az.KeyVault, Az.Storage
   - Research shows: Only Az.Accounts needed (contains Invoke-AzRestMethod)
   - **Action**: Update manifest to require only Az.Accounts v4.0.0+

2. **Remediation Metadata** (DESIGN DECISION)
   - Prowler metadata includes: CLI, Terraform, NativeIaC remediation code
   - Architecture doc specifies: "Link to Devolutions PAM only"
   - **Decision made**: Store full Prowler metadata in JSON for future use; surface as "See Devolutions PAM" in Finding object

3. **Check Metadata Storage** (ALIGNMENT CONFIRMED)
   - Prowler: One .metadata.json per check directory
   - Architecture: "Centralize checks and metadata as much as possible - prefer single consolidated file"
   - **Recommendation**: Create `Data/AzureChecks.json` with all 46 checks

4. **Parallel Execution** (IMPLEMENTATION NOTE)
   - Prowler uses `concurrent.futures.ThreadPoolExecutor`
   - PowerShell: Use `ForEach-Object -Parallel` (PS7+)
   - **Note**: Singleton services must be thread-safe; cache read-only after initialization

---

## Key Findings Summary

1. **46 identity-focused checks confirmed** across 4 services (Entra, IAM, KeyVault, Storage)
2. **No check dependencies** - all can run independently in any order
3. **API endpoints identified** - Graph API for Entra, ARM REST API for IAM/KeyVault/Storage
4. **Service layer pattern clear** - Pre-load all resources, checks reference cached data
5. **Prowler SDK pattern** - Uses Python SDKs (azure-*, msgraph), not REST APIs directly; PowerShell port must use REST
6. **Authentication auto-detection** confirmed - Managed Identity → Env Vars → CLI → Interactive
7. **Multi-subscription support** needed - Services iterate subscriptions per tenant
8. **Module dependencies** - Only Az.Accounts required (contains Invoke-AzRestMethod)
9. **PowerShell 7+ required** - ForEach-Object -Parallel syntax
10. **No conflicts** with architecture doc - full alignment on approach and scope
