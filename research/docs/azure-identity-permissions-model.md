# Azure Identity and Permissions Model

A comprehensive breakdown of Azure's identity types, permission structures, and access control mechanisms.

---

## Table of Contents

1. [Identity Types (Security Principals)](#1-identity-types-security-principals)
2. [Azure RBAC Model](#2-azure-rbac-model)
3. [Role Definitions](#3-role-definitions)
4. [Scope Hierarchy](#4-scope-hierarchy)
5. [Role Assignments](#5-role-assignments)
6. [Deny Assignments](#6-deny-assignments)
7. [Control Plane vs Data Plane](#7-control-plane-vs-data-plane)
8. [Azure Roles vs Microsoft Entra Roles](#8-azure-roles-vs-microsoft-entra-roles)
9. [Permission Evaluation Flow](#9-permission-evaluation-flow)
10. [CIEM Scanning Implications](#10-ciem-scanning-implications)

---

## 1. Identity Types (Security Principals)

A **security principal** is an object that represents an entity requesting access to Azure resources. Azure RBAC can assign roles to any of these security principals.

### 1.1 Users

Human identities in Microsoft Entra ID (formerly Azure AD).

| Attribute | Description |
|-----------|-------------|
| **ObjectId** | Unique GUID identifier |
| **UserPrincipalName** | Email-like identifier (user@domain.com) |
| **DisplayName** | Human-readable name |
| **AccountEnabled** | Whether the account is active |
| **LastSignInDateTime** | Last authentication timestamp (requires Entra ID P1/P2) |

**Types:**
- **Member users**: Full directory members
- **Guest users**: External identities (B2B collaboration)
- **Synced users**: On-premises AD synchronized via Entra Connect

### 1.1.1 Classic Administrators (Legacy)

Legacy administrator roles that predate Azure RBAC:

| Role | Description | CIEM Impact |
|------|-------------|-------------|
| **Account Administrator** | Billing owner, can create subscriptions | 1 per account |
| **Service Administrator** | Implicit Owner at subscription scope | 1 per subscription |
| **Co-Administrator** | Implicit Owner at subscription scope | Up to 200 per subscription |

**CRITICAL for CIEM**: Classic admins are **NOT** returned by standard `Get-AzRoleAssignment`. You must use:
```powershell
Get-AzRoleAssignment -IncludeClassicAdministrators
```

These represent hidden super-admins that standard RBAC scanning misses.

### 1.2 Groups

Collections of users, service principals, or other groups.

| Group Type | Description |
|------------|-------------|
| **Security groups** | Used for access control |
| **Microsoft 365 groups** | Collaboration groups with shared resources |
| **Dynamic groups** | Membership based on attribute rules |
| **Assigned groups** | Manual membership management |
| **Role-assignable groups** | Can be assigned Entra ID roles (requires P1/P2) |

**RBAC behavior**: Role assignments are **transitive** for groups - if User A is in Group B, and Group B is in Group C which has a role assignment, User A inherits that access.

**Role-Assignable Groups**: Special groups that can be assigned Microsoft Entra roles. These are security-sensitive because adding a user to the group grants them the Entra role.

**CIEM consideration**: Scan group membership of role-assignable groups to find indirect privilege holders.

### 1.3 Service Principals

Application identities for automation, services, and applications.

| Component | Description |
|-----------|-------------|
| **Application Object** | The application definition in the "home" tenant |
| **Service Principal** | An instance of the application in a tenant |
| **AppId (ClientId)** | Application identifier |
| **ObjectId** | Service principal's unique ID in the tenant |

**Authentication methods:**
- Client secret (password) - less secure, discouraged
- Certificate - recommended
- Federated identity credential - passwordless (OIDC-based)

**Types:**
- **Single-tenant**: Only authenticates from home tenant
- **Multi-tenant**: Can authenticate from any Entra tenant

### 1.3.1 Workload Identity Federation

A modern credential-free authentication method using OIDC trust relationships.

| Use Case | OIDC Issuer | Security Boundary |
|----------|-------------|-------------------|
| **GitHub Actions** | `https://token.actions.githubusercontent.com` | Repository, branch, environment |
| **Kubernetes (AKS)** | Cluster OIDC issuer URL | Namespace, service account |
| **Other OIDC providers** | Provider's OIDC endpoint | Subject claim validation |

**CIEM Impact**: No secrets to rotate, but the **subject verification policy** is the security control. Overly permissive trust (e.g., trusting any branch) is a major vulnerability.

```powershell
# List federated credentials for an app
Get-AzADAppFederatedCredential -ApplicationObjectId <objectId>
```

### 1.4 Managed Identities

Azure-managed service principals that eliminate credential management.

#### System-Assigned Managed Identity

| Property | Description |
|----------|-------------|
| **Creation** | Created when enabled on an Azure resource |
| **Lifecycle** | Tied to the Azure resource - deleted when resource is deleted |
| **Sharing** | Cannot be shared - 1:1 with Azure resource |
| **Name** | Same as the Azure resource name |
| **Use Case** | Single-resource workloads |

#### User-Assigned Managed Identity

| Property | Description |
|----------|-------------|
| **Creation** | Created as standalone Azure resource |
| **Lifecycle** | Independent - must be explicitly deleted |
| **Sharing** | Can be assigned to multiple Azure resources |
| **Name** | User-defined |
| **Use Case** | Multi-resource workloads, shared identity scenarios |

**Key benefit**: No credentials to manage - Azure handles rotation automatically.

### 1.5 Azure Lighthouse (External Tenant Access)

Allows identities from external tenants to manage resources via delegated access.

| Component | Description |
|-----------|-------------|
| **Registration Definition** | Defines what external tenant can access |
| **Registration Assignment** | Applies the delegation to a scope |
| **Managing Tenant** | The external tenant providing services |
| **Managed Tenant** | The local tenant being managed |

**CIEM Impact**: Lighthouse principals do NOT exist in the local Entra ID directory - they are projected in. Standard RBAC scans may miss them.

```powershell
# List Lighthouse delegations
Get-AzManagedServicesDefinition
Get-AzManagedServicesAssignment
```

**Risk**: External MSPs/vendors with broad access that isn't visible in standard identity scans.

### 1.6 Identity Comparison Table

| Identity Type | Credential Management | Lifecycle | Multi-Resource | Use Case |
|---------------|----------------------|-----------|----------------|----------|
| User | Manual (password/MFA) | Manual | N/A | Human access |
| Group | N/A | Manual | N/A | Organize users/SPs |
| Service Principal | Manual (secret/cert) | Manual | Yes | Applications, automation |
| System-assigned MI | Automatic | Tied to resource | No | Single Azure resource |
| User-assigned MI | Automatic | Independent | Yes | Multiple Azure resources |

---

## 2. Azure RBAC Model

Azure Role-Based Access Control (RBAC) provides fine-grained access management through three core elements:

```
Role Assignment = Security Principal + Role Definition + Scope
```

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Security Principal** | Who is getting access (user, group, SP, MI) |
| **Role Definition** | What permissions are granted |
| **Scope** | Where the permissions apply |
| **Role Assignment** | The binding of all three elements |

### RBAC Characteristics

- **Additive model**: Effective permissions = sum of all role assignments
- **Inheritance**: Permissions flow down the scope hierarchy
- **Global storage**: RBAC data replicated globally for low-latency access
- **Free**: No additional licensing cost

### RBAC Limits

| Limit | Value |
|-------|-------|
| Role assignments per subscription | 4,000 |
| Role assignments per management group | 500 |
| Custom roles per tenant | 5,000 |
| Role definition description length | 2,048 characters |

---

## 2.1 Privileged Identity Management (PIM)

PIM enables **Just-in-Time (JIT)** privileged access, time-bound assignments, and approval workflows. Requires Entra ID P2 license.

### Assignment Types

| Type | Description | Visibility |
|------|-------------|------------|
| **Active Assignment** | Currently has the role | Visible in `Get-AzRoleAssignment` |
| **Eligible Assignment** | Can activate the role on-demand | NOT visible in standard RBAC queries |

**CRITICAL for CIEM**: A user with only Eligible assignments appears to have no privileged access in standard scans, but can become Owner in minutes.

### Scanning PIM

```powershell
# List eligible role assignments (requires PIM module)
Get-AzRoleEligibilitySchedule -Scope "/subscriptions/{subscriptionId}"

# List active role assignments via PIM
Get-AzRoleAssignmentSchedule -Scope "/subscriptions/{subscriptionId}"
```

### PIM Settings to Audit

| Setting | Risk if Misconfigured |
|---------|----------------------|
| **Max activation duration** | Long durations (8+ hours) reduce JIT benefit |
| **Require approval** | No approval = self-service elevation |
| **Require MFA** | No MFA = weaker authentication for privileged access |
| **Require justification** | No justification = no audit trail |

---

## 3. Role Definitions

A role definition is a collection of permissions.

### 3.1 Role Definition Structure

```json
{
  "Name": "Role Name",
  "Id": "unique-guid",
  "IsCustom": false,
  "Description": "What the role does",
  "Actions": [
    "Microsoft.Compute/virtualMachines/*"
  ],
  "NotActions": [
    "Microsoft.Compute/virtualMachines/delete"
  ],
  "DataActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
  ],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/{subscriptionId}"
  ]
}
```

### 3.2 Permission Properties

| Property | Description |
|----------|-------------|
| **Actions** | Control plane operations allowed |
| **NotActions** | Control plane operations excluded from Actions |
| **DataActions** | Data plane operations allowed |
| **NotDataActions** | Data plane operations excluded from DataActions |
| **AssignableScopes** | Where the role can be assigned |

**Effective permissions calculation:**
```
Effective control plane = Actions - NotActions
Effective data plane = DataActions - NotDataActions
```

### 3.3 Action String Format

```
{Company}.{ProviderName}/{resourceType}/{action}
```

| Action Substring | Description |
|------------------|-------------|
| `*` | Wildcard - all actions |
| `read` | GET operations |
| `write` | PUT/PATCH operations |
| `delete` | DELETE operations |
| `action` | Custom operations (POST) |

**Examples:**
- `*/read` - Read all resource types
- `Microsoft.Compute/*` - All compute operations
- `Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read` - Read blobs

### 3.4 Built-in Roles

Azure has 100+ built-in roles. The five fundamental roles:

| Role | Permissions | Notes |
|------|-------------|-------|
| **Owner** | Full access + assign roles | Highest privilege |
| **Contributor** | Full access, cannot assign roles | Cannot manage RBAC |
| **Reader** | View only | Read-only access |
| **User Access Administrator** | Manage user access, assign roles | RBAC management only |
| **Role Based Access Control Administrator** | Manage role assignments | Can assign Owner role |

### 3.5 Custom Roles

Organizations can create custom roles when built-in roles don't meet needs.

**Limits:**
- 5,000 custom roles per tenant
- AssignableScopes limited to management group, subscription, or resource group

**CIEM detection opportunity**: Custom roles with wildcard (`*`) permissions indicate potential over-privileging.

---

## 4. Scope Hierarchy

Scopes are structured in a parent-child relationship. Permissions inherit downward.

```
Root (/)
└── Tenant Root Management Group
    └── Management Groups (nested up to 6 levels)
        └── Subscription
            └── Resource Group
                └── Resource
```

### 4.1 Scope Levels

| Level | Format | Example |
|-------|--------|---------|
| **Root** | `/` | `/` (built-in roles only) |
| **Tenant Root MG** | `/providers/Microsoft.Management/managementGroups/{tenantId}` | Auto-created, ID = tenant ID |
| **Management Group** | `/providers/Microsoft.Management/managementGroups/{groupId}` | `/providers/Microsoft.Management/managementGroups/contoso` |
| **Subscription** | `/subscriptions/{subscriptionId}` | `/subscriptions/00000000-0000-0000-0000-000000000000` |
| **Resource Group** | `/subscriptions/{subId}/resourceGroups/{rgName}` | `/subscriptions/.../resourceGroups/myRG` |
| **Resource** | `/subscriptions/{subId}/resourceGroups/{rgName}/providers/{provider}/{type}/{name}` | `/subscriptions/.../providers/Microsoft.Storage/storageAccounts/mystorageaccount` |

### 4.1.1 Management Group Limits

| Limit | Value |
|-------|-------|
| Management groups per directory | 10,000 |
| Nesting depth | 6 levels (excluding root and subscription) |
| Direct children per group | No specific limit |
| Subscriptions per management group | No specific limit |

### 4.2 Inheritance Behavior

- Permissions assigned at a parent scope are inherited by all child scopes
- Example: Reader role at subscription → Reader access to all resource groups and resources in that subscription

**CIEM detection opportunity**: High-privilege roles (Owner, Contributor) at broad scopes (subscription, management group) are risky.

---

## 5. Role Assignments

A role assignment attaches a role definition to a security principal at a specific scope.

### 5.1 Role Assignment Properties

| Property | Description |
|----------|-------------|
| **Id** | Unique assignment identifier |
| **PrincipalId** | ObjectId of the security principal |
| **PrincipalType** | User, Group, ServicePrincipal, or Unknown |
| **RoleDefinitionId** | ID of the role being assigned |
| **Scope** | Where the assignment applies |
| **Condition** | Optional ABAC condition |
| **CreatedOn** | When the assignment was created |
| **CreatedBy** | Who created the assignment |

### 5.2 PrincipalType Values

| Value | Meaning |
|-------|---------|
| `User` | Microsoft Entra user |
| `Group` | Microsoft Entra group |
| `ServicePrincipal` | App/Service principal or managed identity |
| `Unknown` | **Orphaned assignment** - principal was deleted |

**CIEM detection opportunity**: `PrincipalType = "Unknown"` indicates orphaned role assignments that should be cleaned up.

### 5.3 Multiple Role Assignments

- RBAC is additive: if a user has Contributor at subscription and Reader at resource group, effective permission at resource group is Contributor (more permissive wins)
- NotActions are NOT deny rules - they subtract from wildcards, not override other assignments

### 5.4 ABAC Conditions (Attribute-Based Access Control)

Azure RBAC supports conditions that constrain role assignments based on attributes.

**Condition format:**
```
@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals 'my-container'
```

**Common condition targets:**
- Resource tags
- Blob container names
- Blob index tags
- Principal attributes

**CIEM Impact**: A scanner might flag a user as "Overprivileged" with full Contributor, but an ABAC condition actually restricts them to specific resources. This can cause **false positives** if conditions aren't evaluated.

```powershell
# Check for role assignments with conditions
Get-AzRoleAssignment | Where-Object { $_.Condition -ne $null }
```

---

## 5.5 Resource-Specific Access (Non-RBAC)

Some Azure resources have their own access control systems outside RBAC.

### Key Vault Access Policies (Legacy)

| Model | How Access is Granted |
|-------|----------------------|
| **RBAC** (recommended) | Standard Azure roles like "Key Vault Secrets User" |
| **Access Policies** (legacy) | Per-vault policy with key/secret/certificate permissions |

**CIEM Impact**: A user might have NO RBAC roles on a Key Vault but have full access via Access Policies.

```powershell
# Check for Key Vault access policies
$vault = Get-AzKeyVault -VaultName "myVault"
$vault.AccessPolicies  # Lists non-RBAC access
```

### Other Resource-Specific Access

| Resource | Access Model |
|----------|--------------|
| **Storage Account** | Shared Access Keys, SAS tokens |
| **Cosmos DB** | Primary/secondary keys, RBAC |
| **Azure SQL** | SQL authentication, Entra auth |
| **AKS** | Kubernetes RBAC (separate from Azure RBAC) |

---

## 6. Deny Assignments

Deny assignments block users from specific actions even if a role assignment grants access.

### 6.1 Deny Assignment Properties

| Property | Description |
|----------|-------------|
| **DenyAssignmentName** | Display name |
| **Permissions** | Actions being denied |
| **Scope** | Where the deny applies |
| **ExcludePrincipals** | Principals exempt from the deny |
| **DoNotApplyToChildScopes** | Whether deny inherits to children |
| **IsSystemProtected** | Whether the deny can be modified |

### 6.2 Deny Assignment Behavior

- Deny takes precedence over allow
- Currently, deny assignments can only be created by Azure (for managed apps, blueprints)
- Users cannot create custom deny assignments directly

**Evaluation order**: Deny assignments → Role assignments

---

## 7. Control Plane vs Data Plane

Azure separates management operations from data operations.

### 7.1 Control Plane (Management Plane)

Operations that manage Azure resources themselves.

| Examples | Description |
|----------|-------------|
| Create storage account | `Microsoft.Storage/storageAccounts/write` |
| Delete VM | `Microsoft.Compute/virtualMachines/delete` |
| List resource groups | `Microsoft.Resources/subscriptions/resourceGroups/read` |

- Specified in `Actions` and `NotActions`
- Handled by Azure Resource Manager

### 7.2 Data Plane

Operations on data within Azure resources.

| Examples | Description |
|----------|-------------|
| Read blob data | `Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read` |
| Send message to queue | `Microsoft.Storage/storageAccounts/queueServices/queues/messages/add/action` |
| Read Key Vault secrets | `Microsoft.KeyVault/vaults/secrets/read` |

- Specified in `DataActions` and `NotDataActions`
- Handled by resource provider or Azure Resource Manager

### 7.3 Separation Example

| Role | Control Plane | Data Plane |
|------|---------------|------------|
| **Owner** | Full (`*`) | None by default |
| **Storage Blob Data Reader** | Limited container read | Full blob read |

**Key insight**: Having Owner role does NOT automatically grant access to data. Data access requires explicit DataActions.

### 7.4 The listKeys Bypass (Control→Data Escalation)

Certain control plane actions grant implicit data plane access by retrieving keys.

| Action | Effect |
|--------|--------|
| `Microsoft.Storage/storageAccounts/listKeys/action` | Retrieve storage account keys → Full data access |
| `Microsoft.DocumentDB/databaseAccounts/listKeys/action` | Retrieve Cosmos DB keys → Full data access |
| `Microsoft.Cache/redis/listKeys/action` | Retrieve Redis keys → Full data access |

**CIEM Impact**: A user with only `listKeys` permission can bypass all RBAC-based data access controls. Treat `listKeys` as equivalent to **Full Data Plane Owner**.

```powershell
# Find roles with listKeys permissions
Get-AzRoleDefinition | Where-Object {
    $_.Actions -like "*listKeys*" -or $_.Actions -like "*listkeys*"
}
```

---

## 7.5 Privilege Escalation Paths

CIEM must detect permissions that enable self-elevation to higher privileges.

### 7.5.1 Direct Escalation Permissions

| Permission | Risk |
|------------|------|
| `Microsoft.Authorization/roleAssignments/write` | Can assign themselves Owner |
| `Microsoft.Authorization/roleDefinitions/write` | Can create custom role with any permissions |
| `Microsoft.ManagedIdentity/userAssignedIdentities/assign/action` | Can attach MI to compute they control |

**Any role with `roleAssignments/write` is effectively Owner.**

### 7.5.2 Lateral Movement via Managed Identities

If a user can execute code on a compute resource with a managed identity, they inherit the MI's permissions.

**Attack chain:**
```
User has "Virtual Machine Contributor"
  → Can run commands on VM (runCommand)
  → VM has System-Assigned MI with "Owner" role
  → User is effectively Owner
```

**CIEM must map:**
1. User → Compute resources they can access
2. Compute → Managed Identities attached
3. Managed Identity → Role assignments

### 7.5.3 High-Risk Compute Permissions

| Permission | Allows Code Execution On |
|------------|--------------------------|
| `Microsoft.Compute/virtualMachines/runCommand/action` | VMs |
| `Microsoft.ContainerInstance/containerGroups/containers/exec/action` | Container Instances |
| `Microsoft.Web/sites/host/functionKeys/read` + invoke | Functions |
| `Microsoft.Kubernetes/connectedClusters/pods/exec/action` | Arc-enabled K8s |

---

## 8. Azure Roles vs Microsoft Entra Roles

Azure has two distinct role systems that don't overlap by default.

### 8.1 Azure Roles (Azure RBAC)

| Aspect | Description |
|--------|-------------|
| **Purpose** | Manage Azure resources |
| **Scope** | Management group → Subscription → Resource Group → Resource |
| **Location** | Access control (IAM) blade |
| **Examples** | Owner, Contributor, Virtual Machine Contributor |

### 8.2 Microsoft Entra Roles

| Aspect | Description |
|--------|-------------|
| **Purpose** | Manage Microsoft Entra directory objects |
| **Scope** | Tenant-wide, administrative units, or specific objects |
| **Location** | Microsoft Entra admin center |
| **Examples** | Global Administrator, User Administrator |

### 8.3 Comparison Table

| Aspect | Azure Roles | Microsoft Entra Roles |
|--------|-------------|----------------------|
| Manage | Azure resources (VMs, storage, etc.) | Directory objects (users, groups, apps) |
| Custom roles | Yes | Yes |
| Scope levels | 4 (MG, sub, RG, resource) | 3 (tenant, AU, object) |
| Access location | Azure portal IAM | Entra admin center |

### 8.4 Overlap: Global Administrator Elevation

Global Administrators can elevate to User Access Administrator for all Azure subscriptions via:
- Azure portal → Microsoft Entra ID → Properties → "Access management for Azure resources"

This creates a bridge between Entra and Azure RBAC.

---

## 9. Permission Evaluation Flow

How Azure determines if access is allowed:

```
1. User/SP requests action via Azure Resource Manager
2. ARM retrieves all role assignments and deny assignments for the resource
3. If deny assignment matches → ACCESS DENIED
4. ARM determines which roles apply to the user (including group memberships)
5. ARM checks if any role includes the requested action
6. If roles include Actions with wildcard (*), subtract NotActions
7. If action is in effective permissions → check conditions (ABAC)
8. If conditions pass → ACCESS ALLOWED
9. Otherwise → ACCESS DENIED
```

### Evaluation Logic Summary

```
Deny Assignment? → BLOCK
No matching role? → BLOCK
Action in (Actions - NotActions)? → Check conditions
Conditions pass? → ALLOW
Otherwise → BLOCK
```

---

## 10. CIEM Scanning Implications

Based on Azure's identity and permissions model, CIEM scanning should detect:

### 10.1 Identity Issues

| Detection | How to Find | PowerShell |
|-----------|-------------|------------|
| **Orphaned assignments** | `PrincipalType = "Unknown"` | `Get-AzRoleAssignment \| Where-Object { $_.ObjectType -eq "Unknown" }` |
| **Inactive users** | No sign-in for 90+ days | Requires Entra ID P1/P2 sign-in logs |
| **Stale service principals** | No sign-in activity | Entra ID sign-in reports |
| **Unused managed identities** | No token requests | Entra ID sign-in reports |
| **Classic Administrators** | Legacy admins not in standard RBAC | `Get-AzRoleAssignment -IncludeClassicAdministrators` |

### 10.2 Permission Issues

| Detection | How to Find | Risk |
|-----------|-------------|------|
| **Wildcard Actions** | `Actions` contains `*` | Overprivileged |
| **Owner at subscription** | Role = Owner, Scope = subscription | Super identity |
| **Contributor at management group** | Broad scope + high privilege | Excessive access |
| **Custom roles with wildcards** | `IsCustom = true` AND Actions contains `*` | Overprivileged custom role |
| **DataActions wildcards** | `DataActions` contains `*` | Unrestricted data access |
| **listKeys permissions** | Can retrieve resource keys | Data plane bypass |
| **roleAssignments/write** | Can assign any role | Effective Owner |

### 10.3 Hidden Access (Easily Missed)

| Detection | Why It's Missed | How to Find |
|-----------|-----------------|-------------|
| **PIM Eligible Assignments** | Not in standard RBAC queries | `Get-AzRoleEligibilitySchedule` |
| **Azure Lighthouse** | External tenant principals | `Get-AzManagedServicesDefinition` |
| **Key Vault Access Policies** | Non-RBAC access model | `(Get-AzKeyVault).AccessPolicies` |
| **Workload Identity Federation** | No secrets to scan | `Get-AzADAppFederatedCredential` |
| **ABAC Conditions** | May reduce actual access | Check `Condition` property on assignments |

### 10.4 Privilege Escalation Paths

| Detection | Attack Chain | Severity |
|-----------|--------------|----------|
| **VM Contributor + MI** | User → VM runCommand → MI permissions | Critical |
| **roleAssignments/write** | Self-assign Owner | Critical |
| **roleDefinitions/write** | Create privileged custom role | Critical |
| **listKeys on storage** | Bypass data RBAC | High |
| **Container exec + MI** | Execute in container with MI | Critical |

### 10.5 Key PowerShell Cmdlets for Scanning

```powershell
# === Standard RBAC ===
Get-AzRoleAssignment
Get-AzRoleAssignment -Scope "/subscriptions/{subscriptionId}"
Get-AzRoleDefinition -Custom
Get-AzDenyAssignment

# === Classic Administrators ===
Get-AzRoleAssignment -IncludeClassicAdministrators

# === PIM (Requires PIM module) ===
Get-AzRoleEligibilitySchedule -Scope "/subscriptions/{subscriptionId}"
Get-AzRoleAssignmentSchedule -Scope "/subscriptions/{subscriptionId}"

# === Azure Lighthouse ===
Get-AzManagedServicesDefinition
Get-AzManagedServicesAssignment

# === Key Vault Access Policies ===
Get-AzKeyVault | ForEach-Object { $_.AccessPolicies }

# === Workload Identity Federation ===
Get-AzADApplication | ForEach-Object {
    Get-AzADAppFederatedCredential -ApplicationObjectId $_.Id
}

# === Find Escalation Risks ===
Get-AzRoleDefinition | Where-Object {
    $_.Actions -like "*roleAssignments/write*" -or
    $_.Actions -like "*roleDefinitions/write*" -or
    $_.Actions -like "*listKeys*"
}

# === Find Orphaned Assignments ===
Get-AzRoleAssignment | Where-Object { $_.ObjectType -eq "Unknown" }

# === Find Conditional Assignments ===
Get-AzRoleAssignment | Where-Object { $_.Condition -ne $null }
```

### 10.6 Required Permissions for CIEM Scanning

| Permission | Purpose |
|------------|---------|
| `Microsoft.Authorization/roleAssignments/read` | List role assignments |
| `Microsoft.Authorization/roleDefinitions/read` | Read role definitions |
| `Microsoft.Authorization/denyAssignments/read` | List deny assignments |
| `Microsoft.ManagedServices/*/read` | List Lighthouse delegations |
| `Microsoft.KeyVault/vaults/read` | Read Key Vault config (access policies) |
| `Microsoft.Compute/virtualMachines/read` | Map VMs to managed identities |
| Entra ID "Directory Reader" | Resolve principal names |
| Entra ID "Reports Reader" | Access sign-in logs (for usage tracking) |

**Recommended approach**: Use a service principal with Reader role at management group scope, plus the specific permissions above, plus Entra ID Directory Reader.

---

## Sources

- [Azure RBAC Overview](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)
- [Azure Role Definitions](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-definitions)
- [Azure vs Entra Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/rbac-and-directory-admin-roles)
- [Managed Identities Overview](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/overview)
- [Service Principals and Managed Identities](https://learn.microsoft.com/en-us/azure/devops/integrate/get-started/authentication/service-principal-managed-identity)
