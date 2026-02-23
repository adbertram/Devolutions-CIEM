# CIEM Entity Standards

## Cloud Provider Model

Four levels, provider-agnostic:

```
Level 1: Provider            (Azure, AWS, ...)
Level 2: Pillar              (Identity, Entitlement, Resource)
Level 3: Type                (IdentityType, EntitlementType, ResourceType)
Level 4: Instance            (a specific user, role assignment, key vault, ...)
```

```
                       Provider
                     (Azure, AWS)
                          │
          ┌───────────────┼───────────────┐
          │               │               │
      Identity       Entitlement       Resource
       (WHO)           (HOW)           (WHAT)
          │               │               │
    IdentityType   EntitlementType   ResourceType
          │               │               │
      Instance         Instance        Instance
```

### Azure

Two dimensions define the Azure model: the **type taxonomy** (what kinds of entities exist) and the **scope hierarchy** (how instances nest at runtime).

**Resource boundary rule:** A resource is anything you can assign a permission to — via any mechanism (RBAC role assignment, SAS token, ACL, access policy, firewall rule, etc.). This goes deeper than ARM resource IDs. If a permission can target it, it's a resource in our model.

#### Type Taxonomy

```
Azure
├── Identity
│   ├── User                    (Graph /users)
│   ├── Group                   (Graph /groups)
│   ├── ServicePrincipal        (Graph /servicePrincipals)
│   ├── ManagedIdentity         (Graph /servicePrincipals, filtered by type)
│   └── Application             (Graph /applications)
│
├── Entitlement
│   ├── RoleAssignment          (ARG AuthorizationResources)
│   ├── RoleDefinition          (ARG AuthorizationResources)
│   ├── DirectoryRole           (Graph /directoryRoles)
│   └── AppRoleAssignment       (Graph /servicePrincipals/{id}/appRoleAssignedTo)
│
└── Resource
    └── Tenant                          (Graph /organization)
        └── ManagementGroup             (ARG ResourceContainers)
            └── Subscription            (ARG ResourceContainers)
                └── ResourceGroup       (ARG ResourceContainers)
                    ├── VirtualMachine                          RBAC
                    │   ├── Extension                           RBAC
                    │   └── RunCommand                          RBAC
                    ├── Disk                                    RBAC
                    ├── NetworkInterface                        RBAC
                    │   └── IPConfiguration                     RBAC
                    ├── PublicIPAddress                         RBAC
                    └── NetworkSecurityGroup                    RBAC
```

#### Scope Hierarchy

Resources nest inside each other in a strict containment chain. Entitlements are assigned at any scope and **inherit downward** — a RoleAssignment at Subscription grants access to every ResourceGroup and Resource beneath it.

```
Tenant
└── ManagementGroup              (can nest: MG → MG → ...)
    └── Subscription
        └── ResourceGroup
            └── Resource         (KeyVault, VM, StorageAccount, ...)
```

Identities (Entra ID) live at the **Tenant** scope — they are not scoped to subscriptions or resource groups. Entitlements bridge the two: they bind a tenant-scoped identity to a resource at any level of the scope hierarchy.

```
                Tenant
               ╱      ╲
        Identities    Scope Hierarchy
        (Entra ID)    (ARM)
             │              │
          User/SP    MG → Sub → RG → Resource
             │              │
             └── Entitlement ┘
                 (binds identity to scope)
```

#### Identity Types

| Type | API Source | Class | Category | PrincipalType |
|------|-----------|-------|----------|---------------|
| User | Graph `/users` | `CIEMAzureUser` | Human | User |
| Group | Graph `/groups` | `CIEMAzureGroup` | Collection | Group |
| ServicePrincipal | Graph `/servicePrincipals` | `CIEMAzureServicePrincipal` | Workload | ServicePrincipal |
| ManagedIdentity | Graph `/servicePrincipals` (filtered) | `CIEMAzureServicePrincipal` | Workload | ServicePrincipal |
| Application | Graph `/applications` | `CIEMAzureApplication` | Workload | *(null)* |

Category values: **Human** (interactive sign-in), **Collection** (contains other identities), **Workload** (non-human / automated).

ManagedIdentity shares the ServicePrincipal class — it's a ServicePrincipal with `servicePrincipalType` = `ManagedIdentity`.

#### Entitlement Types

| Type | API Source | Class | Scope Model |
|------|-----------|-------|-------------|
| RoleAssignment | ARG `AuthorizationResources` | `CIEMAzureRoleAssignment` | ARM scope (subscription/resourceGroup/resource) |
| RoleDefinition | ARG `AuthorizationResources` | `CIEMAzureRoleDefinition` | AssignableScopes |
| DirectoryRole | Graph `/directoryRoles` | `CIEMAzureDirectoryRole` | Tenant-wide |
| AppRoleAssignment | Graph `/servicePrincipals/{id}/appRoleAssignedTo` | `CIEMAzureAppRoleAssignment` | Per-application |

Azure has two distinct permission systems:
- **Azure RBAC** (RoleAssignment + RoleDefinition) — scoped to ARM resources via Actions/DataActions
- **Entra ID** (DirectoryRole + AppRoleAssignment) — scoped to the directory or individual applications

#### Resource Types

| Type | API Source | Class | ARG Table | ARM Type |
|------|-----------|-------|-----------|----------|
| Subscription | ARG | `CIEMAzureSubscription` | ResourceContainers | `microsoft.resources/subscriptions` |
| ResourceGroup | ARG | `CIEMAzureResourceGroup` | ResourceContainers | `microsoft.resources/subscriptions/resourcegroups` |
| VirtualMachine | ARG | `CIEMAzureVirtualMachine` | Resources | `microsoft.compute/virtualmachines` |
| StorageAccount | ARG | `CIEMAzureStorageAccount` | Resources | `microsoft.storage/storageaccounts` |
| KeyVault | ARG | `CIEMAzureKeyVault` | Resources | `microsoft.keyvault/vaults` |
| SqlServer | ARG | `CIEMAzureSqlServer` | Resources | `microsoft.sql/servers` |
| WebApp | ARG | `CIEMAzureWebApp` | Resources | `microsoft.web/sites` |
| AKS | ARG | `CIEMAzureAKS` | Resources | `microsoft.containerservice/managedclusters` |
| ContainerRegistry | ARG | `CIEMAzureContainerRegistry` | Resources | `microsoft.containerregistry/registries` |
| CosmosDB | ARG | `CIEMAzureCosmosDB` | Resources | `microsoft.documentdb/databaseaccounts` |
| NetworkSecurityGroup | ARG | `CIEMAzureNetworkSecurityGroup` | Resources | `microsoft.network/networksecuritygroups` |

Subscription and ResourceGroup serve dual purpose: they are resources AND scopes that contain other resources.

All ARG resources share a common ARM envelope (Id, Name, Type, Location, SubscriptionId, ResourceGroup, Tags, Kind, Sku, Identity) plus type-specific `properties.*` fields.

#### Graph Chain

The full entitlement chain from identity to resource in Azure RBAC:

```
User/Group/SP
  → HAS_ROLE_ASSIGNMENT → RoleAssignment (scope: /subscriptions/abc/...)
    → USES_ROLE → RoleDefinition (e.g., "Contributor")
      → HAS_PERMISSIONS → Permissions (Actions, DataActions, ...)
        → CAN_READ/CAN_WRITE/CAN_MANAGE → ResourceType (e.g., KeyVault)
```

The Entra ID entitlement chain is shorter:

```
User/Group/SP
  → HAS_APP_ROLE → AppRoleAssignment
    → ASSIGNED_TO → ServicePrincipal (the target application)

User/Group/SP
  → MEMBER_OF → DirectoryRole (tenant-wide admin role)
```

---

## Naming Convention

- **Classes**: `CIEM{Provider}{Entity}` — provider-specific, no base classes. Entities differ across clouds.
- **Low-level functions**: `Get-CIEM{Provider}{Entity}` — provider-specific, performs the actual API query
- **Orchestrators**: `Get-CIEM{Noun}` — handles auth, dispatches to low-level functions by provider
- **Metadata**: `Get-CIEM{Noun}Type` — reads static type catalog from JSON, no API calls

### All Object Types

| Noun | Live (`Get-CIEM{Noun}`) | Metadata (`Get-CIEM{Noun}Type`) | Low-level (`Get-CIEM{Provider}{Noun}`) |
|------|---|---|---|
| **Identity** | `Get-CIEMIdentity` | `Get-CIEMIdentityType` | `Get-CIEMAzureUser`, `Get-CIEMAzureGroup`, `Get-CIEMAzureServicePrincipal`, `Get-CIEMAzureApplication` |
| **CloudResource** | `Get-CIEMCloudResource` | `Get-CIEMCloudResourceType` | `Get-CIEMAzureVirtualMachine`, `Get-CIEMAzureStorageAccount`, `Get-CIEMAzureKeyVault`, ... |
| **RoleAssignment** | `Get-CIEMRoleAssignment` | — | `Get-CIEMAzureRoleAssignment` |
| **RoleDefinition** | `Get-CIEMRoleDefinition` | — | `Get-CIEMAzureRoleDefinition` |
| **AppRoleAssignment** | `Get-CIEMAppRoleAssignment` | — | `Get-CIEMAzureAppRoleAssignment` |
| **DirectoryRole** | `Get-CIEMDirectoryRole` | — | `Get-CIEMAzureDirectoryRole` |
| **Check** | — | `Get-CIEMCheck` | — |
| **ProviderService** | — | `Get-CIEMProviderService` | — |
| **Provider** | — | `Get-CIEMProvider` | — |
| **ScanRun** | — | `Get-CIEMScanRun` | — |
| **ScanResult** | — | `Get-CIEMScanResult` | — |

## Architecture

```
Get-CIEMCloudResource -Provider Azure -Type User
    │
    ├─ Connect-CIEM -Provider Azure        (authentication)
    ├─ Get-CIEMAzureUser                   (low-level API query)
    └─ returns CIEMAzureUser[]

Get-CIEMIdentity -Provider Azure
    │
    ├─ Get-CIEMCloudResource -Provider Azure -Type User
    ├─ Get-CIEMCloudResource -Provider Azure -Type Group
    ├─ Get-CIEMCloudResource -Provider Azure -Type ServicePrincipal
    ├─ Get-CIEMCloudResource -Provider Azure -Type Application
    └─ returns mixed CIEMAzureUser[] / CIEMAzureGroup[] / ...
```

## Data Sources

Azure entities come from two APIs. Class properties are modeled from their respective response schemas.

| Source | Entities | Query Method |
|--------|----------|-------------|
| **Azure Resource Graph** (`Resources` table) | VMs, Storage, KeyVault, SQL, WebApp, AKS, etc. | ARM envelope: `id`, `name`, `type`, `location`, `subscriptionId`, `resourceGroup`, `tags`, `sku`, `kind`, `identity` + type-specific `properties.*` |
| **Azure Resource Graph** (`AuthorizationResources` table) | Role assignments, role definitions | `properties.principalId`, `properties.roleDefinitionId`, `properties.scope`, etc. |
| **Azure Resource Graph** (`ResourceContainers` table) | Subscriptions, resource groups, management groups | ARM envelope |
| **Microsoft Graph API** | Users, groups, service principals, applications, directory roles, app role assignments | Graph-specific fields per entity |

---

## Enums

### CIEMCheckSeverity

| Value | File |
|-------|------|
| `low` | `Devolutions.CIEM/Classes/CIEMCheck.ps1` |
| `medium` | |
| `high` | |
| `critical` | |

### CIEMScanStatus

| Value | File |
|-------|------|
| `PASS` | `Devolutions.CIEM/Classes/CIEMScanResult.ps1` |
| `FAIL` | |
| `MANUAL` | |
| `SKIPPED` | |

### CIEMScanRunStatus

| Value | File |
|-------|------|
| `Running` | `Devolutions.CIEM/Classes/CIEMScanResult.ps1` |
| `Completed` | |
| `Failed` | |

### CIEMGraphNodeType

| Value | Description | File |
|-------|-------------|------|
| `EntraUser` | Entra ID user | `Devolutions.CIEM.Graph/Classes/CIEMGraphNode.ps1` |
| `EntraGroup` | Entra ID group | |
| `EntraServicePrincipal` | Entra ID service principal | |
| `EntraApplication` | Entra ID application | |
| `EntraAppRoleAssignment` | App role assignment | |
| `AzureRoleAssignment` | Azure RBAC role assignment | |
| `AzureRoleDefinition` | Azure RBAC role definition | |
| `AzurePermissions` | Permission set (actions/data actions) | |
| `AzureResourceType` | Azure resource type category node | |
| `AWSResourceType` | AWS resource type category node | |

### CIEMGraphRelationship

| Value | Category | File |
|-------|----------|------|
| `REPORTS_TO` | Identity | `Devolutions.CIEM.Graph/Classes/CIEMGraphEdge.ps1` |
| `MEMBER_OF` | Identity | |
| `OWNER_OF` | Identity | |
| `HAS_SERVICE_PRINCIPAL` | Identity | |
| `HAS_APP_ROLE` | App roles | |
| `ASSIGNED_TO` | App roles | |
| `HAS_ROLE_ASSIGNMENT` | RBAC | |
| `USES_ROLE` | RBAC | |
| `HAS_PERMISSIONS` | RBAC | |
| `CAN_READ` | Computed | |
| `CAN_WRITE` | Computed | |
| `CAN_MANAGE` | Computed | |

---

## Core Framework Classes (Devolutions.CIEM)

### CIEMProvider

| | |
|---|---|
| Class | `CIEMProvider` |
| File | `Devolutions.CIEM/Classes/CIEMProvider.ps1` |
| Purpose | Provider configuration (Azure, AWS, etc.) |

| Property | Type | Notes |
|----------|------|-------|
| Name | string | `'Azure'`, `'AWS'`, `'GCP'`, etc. |
| Enabled | bool | |
| IsDefault | bool | |
| Authentication | PSCustomObject | Untyped for PSU runspace compat; expected shape matches `CIEMAuthenticationContext` subclass |
| Endpoints | PSCustomObject | Provider-specific API endpoints |
| ResourceFilter | string[] | Subscription IDs / Account IDs |

Methods: `ToPSCustomObject()` — serializes for PSU cache.

### CIEMProviderService

| | |
|---|---|
| Class | `CIEMProviderService` |
| File | `Devolutions.CIEM/Classes/CIEMProviderService.ps1` |
| Purpose | Provider service reference |

| Property | Type |
|----------|------|
| Name | string |
| Provider | string |

### CIEMCheck

| | |
|---|---|
| Class | `CIEMCheck` |
| File | `Devolutions.CIEM/Classes/CIEMCheck.ps1` |
| Purpose | Security check definition |

| Property | Type | Notes |
|----------|------|-------|
| Id | string | |
| Provider | string | |
| Service | string | |
| Title | string | |
| Description | string | |
| Risk | string | |
| Severity | CIEMCheckSeverity | enum: low, medium, high, critical |
| Remediation | CIEMCheckRemediation | Sub-object (Text, Url) |
| RelatedUrl | string | |
| CheckScript | string | |
| DependsOn | string[] | |
| Permissions | CIEMCheckPermissions | Sub-object (Graph, ARM, KeyVaultDataPlane, IAM) |
| Disabled | bool | |

### CIEMCheckRemediation

| | |
|---|---|
| Class | `CIEMCheckRemediation` |
| File | `Devolutions.CIEM/Classes/CIEMCheck.ps1` |
| Purpose | Check remediation details |

| Property | Type |
|----------|------|
| Text | string |
| Url | string |

### CIEMCheckPermissions

| | |
|---|---|
| Class | `CIEMCheckPermissions` |
| File | `Devolutions.CIEM/Classes/CIEMCheck.ps1` |
| Purpose | Required API permissions for a check |

| Property | Type | Notes |
|----------|------|-------|
| Graph | string[] | Azure: Microsoft Graph API |
| ARM | string[] | Azure: Azure Resource Manager |
| KeyVaultDataPlane | string[] | Azure: Key Vault data plane |
| IAM | string[] | AWS: IAM actions |

### CIEMScanResult

| | |
|---|---|
| Class | `CIEMScanResult` |
| File | `Devolutions.CIEM/Classes/CIEMScanResult.ps1` |
| Purpose | Individual scan finding |

| Property | Type | Notes |
|----------|------|-------|
| Check | object | PSCustomObject from `Get-CIEMCheck` (not typed `[CIEMCheck]` for PSU runspace compat) |
| Status | CIEMScanStatus | PASS, FAIL, MANUAL, SKIPPED |
| StatusExtended | string | |
| ResourceId | string | |
| ResourceName | string | |
| Location | string | |

Static factory: `[CIEMScanResult]::Create($Check, $Status, $StatusExtended, $ResourceId, $ResourceName [, $Location])`

### CIEMScanRun

| | |
|---|---|
| Class | `CIEMScanRun` |
| File | `Devolutions.CIEM/Classes/CIEMScanResult.ps1` |
| Purpose | Scan execution tracking |

| Property | Type | Notes |
|----------|------|-------|
| Id | string | Auto-generated GUID |
| Status | CIEMScanRunStatus | Running, Completed, Failed |
| Providers | string[] | |
| ProviderSummaries | PSCustomObject[] | Per-provider counts (auto-computed) |
| Services | string[] | |
| StartTime | datetime | Auto-set on construction |
| EndTime | nullable[datetime] | |
| Duration | string | Human-readable (e.g., `"2m 15s"`) |
| IncludePassed | bool | |
| TotalResults | int | |
| FailedResults | int | |
| PassedResults | int | |
| SkippedResults | int | |
| ManualResults | int | |
| ScanResults | object[] | |
| ErrorMessage | string | Set on failure |

Methods: `GetDuration()`, `UpdateCounts()`, `UpdateProviderSummaries()`, `Complete()`, `Fail($ErrorMessage)`

### CIEMServiceCache

| | |
|---|---|
| Class | `CIEMServiceCache` |
| File | `Devolutions.CIEM/Classes/CIEMServiceCache.ps1` |
| Purpose | Per-service scan cache entry |

| Property | Type |
|----------|------|
| ServiceName | string |
| Success | bool |
| Duration | timespan |
| Errors | string[] |
| Warnings | string[] |
| Output | string[] |
| CacheData | hashtable |

---

## Abstraction / Metadata Classes (Devolutions.CIEM)

### CIEMIdentity

| | |
|---|---|
| Class | `CIEMIdentity` |
| File | `Devolutions.CIEM/Classes/CIEMIdentity.ps1` |
| Source | `Data/identity_types.json` |
| Function | `Get-CIEMIdentityType [-Provider] [-Name] [-Type]` |
| Purpose | Static identity type definition from JSON catalog |

| Property | Type | JSON Field | Notes |
|----------|------|------------|-------|
| Name | string | `name` | `"EntraUser"`, `"EntraServicePrincipal"`, etc. |
| DisplayName | string | `displayName` | `"User"`, `"Service Principal"`, etc. |
| Type | string | `type` | `"Human"`, `"Collection"`, `"Workload"` |
| Provider | string | *(key)* | `"Azure"`, `"AWS"` |
| PrincipalType | string | `principalType` | Azure RBAC principal type (`"User"`, `"Group"`, `"ServicePrincipal"`, null) |
| GraphNodeType | string | `graphNodeType` | Corresponding `CIEMGraphNodeType` enum value |
| Description | string | `description` | |

**Defined identity types** (`Data/identity_types.json`):

| Name | DisplayName | Type | PrincipalType | GraphNodeType |
|------|-------------|------|---------------|---------------|
| EntraUser | User | Human | User | EntraUser |
| EntraGroup | Group | Collection | Group | EntraGroup |
| EntraServicePrincipal | Service Principal | Workload | ServicePrincipal | EntraServicePrincipal |
| EntraManagedIdentity | Managed Identity | Workload | ServicePrincipal | EntraServicePrincipal |
| EntraApplication | Application | Workload | *(null)* | EntraApplication |

### CIEMResourceType (base)

| | |
|---|---|
| Class | `CIEMResourceType` |
| File | `Devolutions.CIEM/Classes/CIEMResourceType.ps1` |
| Source | `Data/resource_types.json` |
| Function | `Get-CIEMCloudResourceType [-Provider] [-Name]` |
| Purpose | Base resource type definition |

| Property | Type | Notes |
|----------|------|-------|
| Name | string | `"KeyVault"`, `"S3Bucket"`, etc. |
| DisplayName | string | `"Key Vault"`, `"S3 Bucket"`, etc. |
| Provider | string | `"Azure"`, `"AWS"` |
| ServiceName | string | Links to `CIEMProviderService.Name` |

### CIEMAzureResourceType

| | |
|---|---|
| Class | `CIEMAzureResourceType : CIEMResourceType` |
| File | `Devolutions.CIEM/Classes/CIEMResourceType.ps1` |

| Property | Type | Notes |
|----------|------|-------|
| *(inherited)* | | |
| ArmProviderPrefix | string | `"Microsoft.KeyVault/vaults"`, etc. (null for Subscription) |

### CIEMAWSResourceType

| | |
|---|---|
| Class | `CIEMAWSResourceType : CIEMResourceType` |
| File | `Devolutions.CIEM/Classes/CIEMResourceType.ps1` |

| Property | Type | Notes |
|----------|------|-------|
| *(inherited)* | | |
| ArnServicePrefix | string | `"s3"`, `"ec2"`, `"iam"`, etc. |

**Defined resource types** (`Data/resource_types.json`):

| Name | Provider | DisplayName | ServiceName | ArmProviderPrefix / ArnServicePrefix |
|------|----------|-------------|-------------|--------------------------------------|
| AKS | Azure | AKS | Aks | `Microsoft.ContainerService/managedClusters` |
| ContainerRegistry | Azure | Container Registry | Containerregistry | `Microsoft.ContainerRegistry/registries` |
| CosmosDB | Azure | Cosmos DB | Cosmosdb | `Microsoft.DocumentDB/databaseAccounts` |
| KeyVault | Azure | Key Vault | KeyVault | `Microsoft.KeyVault/vaults` |
| NetworkSecurityGroup | Azure | Network Security Group | Network | `Microsoft.Network/networkSecurityGroups` |
| ResourceGroup | Azure | Resource Group | *(null)* | `Microsoft.Resources/subscriptions/resourceGroups` |
| SqlServer | Azure | SQL Server | Sqlserver | `Microsoft.Sql/servers` |
| StorageAccount | Azure | Storage Account | Storage | `Microsoft.Storage/storageAccounts` |
| Subscription | Azure | Subscription | *(null)* | *(null)* |
| VirtualMachine | Azure | Virtual Machine | Vm | `Microsoft.Compute/virtualMachines` |
| WebApp | Azure | Web App | App | `Microsoft.Web/sites` |
| S3Bucket | AWS | S3 Bucket | S3 | `s3` |
| EC2Instance | AWS | EC2 Instance | EC2 | `ec2` |
| IAMRole | AWS | IAM Role | IAM | `iam` |
| LambdaFunction | AWS | Lambda Function | Lambda | `lambda` |

---

## Authentication Context Classes (Devolutions.CIEM)

All defined in `Devolutions.CIEM/Classes/CIEMCheck.ps1`. Inheritance hierarchy:

```
CIEMAuthenticationContext
├── CIEMAzureAuthenticationContext
│   ├── CIEMAzureSPAuthenticationContext              (Method = "ServicePrincipalSecret")
│   ├── CIEMAzureSPCertificateAuthenticationContext   (Method = "ServicePrincipalCertificate")
│   ├── CIEMAzureManagedIdentityAuthenticationContext  (Method = "ManagedIdentity")
│   ├── CIEMAzureDeviceCodeAuthenticationContext       (Method = "DeviceCode")
│   └── CIEMAzureInteractiveAuthenticationContext      (Method = "Interactive")
└── CIEMAWSAuthenticationContext
    ├── CIEMAWSCurrentProfileAuthenticationContext     (Method = "CurrentProfile")
    └── CIEMAWSAccessKeyAuthenticationContext          (Method = "AccessKey")
```

### CIEMAuthenticationContext (base)

| Property | Type | Notes |
|----------|------|-------|
| Provider | string | Set by subclass constructor |
| Enabled | bool | |
| Method | string | Set by subclass constructor |

### CIEMAzureAuthenticationContext

| Property | Type | Notes |
|----------|------|-------|
| *(inherited)* | | Provider = `"Azure"` |
| TenantId | string | |

### CIEMAzureSPAuthenticationContext

| Property | Type | Notes |
|----------|------|-------|
| *(inherited)* | | Method = `"ServicePrincipalSecret"` |
| ClientId | string | |
| HasClientSecret | bool | true when secret exists in PSU secret store |

### CIEMAzureSPCertificateAuthenticationContext

| Property | Type | Notes |
|----------|------|-------|
| *(inherited)* | | Method = `"ServicePrincipalCertificate"` |
| ClientId | string | |
| HasCertThumbprint | bool | true when thumbprint exists in PSU secret store |

### CIEMAzureManagedIdentityAuthenticationContext

| Property | Type | Notes |
|----------|------|-------|
| *(inherited)* | | Method = `"ManagedIdentity"` |
| ManagedIdentityClientId | string | null = system-assigned |

### CIEMAzureDeviceCodeAuthenticationContext

No additional properties. Method = `"DeviceCode"`.

### CIEMAzureInteractiveAuthenticationContext

No additional properties. Method = `"Interactive"`.

### CIEMAWSAuthenticationContext

| Property | Type | Notes |
|----------|------|-------|
| *(inherited)* | | Provider = `"AWS"` |
| Region | string | |

### CIEMAWSCurrentProfileAuthenticationContext

| Property | Type | Notes |
|----------|------|-------|
| *(inherited)* | | Method = `"CurrentProfile"` |
| Profile | string | |

### CIEMAWSAccessKeyAuthenticationContext

| Property | Type | Notes |
|----------|------|-------|
| *(inherited)* | | Method = `"AccessKey"` |
| HasAccessKeyId | bool | true when key exists in PSU secret store |
| HasSecretAccessKey | bool | true when key exists in PSU secret store |

---

## Identity Entities (Microsoft Graph API)

### User

| | |
|---|---|
| Class | `CIEMAzureUser` |
| Source | Microsoft Graph `/users` |
| Function | `Get-CIEMAzureUser [-Id]` |

| Property | Type | Graph Field |
|----------|------|-------------|
| Id | string | `id` |
| DisplayName | string | `displayName` |
| UserPrincipalName | string | `userPrincipalName` |
| AccountEnabled | bool | `accountEnabled` |
| UserType | string | `userType` (Member/Guest) |
| ManagerId | string | `manager.id` (via `$expand`) |
| Department | string | `department` |
| JobTitle | string | `jobTitle` |

### Group

| | |
|---|---|
| Class | `CIEMAzureGroup` |
| Source | Microsoft Graph `/groups` |
| Function | `Get-CIEMAzureGroup [-Id] [-IncludeMembers] [-IncludeOwners]` |

| Property | Type | Graph Field |
|----------|------|-------------|
| Id | string | `id` |
| DisplayName | string | `displayName` |
| SecurityEnabled | bool | `securityEnabled` |
| IsAssignableToRole | bool | `isAssignableToRole` |
| GroupTypes | string[] | `groupTypes` |
| Visibility | string | `visibility` |
| Members | PSCustomObject[] | `/groups/{id}/members` (Id, DisplayName, Type) |
| Owners | PSCustomObject[] | `/groups/{id}/owners` (Id, DisplayName, Type) |

### Service Principal

| | |
|---|---|
| Class | `CIEMAzureServicePrincipal` |
| Source | Microsoft Graph `/servicePrincipals` |
| Function | `Get-CIEMAzureServicePrincipal [-Id]` |

| Property | Type | Graph Field |
|----------|------|-------------|
| Id | string | `id` |
| DisplayName | string | `displayName` |
| AppId | string | `appId` |
| ServicePrincipalType | string | `servicePrincipalType` |
| AccountEnabled | bool | `accountEnabled` |
| SignInAudience | string | `signInAudience` |
| Tags | string[] | `tags` |

### Application

| | |
|---|---|
| Class | `CIEMAzureApplication` |
| Source | Microsoft Graph `/applications` |
| Function | `Get-CIEMAzureApplication [-Id]` |

| Property | Type | Graph Field |
|----------|------|-------------|
| Id | string | `id` |
| DisplayName | string | `displayName` |
| AppId | string | `appId` |
| PublisherDomain | string | `publisherDomain` |
| SignInAudience | string | `signInAudience` |

---

## RBAC Entities (Azure Resource Graph — AuthorizationResources)

### Role Assignment

| | |
|---|---|
| Class | `CIEMAzureRoleAssignment` |
| Source | ARG `AuthorizationResources` where `type =~ 'microsoft.authorization/roleassignments'` |
| Function | `Get-CIEMAzureRoleAssignment [-SubscriptionId]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| Id | string | `id` |
| Name | string | `name` |
| PrincipalId | string | `properties.principalId` |
| PrincipalType | string | `properties.principalType` (User/Group/ServicePrincipal) |
| RoleDefinitionId | string | `properties.roleDefinitionId` |
| Scope | string | `properties.scope` |
| Description | string | `properties.description` |
| Condition | string | `properties.condition` |
| CreatedOn | datetime | `properties.createdOn` |
| CreatedBy | string | `properties.createdBy` |
| UpdatedOn | datetime | `properties.updatedOn` |
| UpdatedBy | string | `properties.updatedBy` |

### Role Definition

| | |
|---|---|
| Class | `CIEMAzureRoleDefinition` |
| Source | ARG `AuthorizationResources` where `type =~ 'microsoft.authorization/roledefinitions'` |
| Function | `Get-CIEMAzureRoleDefinition [-SubscriptionId] [-CustomOnly]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| Id | string | `id` |
| RoleName | string | `properties.roleName` |
| Description | string | `properties.description` |
| RoleType | string | `properties.type` (BuiltInRole/CustomRole) |
| AssignableScopes | string[] | `properties.assignableScopes` |
| Actions | string[] | `properties.permissions[0].actions` |
| NotActions | string[] | `properties.permissions[0].notActions` |
| DataActions | string[] | `properties.permissions[0].dataActions` |
| NotDataActions | string[] | `properties.permissions[0].notDataActions` |

### App Role Assignment

| | |
|---|---|
| Class | `CIEMAzureAppRoleAssignment` |
| Source | Microsoft Graph `/servicePrincipals/{id}/appRoleAssignedTo` |
| Function | `Get-CIEMAzureAppRoleAssignment -ServicePrincipalId <string>` |

| Property | Type | Graph Field |
|----------|------|-------------|
| Id | string | `id` |
| AppRoleId | string | `appRoleId` |
| PrincipalId | string | `principalId` |
| PrincipalType | string | `principalType` |
| PrincipalDisplayName | string | `principalDisplayName` |
| ResourceId | string | `resourceId` |
| ResourceDisplayName | string | `resourceDisplayName` |
| CreatedDateTime | string | `createdDateTime` |

---

## Directory Entities (Microsoft Graph API)

### Directory Role

| | |
|---|---|
| Class | `CIEMAzureDirectoryRole` |
| Source | Microsoft Graph `/directoryRoles` |
| Function | `Get-CIEMAzureDirectoryRole [-Id] [-IncludeMembers]` |

| Property | Type | Graph Field |
|----------|------|-------------|
| Id | string | `id` |
| DisplayName | string | `displayName` |
| Description | string | `description` |
| RoleTemplateId | string | `roleTemplateId` |
| Members | PSCustomObject[] | `/directoryRoles/{id}/members` (Id, DisplayName, Type) |

---

## Cloud Resource Entities (Azure Resource Graph — Resources table)

All Azure resources share the ARM envelope. Class properties are pulled from top-level ARG columns + type-specific `properties.*` fields.

### ARM Envelope (common to all Azure resource classes)

| Property | Type | ARG Column |
|----------|------|-----------|
| Id | string | `id` |
| Name | string | `name` |
| Type | string | `type` |
| Location | string | `location` |
| SubscriptionId | string | `subscriptionId` |
| ResourceGroup | string | `resourceGroup` |
| Tags | hashtable | `tags` |
| Kind | string | `kind` |
| Sku | string | `sku.name` |
| Identity | PSCustomObject | `identity` (principalId, type, userAssignedIdentities) |

### Virtual Machine

| | |
|---|---|
| Class | `CIEMAzureVirtualMachine` |
| Source | ARG `Resources` where `type == 'microsoft.compute/virtualmachines'` |
| Function | `Get-CIEMAzureVirtualMachine [-SubscriptionId] [-ResourceGroup]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| *(ARM envelope)* | | |
| VmSize | string | `properties.hardwareProfile.vmSize` |
| OsType | string | `properties.storageProfile.osDisk.osType` |
| ComputerName | string | `properties.osProfile.computerName` |
| ProvisioningState | string | `properties.provisioningState` |
| VmId | string | `properties.vmId` |

### Storage Account

| | |
|---|---|
| Class | `CIEMAzureStorageAccount` |
| Source | ARG `Resources` where `type == 'microsoft.storage/storageaccounts'` |
| Function | `Get-CIEMAzureStorageAccount [-SubscriptionId] [-ResourceGroup]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| *(ARM envelope)* | | |
| SupportsHttpsTrafficOnly | bool | `properties.supportsHttpsTrafficOnly` |
| MinimumTlsVersion | string | `properties.minimumTlsVersion` |
| AllowBlobPublicAccess | bool | `properties.allowBlobPublicAccess` |
| AllowSharedKeyAccess | bool | `properties.allowSharedKeyAccess` |
| NetworkDefaultAction | string | `properties.networkAcls.defaultAction` |
| EncryptionKeySource | string | `properties.encryption.keySource` |

### Key Vault

| | |
|---|---|
| Class | `CIEMAzureKeyVault` |
| Source | ARG `Resources` where `type == 'microsoft.keyvault/vaults'` |
| Function | `Get-CIEMAzureKeyVault [-SubscriptionId] [-ResourceGroup]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| *(ARM envelope)* | | |
| VaultUri | string | `properties.vaultUri` |
| EnableRbacAuthorization | bool | `properties.enableRbacAuthorization` |
| EnableSoftDelete | bool | `properties.enableSoftDelete` |
| EnablePurgeProtection | bool | `properties.enablePurgeProtection` |
| SoftDeleteRetentionInDays | int | `properties.softDeleteRetentionInDays` |
| NetworkDefaultAction | string | `properties.networkAcls.defaultAction` |

### SQL Server

| | |
|---|---|
| Class | `CIEMAzureSqlServer` |
| Source | ARG `Resources` where `type == 'microsoft.sql/servers'` |
| Function | `Get-CIEMAzureSqlServer [-SubscriptionId] [-ResourceGroup]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| *(ARM envelope)* | | |
| FullyQualifiedDomainName | string | `properties.fullyQualifiedDomainName` |
| AdministratorLogin | string | `properties.administratorLogin` |
| State | string | `properties.state` |
| Version | string | `properties.version` |

### Web App

| | |
|---|---|
| Class | `CIEMAzureWebApp` |
| Source | ARG `Resources` where `type == 'microsoft.web/sites'` |
| Function | `Get-CIEMAzureWebApp [-SubscriptionId] [-ResourceGroup]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| *(ARM envelope)* | | |
| DefaultHostName | string | `properties.defaultHostName` |
| State | string | `properties.state` |
| HttpsOnly | bool | `properties.httpsOnly` |
| ServerFarmId | string | `properties.serverFarmId` |

### AKS

| | |
|---|---|
| Class | `CIEMAzureAKS` |
| Source | ARG `Resources` where `type == 'microsoft.containerservice/managedclusters'` |
| Function | `Get-CIEMAzureAKS [-SubscriptionId] [-ResourceGroup]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| *(ARM envelope)* | | |
| KubernetesVersion | string | `properties.kubernetesVersion` |
| DnsPrefix | string | `properties.dnsPrefix` |
| Fqdn | string | `properties.fqdn` |
| ProvisioningState | string | `properties.provisioningState` |
| PowerStateCode | string | `properties.powerState.code` |

### Container Registry

| | |
|---|---|
| Class | `CIEMAzureContainerRegistry` |
| Source | ARG `Resources` where `type == 'microsoft.containerregistry/registries'` |
| Function | `Get-CIEMAzureContainerRegistry [-SubscriptionId] [-ResourceGroup]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| *(ARM envelope)* | | |
| LoginServer | string | `properties.loginServer` |
| AdminUserEnabled | bool | `properties.adminUserEnabled` |
| ProvisioningState | string | `properties.provisioningState` |

### Cosmos DB

| | |
|---|---|
| Class | `CIEMAzureCosmosDB` |
| Source | ARG `Resources` where `type == 'microsoft.documentdb/databaseaccounts'` |
| Function | `Get-CIEMAzureCosmosDB [-SubscriptionId] [-ResourceGroup]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| *(ARM envelope)* | | |
| DatabaseAccountOfferType | string | `properties.databaseAccountOfferType` |
| DocumentEndpoint | string | `properties.documentEndpoint` |
| EnableAutomaticFailover | bool | `properties.enableAutomaticFailover` |
| ConsistencyLevel | string | `properties.consistencyPolicy.defaultConsistencyLevel` |

### Network Security Group

| | |
|---|---|
| Class | `CIEMAzureNetworkSecurityGroup` |
| Source | ARG `Resources` where `type == 'microsoft.network/networksecuritygroups'` |
| Function | `Get-CIEMAzureNetworkSecurityGroup [-SubscriptionId] [-ResourceGroup]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| *(ARM envelope)* | | |
| ProvisioningState | string | `properties.provisioningState` |
| SecurityRuleCount | int | count of `properties.securityRules` |
| DefaultSecurityRuleCount | int | count of `properties.defaultSecurityRules` |

### Subscription

| | |
|---|---|
| Class | `CIEMAzureSubscription` |
| Source | ARG `ResourceContainers` where `type == 'microsoft.resources/subscriptions'` |
| Function | `Get-CIEMAzureSubscription` |

| Property | Type | ARG Field |
|----------|------|-----------|
| Id | string | `id` |
| Name | string | `name` |
| SubscriptionId | string | `subscriptionId` |
| TenantId | string | `tenantId` |
| State | string | `properties.state` |

### Resource Group

| | |
|---|---|
| Class | `CIEMAzureResourceGroup` |
| Source | ARG `ResourceContainers` where `type == 'microsoft.resources/subscriptions/resourcegroups'` |
| Function | `Get-CIEMAzureResourceGroup [-SubscriptionId]` |

| Property | Type | ARG Field |
|----------|------|-----------|
| Id | string | `id` |
| Name | string | `name` |
| Location | string | `location` |
| SubscriptionId | string | `subscriptionId` |
| Tags | hashtable | `tags` |
| ProvisioningState | string | `properties.provisioningState` |

---

## Graph Module (Devolutions.CIEM.Graph)

The graph module builds an in-memory identity/access graph from the entities above. It has its own class hierarchy separate from the entity classes.

**Important:** The Graph module defines classes like `CIEMAzureRoleAssignment` and `CIEMAzureRoleDefinition` that are **graph node subclasses** (inheriting `CIEMGraphNode`). These are distinct from the entity classes with the same name in `Devolutions.CIEM` — the graph nodes have a reduced property set optimized for graph traversal.

### CIEMGraphNode (base)

| | |
|---|---|
| Class | `CIEMGraphNode` |
| File | `Devolutions.CIEM.Graph/Classes/CIEMGraphNode.ps1` |
| Purpose | Base class for all graph nodes |

| Property | Type |
|----------|------|
| Id | string |
| NodeType | CIEMGraphNodeType |

### CIEMGraphEdge

| | |
|---|---|
| Class | `CIEMGraphEdge` |
| File | `Devolutions.CIEM.Graph/Classes/CIEMGraphEdge.ps1` |
| Purpose | Directed edge between two graph nodes |

| Property | Type |
|----------|------|
| SourceId | string |
| TargetId | string |
| Relationship | CIEMGraphRelationship |
| Properties | hashtable |

### CIEMGraph

| | |
|---|---|
| Class | `CIEMGraph` |
| File | `Devolutions.CIEM.Graph/Classes/CIEMGraph.ps1` |
| Purpose | Main graph container with indexed lookup |

| Property | Type | Notes |
|----------|------|-------|
| Nodes | hashtable | Keyed by node Id |
| Edges | List[CIEMGraphEdge] | |
| EdgesBySource | hashtable | *(hidden)* Indexed by SourceId |
| EdgesByTarget | hashtable | *(hidden)* Indexed by TargetId |
| BuildTime | datetime | UTC |
| TenantId | string | |
| SubscriptionIds | string[] | |

| Method | Signature | Purpose |
|--------|-----------|---------|
| AddNode | `(CIEMGraphNode)` | Add a node to the graph |
| AddEdge | `(CIEMGraphEdge)` or `(string, string, CIEMGraphRelationship)` | Add an edge (auto-indexes) |
| GetNode | `(string) → CIEMGraphNode` | Lookup by Id |
| GetEdgesFrom | `(string) → CIEMGraphEdge[]` | Outgoing edges from a node |
| GetEdgesTo | `(string) → CIEMGraphEdge[]` | Incoming edges to a node |
| GetEdgesByRelationship | `(CIEMGraphRelationship) → CIEMGraphEdge[]` | All edges of a relationship type |
| GetNodesByType | `(CIEMGraphNodeType) → CIEMGraphNode[]` | All nodes of a type |
| Traverse | `(string, CIEMGraphRelationship[]) → CIEMGraphNode[]` | Walk a chain of relationships from a start node |
| ToPSCustomObject | `() → PSCustomObject` | Serialize for PSU cache |
| FromPSCustomObject | `static (PSCustomObject) → CIEMGraph` | Deserialize from PSU cache |

### Graph Identity Nodes

All defined in `Devolutions.CIEM.Graph/Classes/CIEMIdentityNodes.ps1`, inheriting `CIEMGraphNode`.

#### CIEMEntraUser

| Property | Type | NodeType |
|----------|------|----------|
| *(Id, NodeType)* | | `EntraUser` |
| UserPrincipalName | string | |
| DisplayName | string | |
| AccountEnabled | bool | |
| UserType | string | |
| ManagerId | string | |
| Department | string | |
| JobTitle | string | |

#### CIEMEntraGroup

| Property | Type | NodeType |
|----------|------|----------|
| *(Id, NodeType)* | | `EntraGroup` |
| DisplayName | string | |
| SecurityEnabled | bool | |
| IsAssignableToRole | bool | |
| GroupTypes | string[] | |
| Visibility | string | |

#### CIEMEntraServicePrincipal

| Property | Type | NodeType |
|----------|------|----------|
| *(Id, NodeType)* | | `EntraServicePrincipal` |
| AppId | string | |
| DisplayName | string | |
| ServicePrincipalType | string | |
| AccountEnabled | bool | |
| SignInAudience | string | |
| Tags | string[] | |

#### CIEMEntraApplication

| Property | Type | NodeType |
|----------|------|----------|
| *(Id, NodeType)* | | `EntraApplication` |
| AppId | string | |
| DisplayName | string | |
| PublisherDomain | string | |
| SignInAudience | string | |

#### CIEMEntraAppRoleAssignment

| Property | Type | NodeType |
|----------|------|----------|
| *(Id, NodeType)* | | `EntraAppRoleAssignment` |
| AppRoleId | string | |
| PrincipalId | string | |
| PrincipalType | string | |
| PrincipalDisplayName | string | |
| ResourceId | string | |
| ResourceDisplayName | string | |
| CreatedDateTime | string | |

### Graph RBAC Nodes

All defined in `Devolutions.CIEM.Graph/Classes/CIEMRBACNodes.ps1`, inheriting `CIEMGraphNode`.

#### CIEMAzureRoleAssignment (Graph Node)

| Property | Type | NodeType |
|----------|------|----------|
| *(Id, NodeType)* | | `AzureRoleAssignment` |
| PrincipalId | string | |
| PrincipalType | string | |
| RoleDefinitionId | string | |
| Scope | string | |
| ScopeType | string | |
| Condition | string | |
| CreatedBy | string | |
| UpdatedBy | string | |

#### CIEMAzureRoleDefinition (Graph Node)

| Property | Type | NodeType |
|----------|------|----------|
| *(Id, NodeType)* | | `AzureRoleDefinition` |
| RoleName | string | |
| Description | string | |
| AssignableScopes | string[] | |
| RoleType | string | |

#### CIEMAzurePermissions

| Property | Type | NodeType |
|----------|------|----------|
| *(Id, NodeType)* | | `AzurePermissions` |
| Actions | string[] | |
| NotActions | string[] | |
| DataActions | string[] | |
| NotDataActions | string[] | |

#### CIEMAzureResourceTypeNode

| Property | Type | NodeType |
|----------|------|----------|
| *(Id, NodeType)* | | `AzureResourceType` |
| ResourceTypeName | string | Matches `CIEMAzureResourceType.Name` |
| DisplayName | string | |
| ArmProviderPrefix | string | |

#### CIEMAWSResourceTypeNode

| Property | Type | NodeType |
|----------|------|----------|
| *(Id, NodeType)* | | `AWSResourceType` |
| ResourceTypeName | string | Matches `CIEMAWSResourceType.Name` |
| DisplayName | string | |
| ArnServicePrefix | string | |

### Permission Relationships Data

Defined in `Devolutions.CIEM.Graph/Data/permission_relationships.json`. Maps ARM permissions to computed graph relationships (`CAN_READ`, `CAN_WRITE`, `CAN_MANAGE`) per resource type.

| Target Type | CAN_READ Permissions | CAN_WRITE Permissions | CAN_MANAGE Permissions |
|-------------|----------------------|-----------------------|------------------------|
| SqlServer | `servers/read`, `servers/databases/read` | `servers/write`, `servers/databases/write` | `servers/*` |
| KeyVault | `vaults/read`, `vaults/secrets/read` | `vaults/write`, `vaults/secrets/write` | `vaults/*` |
| StorageAccount | `storageAccounts/read`, `storageAccounts/listKeys/action` | `storageAccounts/write` | `storageAccounts/*` |
| VirtualMachine | `virtualMachines/read` | `virtualMachines/write`, `start/action`, `restart/action` | `virtualMachines/*` |
| NetworkSecurityGroup | `networkSecurityGroups/read` | `networkSecurityGroups/write`, `securityRules/write` | `networkSecurityGroups/*` |
| WebApp | `sites/read` | `sites/write`, `sites/config/write` | `sites/*` |
| ContainerRegistry | `registries/read`, `registries/pull/read` | `registries/write`, `registries/push/write` | `registries/*` |
| CosmosDB | `databaseAccounts/read`, `databaseAccounts/listKeys/action` | `databaseAccounts/write` | `databaseAccounts/*` |
| AKS | `managedClusters/read`, `listClusterUserCredential/action` | `managedClusters/write` | `managedClusters/*` |
| Subscription | `*/read` | — | `*` |
| ResourceGroup | `subscriptions/resourceGroups/read` | `subscriptions/resourceGroups/write` | `subscriptions/resourceGroups/*` |

---

## Orchestrator Functions (live API queries)

| Function | Purpose |
|----------|---------|
| `Get-CIEMCloudResource -Provider <string> -Type <string> [...]` | Authenticates via `Connect-CIEM`, dispatches to the correct `Get-CIEM{Provider}{Entity}` function, returns typed objects |
| `Get-CIEMIdentity -Provider <string> [-Type <string[]>]` | Calls `Get-CIEMCloudResource` for identity types (User, Group, ServicePrincipal, Application), streams combined results |
| `Get-CIEMRoleAssignment -Provider <string> [...]` | Dispatches to `Get-CIEMAzureRoleAssignment`, etc. |
| `Get-CIEMRoleDefinition -Provider <string> [...]` | Dispatches to `Get-CIEMAzureRoleDefinition`, etc. |
| `Get-CIEMAppRoleAssignment -Provider <string> [...]` | Dispatches to `Get-CIEMAzureAppRoleAssignment`, etc. |
| `Get-CIEMDirectoryRole -Provider <string> [...]` | Dispatches to `Get-CIEMAzureDirectoryRole`, etc. |

## Metadata Functions (static type catalogs)

| Function | Source | Returns |
|----------|--------|---------|
| `Get-CIEMCloudResourceType [-Provider] [-Name]` | `Data/resource_types.json` | Static resource type definitions (renamed from `Get-CIEMResourceType`) |
| `Get-CIEMIdentityType [-Provider] [-Name] [-Type]` | `Data/identity_types.json` | Static identity type definitions (renamed from `Get-CIEMIdentity`) |

## Graph Functions

| Function | Purpose |
|----------|---------|
| `New-CIEMGraph -Provider <string> [...]` | Builds the full identity/access graph from live entities |
| `Get-CIEMGraphSummary -Graph <CIEMGraph>` | Returns summary statistics for a built graph |
| `ConvertTo-CIEMGraphMermaid -Graph <CIEMGraph> [...]` | Exports graph to Mermaid diagram format |
