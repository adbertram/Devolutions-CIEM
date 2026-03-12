# Devolutions CIEM — Data Model Architecture

## Overview

Discovery-first data model. The collection engine scans the tenant to discover what exists and stores raw API responses. No static resource type registry. No per-type entity tables. No transform functions. Relationship mapping happens at runtime on stored data.

### Design Principles

1. **Discovery-first** — Scan the tenant to find what exists. The database reflects the user's actual environment, not a pre-defined schema of what Azure _could_ have.
2. **Store raw responses** — Common fields extracted as columns; type-specific data stays as JSON in `properties`. No per-type transform functions. `json_extract()` handles type-specific queries.
3. **Provider isolation** — Each provider gets its own tables. Only `providers` is shared.
4. **Idempotent** — Discovery can be re-run anytime. Clear existing data for the source, re-collect, insert fresh.
5. **Relationship mapping at runtime** — Resources link to each other via ARM IDs and Entra GUIDs embedded in their properties. Analysis functions resolve these after collection.

### Data Sources

| Source | What It Covers | How It Works |
|--------|---------------|-------------|
| **Azure Resource Graph** | ALL ARM resources, subscriptions, resource groups, role assignments, role definitions | REST API via `Invoke-AzureApi -Api ARM` (`POST .../providers/Microsoft.ResourceGraph/resources`). Three tables: `Resources`, `ResourceContainers`, `AuthorizationResources`. Returns a consistent shape for ALL resource types. |
| **Azure ARM API** | Built-in role definitions (not returned by Resource Graph) | REST API via `Invoke-AzureApi -Api ARM`. Required to resolve role assignment → permission chain. |
| **Microsoft Graph API** | Entra ID: users, groups, service principals, applications, directory roles, app role assignments, OAuth2 grants | REST API via `Invoke-AzureApi -Api Graph`. Each entity type has its own endpoint. |

**Key insight:** Azure Resource Graph is not a general Azure schema — it only returns resources that exist in the authenticated tenant. The app dynamically discovers the tenant's resource landscape instead of maintaining a static catalog.

---

## Permission Requirements

Discovery requires a **dedicated service principal** (app registration) with read-only access to both ARM resources and Entra ID.

### Required Permissions

**Azure RBAC (ARM / Resource Graph):**

| Role | Scope | Purpose |
|------|-------|---------|
| `Reader` | Root management group (recommended) or each subscription | Resource Graph queries, ARM API calls |

**Microsoft Graph API (Entra ID) — Application permissions:**

| Permission | Required | Purpose |
|-----------|----------|---------|
| `Directory.Read.All` | Yes | Users, groups, service principals, applications, directory roles, memberships, OAuth2 grants |
| `AuditLog.Read.All` | Recommended | `signInActivity` on users and service principals (dormant permission detection). Requires Azure AD Premium P1. |

### Permission Tiers

| Tier | ARM | Graph | What You Get |
|------|-----|-------|-------------|
| **Minimum** | `Reader` on each subscription | `Directory.Read.All` | Full discovery minus sign-in activity and management group visibility |
| **Recommended** | `Reader` on root management group | `Directory.Read.All` + `AuditLog.Read.All` | Full discovery including dormant permission detection |

### Notes

- Authentication is handled by the existing auth module — not ResourceDiscovery's concern.
- Discovery uses whatever identity is configured in the active auth profile.
- Discovery should handle 403s gracefully (skip + log).

---

## Database Tables

### `providers` (existing)

Cloud environments to scan. Shared across providers. Already exists. Drop `is_default` column; update `CIEMProvider` class to remove `IsDefault` property.

### `azure_arm_resources` (new)

**ALL ARM resources from Azure Resource Graph.** One table for everything — VMs, disks, NSGs, key vaults, app services, subscriptions, resource groups, role assignments, role definitions, etc.

Combines results from all three Resource Graph tables (`Resources`, `ResourceContainers`, `AuthorizationResources`). The `type` column distinguishes them.

Common fields are columns; type-specific `properties` stays as JSON.

### `azure_entra_resources` (new)

**ALL Entra ID resources from Microsoft Graph API.** Users, groups, service principals, applications, directory roles, app role assignments, OAuth2 permission grants.

Common fields extracted; full Graph API response stored in `properties`.

**ID uniqueness:** Entity types (user, group, SP, application, directoryRole) have globally unique GUIDs. Junction records (`appRoleAssignment`, `oauth2PermissionGrant`) may not — use composite key `{parentId}_{id}` as the `Id` column value to guarantee uniqueness.

**ParentId population:** `ParentId` is null for top-level entities and set for junction/child records. Discovery populates it based on the API call context:

| Type | API Call | ParentId Source |
|------|----------|----------------|
| `user` | `GET /users` | null |
| `group` | `GET /groups` | null |
| `servicePrincipal` | `GET /servicePrincipals` | null |
| `application` | `GET /applications` | null |
| `directoryRole` | `GET /directoryRoles` | null |
| `appRoleAssignment` | `GET /servicePrincipals/{spId}/appRoleAssignments` | `{spId}` — the SP the call was made against |
| `oauth2PermissionGrant` | `GET /oauth2PermissionGrants` | `clientId` field from response — the SP that was granted consent |

`InvokeCIEMEntraPermissionCollection` sets `ParentId` at collection time — it already knows the SP ID (loop variable) or can read `clientId` from the response. No post-processing needed.

### `azure_resource_types` (new)

Auto-populated metadata about discovered resource types. **Not seeded** — populated entirely by the discovery engine after scanning.

### `azure_discovery_runs` (new)

Tracks discovery runs for freshness and debugging.

### `azure_resource_relationships` (new)

Runtime table storing discovered relationships between resources. Populated by a separate analysis step after collection (not during discovery).

Two categories:
- **Collected** — Explicit API calls during discovery (e.g., group membership, directory role members)
- **Inferred** — Analyzing stored `properties` after collection (e.g., disk → VM via `managed_by`, VM → NIC via properties)

### `azure_effective_access` (Phase 2)

Computed table: identity → resource access resolved through the full chain (role assignments, role definitions, permissions, scope hierarchy, group inheritance).

---

## Module Structure

### Architecture: Single Module, Organizational Folders

Everything ships as one PSGallery package (`Devolutions.CIEM`). The psm1 dot-sources all sub-folders into a single module scope. Sub-folders are **organizational**, not standalone modules — they have no psm1/psd1 of their own.

**Exception:** `PSUSQLite` is a real standalone module (`Import-Module -Global`). It has its own psm1/psd1 and independent session state.

### Folder Layout

```
psu-app/
├── Devolutions.CIEM.psd1/.psm1       # Root module
├── Classes/                           # Base classes (auth, provider, config)
├── Public/                            # Base public functions
├── Private/                           # Base private functions
├── Data/                              # Base schema.sql, ciem.db
└── modules/
    ├── PSUSQLite/                      # Real module (Import-Module -Global)
    │
    ├── Azure/                          # Provider: Azure
    │   ├── Infrastructure/             # ARM resource CRUD, API helpers
    │   │   ├── Classes/
    │   │   ├── Public/
    │   │   ├── Private/
    │   │   └── Data/                   # azure_schema.sql
    │   ├── Discovery/                  # NEW — Resource discovery engine
    │   │   ├── Classes/
    │   │   ├── Public/
    │   │   ├── Private/
    │   │   └── Data/                   # discovery_schema.sql
    │   └── Permissions/                # Being gutted — remnants move elsewhere
    │
    ├── AWS/                            # Provider: AWS
    │   ├── Infrastructure/
    │   └── Checks/
    │
    ├── Devolutions.CIEM.Checks/        # CSPM check engine + scan management
    │   ├── Classes/
    │   ├── Public/
    │   ├── Private/
    │   └── Data/
    │
    └── Devolutions.CIEM.PSU/           # PSU app pages + UI helpers
        ├── Pages/
        └── Public/
```

### Naming Convention

| Pattern | When to Use | Examples |
|---------|-------------|---------|
| `{Provider}/{Area}/` | Provider-specific functionality — data collection, CRUD for provider tables, provider API interaction | `Azure/Infrastructure`, `Azure/Discovery`, `AWS/Infrastructure` |
| `Devolutions.CIEM.{Feature}/` | Cross-provider or provider-agnostic features | `Devolutions.CIEM.Checks` (runs checks for any provider), `Devolutions.CIEM.PSU` (UI layer) |

### When to Create a New Folder

Create a new organizational folder when:

1. **New provider** — `AWS/Infrastructure`, `AWS/Discovery` (mirror Azure structure)
2. **New area within a provider** — Clear separation of concern that has its own classes, CRUD functions, and schema (e.g., `Azure/Discovery` is separate from `Azure/Infrastructure` because it has different tables, different classes, and a different lifecycle)
3. **New cross-provider feature** — Functionality that operates on data from any provider (e.g., a future `Devolutions.CIEM.Reports` that aggregates findings across Azure + AWS)

Do NOT create a new folder for:

- A few helper functions (put them in the closest existing folder's `Private/`)
- A single table (add to the closest existing folder's schema + CRUD)
- UI pages (add to `Devolutions.CIEM.PSU/Pages/`)

### Folder Internal Structure

Every organizational folder follows the same layout:

| Directory | Contents |
|-----------|----------|
| `Classes/` | PowerShell classes (one file per class) |
| `Public/` | Public functions (`Verb-CIEMNoun`) — exported by the root module |
| `Private/` | Private functions (`VerbCIEMNoun`, no dash) — internal to the module |
| `Data/` | SQL schema files, JSON data files (optional, only if the folder owns tables) |

### How Dot-Sourcing Works

The root `Devolutions.CIEM.psm1` discovers and dot-sources in order:

1. `Classes/*.ps1` (base)
2. `Private/*.ps1` (base)
3. `Public/*.ps1` (base)
4. For each organizational folder: `Classes/` → `Private/` → `Public/` (same order)
5. `Export-ModuleMember` for all public functions

Order matters: classes must load before functions that reference them. Base classes load before provider classes.

### Root Variables

The psm1 defines per-area root paths so functions can locate their own files:

```powershell
$script:ModuleRoot          # psu-app/ (base)
$script:AzureRoot           # modules/Azure/Infrastructure/
$script:AzureDiscoveryRoot  # modules/Azure/Discovery/ (NEW)
$script:AWSRoot             # modules/AWS/Infrastructure/
$script:ChecksRoot          # modules/Devolutions.CIEM.Checks/
$script:AzurePermissionsRoot # modules/Azure/Permissions/ (DELETED after migration — contents moved)
$script:IdentitiesRoot      # modules/Devolutions.CIEM.Identities/ (DELETED after migration)
$script:PSURoot             # modules/Devolutions.CIEM.PSU/
```

Functions use these instead of `$script:ModuleRoot` when accessing folder-specific files (Data/*.sql, Data/*.json).

---

## Azure/Discovery Module

New organizational folder under `modules/Azure/Discovery/`. Houses all resource discovery classes, CRUD functions, collection helpers, and schema.

### Classes

Every table has a corresponding PowerShell class. Properties match table columns (PascalCase).

```
CIEMAzureArmResource
├── Id                  [string]
├── Type                [string]
├── Name                [string]
├── Location            [string]
├── ResourceGroup       [string]
├── SubscriptionId      [string]
├── TenantId            [string]
├── Kind                [string]
├── Sku                 [string]    # JSON
├── Identity            [string]    # JSON
├── ManagedBy           [string]
├── Plan                [string]    # JSON
├── Zones               [string]    # JSON
├── Tags                [string]    # JSON
├── Properties          [string]    # JSON
└── CollectedAt         [string]

CIEMAzureEntraResource
├── Id                  [string]
├── Type                [string]
├── DisplayName         [string]
├── ParentId            [string]    # nullable — see ParentId Population below
├── Properties          [string]    # JSON
└── CollectedAt         [string]

CIEMAzureResourceType
├── Type                [string]
├── ApiSource           [string]
├── GraphTable          [string]
├── ResourceCount       [int]
├── DiscoveredAt        [string]
└── LastCollected       [string]

CIEMAzureDiscoveryRun
├── Id                  [int]
├── Scope               [string]
├── Status              [string]    # 'running', 'completed', 'partial', 'failed'
├── StartedAt           [string]
├── CompletedAt         [string]
├── ArmTypeCount        [int]
├── ArmRowCount         [int]
├── EntraTypeCount      [int]
├── EntraRowCount       [int]
├── WarningCount        [int]       # Non-fatal issues (403s, skipped endpoints)
└── ErrorMessage        [string]

CIEMAzureResourceRelationship
├── Id                  [int]
├── SourceId            [string]
├── SourceType          [string]
├── TargetId            [string]
├── TargetType          [string]
├── Relationship        [string]
└── CollectedAt         [string]

CIEMAzureEffectiveAccess          # Phase 2
├── Id                  [int]
├── IdentityId          [string]
├── IdentityType        [string]
├── IdentityDisplayName [string]
├── ResourceId          [string]
├── ResourceType        [string]
├── AccessType          [string]
├── RoleName            [string]
├── RoleAssignmentId    [string]
├── Scope               [string]
├── IsInherited         [bool]
├── EffectiveIdentityId [string]
├── Permissions         [string]    # JSON
└── ComputedAt          [string]

CIEMAzureResourceGraph            # Phase 2 — read-only projection (illustrative, final shape TBD)
├── Resources           [CIEMAzureArmResource[]]
├── EntraResources      [CIEMAzureEntraResource[]]
└── Relationships       [CIEMAzureResourceRelationship[]]

CIEMAzureDormantAccess            # Phase 2 — read-only projection (illustrative, final shape TBD)
├── IdentityId          [string]
├── IdentityType        [string]
├── IdentityDisplayName [string]
├── RoleName            [string]
├── Scope               [string]
├── IsInherited         [bool]
├── LastSignIn          [string]
└── DaysSinceSignIn     [int]

CIEMAzureOverprivilegedIdentity   # Phase 2 — read-only projection (illustrative, final shape TBD)
├── IdentityId          [string]
├── IdentityType        [string]
├── IdentityDisplayName [string]
├── RoleName            [string]
├── Scope               [string]
├── ScopeLevel          [string]   # 'ManagementGroup', 'Subscription', 'ResourceGroup', 'Resource'
├── IsInherited         [bool]
└── Recommendation      [string]

CIEMAzureRoleRightSizing          # Phase 2 — read-only projection (illustrative, final shape TBD)
├── IdentityId          [string]
├── IdentityType        [string]
├── IdentityDisplayName [string]
├── CurrentRoleName     [string]
├── Scope               [string]
├── AssignedActions      [string[]]
├── UsedActions          [string[]]
├── UnusedActions        [string[]]
└── ProposedRoleName    [string]
```

### Discovery Flow

```
Start-CIEMAzureDiscovery [-Scope All|ARM|Entra]
    │
    ├─ New-CIEMAzureDiscoveryRun -Scope $Scope -Status 'running'
    │
    ├─ PHASE 1: Collect to memory (API calls, no DB writes)
    │   │
    │   ├─ ARM Collection (if Scope = All or ARM):
    │   │   ├─ InvokeCIEMResourceGraphQuery -Query 'Resources'
    │   │   ├─ InvokeCIEMResourceGraphQuery -Query 'ResourceContainers'
    │   │   ├─ InvokeCIEMResourceGraphQuery -Query 'AuthorizationResources'
    │   │   └─ GetCIEMBuiltInRoleDefinitions
    │   │   → all results accumulated in $armResources (memory)
    │   │
    │   └─ Entra Collection (if Scope = All or Entra):
    │       ├─ InvokeCIEMEntraEntityCollection
    │       │   → /users, /groups, /servicePrincipals, /applications, /directoryRoles
    │       ├─ InvokeCIEMEntraPermissionCollection
    │       │   → /servicePrincipals/{id}/appRoleAssignments, /oauth2PermissionGrants
    │       └─ InvokeCIEMEntraRelationshipCollection
    │           → /groups/{id}/members, /groups/{id}/owners, /directoryRoles/{id}/members, /users/{id}/transitiveMemberOf
    │       → all results accumulated in $entraResources, $entraPermissions, $relationships (memory)
    │
    ├─ PHASE 2: Atomic DB write (single transaction)
    │   ├─ BEGIN TRANSACTION
    │   ├─ Remove-CIEMAzureArmResource -All
    │   ├─ Save-CIEMAzureArmResource -InputObject $armResources
    │   ├─ Remove-CIEMAzureEntraResource -All
    │   ├─ Save-CIEMAzureEntraResource -InputObject $entraResources
    │   ├─ Save-CIEMAzureEntraResource -InputObject $entraPermissions
    │   ├─ Remove-CIEMAzureResourceRelationship -All
    │   ├─ Save-CIEMAzureResourceRelationship -InputObject $relationships
    │   ├─ Auto-populate azure_resource_types
    │   └─ COMMIT
    │
    └─ Update-CIEMAzureDiscoveryRun -Status 'completed|partial' -ArmRowCount ... -EntraRowCount ...
```

### Implementation Constraints

**Atomic writes:** All DB writes happen in Phase 2 inside a single `BEGIN TRANSACTION ... COMMIT`. If any API call fails in Phase 1, old data remains intact. If the transaction fails, it rolls back to the previous state.

**Transaction wrapping:** All bulk insert functions (`Save-*`) must accept an existing connection/transaction parameter or be called within an `Invoke-CIEMQuery` transaction block. Without explicit transactions, SQLite does an implicit commit per INSERT — thousands of rows will take minutes instead of seconds.

**Rate limiting (Phase 1 requirement):** Graph API throttles at ~20 requests/second. Per-entity calls (929 SPs x `/appRoleAssignments`, groups x `/members`, etc.) require:
- Sequential calls with 429 retry + `Retry-After` header support in `Invoke-AzureApi`
- Configurable delay between calls (default: 50ms)
- `$batch` endpoint evaluation for per-entity calls (up to 20 requests per batch)

**Partial success:** Discovery runs that encounter 403 or throttling on some endpoints but succeed on others are marked `partial` (not `completed` or `failed`). `CIEMAzureDiscoveryRun.ErrorMessage` captures what was skipped and why. `WarningCount` tracks number of non-fatal issues.

### Functions

All CRUD functions follow the convention: New (INSERT) / Get (SELECT) / Update (partial) / Save (upsert) / Remove (DELETE). Every Get returns `[ClassName[]]`. Every write function has `ByProperties` and `InputObject` parameter sets.

**Public — Discovery entry point:**

```
Start-CIEMAzureDiscovery [-Scope <'All'|'ARM'|'Entra'>]
```

**Public — azure_arm_resources → [CIEMAzureArmResource]:**

```
New-CIEMAzureArmResource    [-Id] [-Type] [-Name] [-Location] [-ResourceGroup] [-SubscriptionId] [-TenantId] [-Kind] [-Sku] [-Identity] [-ManagedBy] [-Plan] [-Zones] [-Tags] [-Properties] [-CollectedAt]
                             [-InputObject <CIEMAzureArmResource[]>]
Get-CIEMAzureArmResource    [-Id] [-Type] [-Name] [-SubscriptionId] [-ResourceGroup]
Update-CIEMAzureArmResource [-Id] [-Properties] [-Tags] [-CollectedAt] [-PassThru]
                             [-InputObject <CIEMAzureArmResource[]>]
Save-CIEMAzureArmResource   [-InputObject <CIEMAzureArmResource[]>]
Remove-CIEMAzureArmResource [-Id] [-Type] [-All] [-InputObject <CIEMAzureArmResource[]>]
```

**Public — azure_entra_resources → [CIEMAzureEntraResource]:**

```
New-CIEMAzureEntraResource    [-Id] [-Type] [-DisplayName] [-ParentId] [-Properties] [-CollectedAt]
                               [-InputObject <CIEMAzureEntraResource[]>]
Get-CIEMAzureEntraResource    [-Id] [-Type] [-DisplayName] [-ParentId]
Update-CIEMAzureEntraResource [-Id] [-Properties] [-DisplayName] [-ParentId] [-CollectedAt] [-PassThru]
                               [-InputObject <CIEMAzureEntraResource[]>]
Save-CIEMAzureEntraResource   [-InputObject <CIEMAzureEntraResource[]>]
Remove-CIEMAzureEntraResource [-Id] [-Type] [-All] [-InputObject <CIEMAzureEntraResource[]>]
```

**Public — azure_resource_types → [CIEMAzureResourceType]:**

```
Get-CIEMAzureResourceType    [-Type] [-ApiSource]
```

*New/Update/Save/Remove are private — resource types are auto-populated by the discovery engine, not manually managed.*

**Public — azure_discovery_runs → [CIEMAzureDiscoveryRun]:**

```
New-CIEMAzureDiscoveryRun    [-Scope] [-Status] [-StartedAt]
                              [-InputObject <CIEMAzureDiscoveryRun[]>]
Get-CIEMAzureDiscoveryRun    [-Id] [-Status] [-Last <int>]
Update-CIEMAzureDiscoveryRun [-Id] [-Status] [-CompletedAt] [-ArmTypeCount] [-ArmRowCount] [-EntraTypeCount] [-EntraRowCount] [-WarningCount] [-ErrorMessage] [-PassThru]
                              [-InputObject <CIEMAzureDiscoveryRun[]>]
Save-CIEMAzureDiscoveryRun   [-InputObject <CIEMAzureDiscoveryRun[]>]
Remove-CIEMAzureDiscoveryRun [-Id] [-InputObject <CIEMAzureDiscoveryRun[]>]
```

**Public — azure_resource_relationships → [CIEMAzureResourceRelationship]:**

```
New-CIEMAzureResourceRelationship    [-SourceId] [-SourceType] [-TargetId] [-TargetType] [-Relationship] [-CollectedAt]
                                      [-InputObject <CIEMAzureResourceRelationship[]>]
Get-CIEMAzureResourceRelationship    [-SourceId] [-TargetId] [-Relationship] [-SourceType] [-TargetType]
Update-CIEMAzureResourceRelationship [-Id] [-Relationship] [-CollectedAt] [-PassThru]
                                      [-InputObject <CIEMAzureResourceRelationship[]>]
Save-CIEMAzureResourceRelationship   [-InputObject <CIEMAzureResourceRelationship[]>]
Remove-CIEMAzureResourceRelationship [-SourceId] [-TargetId] [-Relationship] [-All] [-InputObject <CIEMAzureResourceRelationship[]>]
```

**Public — azure_effective_access → [CIEMAzureEffectiveAccess] (Phase 2):**

```
New-CIEMAzureEffectiveAccess    [-IdentityId] [-IdentityType] [-IdentityDisplayName] [-ResourceId] [-ResourceType] [-AccessType] [-RoleName] [-RoleAssignmentId] [-Scope] [-IsInherited] [-EffectiveIdentityId] [-Permissions] [-ComputedAt]
                                 [-InputObject <CIEMAzureEffectiveAccess[]>]
Get-CIEMAzureEffectiveAccess    [-IdentityId] [-ResourceId] [-AccessType] [-IdentityType] [-ResourceType]
Update-CIEMAzureEffectiveAccess [-Id] [-Permissions] [-ComputedAt] [-PassThru]
                                 [-InputObject <CIEMAzureEffectiveAccess[]>]
Save-CIEMAzureEffectiveAccess   [-InputObject <CIEMAzureEffectiveAccess[]>]
Remove-CIEMAzureEffectiveAccess [-IdentityId] [-ResourceId] [-All] [-InputObject <CIEMAzureEffectiveAccess[]>]
```

**Private — ARM collection:**

```
InvokeCIEMResourceGraphQuery [-Query <string>]
    → POST to Microsoft.ResourceGraph/resources. Custom pagination — Resource Graph returns
      $skipToken in response body (not nextLink URL). Pass $skipToken back in next POST body.
      Cannot use Invoke-AzureApi's built-in nextLink pagination.
    → Returns [CIEMAzureArmResource[]]

GetCIEMBuiltInRoleDefinitions
    → ARM API call, returns [CIEMAzureArmResource[]]
```

**Private — Entra collection:**

```
InvokeCIEMEntraEntityCollection
    → Collects users, groups, SPs, apps, directoryRoles. Returns [CIEMAzureEntraResource[]]

InvokeCIEMEntraPermissionCollection
    → Collects appRoleAssignments per SP + oauth2PermissionGrants. Returns [CIEMAzureEntraResource[]]

InvokeCIEMEntraRelationshipCollection
    → Collects group members, group owners, directory role members, transitive membership. Returns [CIEMAzureResourceRelationship[]]
```

**Private — azure_resource_types CRUD (auto-populated by discovery):**

```
NewCIEMAzureResourceType     [-Type] [-ApiSource] [-GraphTable] [-ResourceCount] [-DiscoveredAt]
                              [-InputObject <CIEMAzureResourceType[]>]
UpdateCIEMAzureResourceType  [-Type] [-ResourceCount] [-LastCollected] [-PassThru]
                              [-InputObject <CIEMAzureResourceType[]>]
SaveCIEMAzureResourceType    [-InputObject <CIEMAzureResourceType[]>]
RemoveCIEMAzureResourceType  [-Type] [-All] [-InputObject <CIEMAzureResourceType[]>]
```

**Phase 1 total: 21 public (20 CRUD + 1 Get resource types) + 1 discovery entry point + 9 private = 31 functions.**
*Phase 2 adds: 5 effective access CRUD (public) + 2 entry points + 4 query functions + 3 analysis functions + 10 private resolvers = 24 functions.*

---

## Relationship Mapping (Phase 2)

After discovery populates `azure_arm_resources` and `azure_entra_resources`, relationships are resolved in two ways.

### Collected Relationships (from API, stored during discovery)

| Relationship | Source | Stored As |
|-------------|--------|-----------|
| Group → Member | `GET /groups/{id}/members` | `member_of` |
| Group → Owner | `GET /groups/{id}/owners` | `owner_of` |
| Directory Role → Member | `GET /directoryRoles/{id}/members` | `has_role_member` |
| User → Transitive Groups | `GET /users/{id}/transitiveMemberOf` | `transitive_member_of` |

### Inferred Relationships (from properties, computed post-discovery)

| Relationship | How to Discover |
|-------------|----------------|
| Disk → VM | `managed_by` column |
| VM → NIC | `properties.networkProfile.networkInterfaces` |
| VM → OS Disk | `properties.storageProfile.osDisk.managedDisk.id` |
| VM → Managed Identity SP | `identity.principalId` cross-ref to entra resources |
| NSG → NIC | `properties.networkInterfaces` |
| Public IP → NIC | `properties.ipConfiguration.id` |
| Role Assignment → Principal | `properties.principalId` cross-ref to entra resources |
| Role Assignment → Role Def | `properties.roleDefinitionId` cross-ref to arm resources |
| App → Service Principal | `properties.appId` matching between `application` and `servicePrincipal` |

### Effective Access Resolution (Phase 2)

The CIEM analysis layer computes effective identity → resource access by resolving:

```
Identity → (direct or via group) → Role Assignment → Role Definition → Permissions → Resource (scope)
```

1. Find all role assignments where `principalId` = identity (direct)
2. Find all role assignments where `principalId` = a group the identity is a transitive member of (inherited)
3. Resolve `roleDefinitionId` → role definition → `permissions.actions[]`
4. Evaluate scope hierarchy (management group → subscription → resource group → resource)
5. Apply `notActions` / `notDataActions` deny rules
6. Include Entra-level permissions (app role assignments, OAuth2 permission grants)

### Functions

**Public — Relationship resolution entry points:**

```
Invoke-CIEMAzureRelationshipMapping [-Scope <'All'|'Inferred'|'Collected'>]
    → Orchestrator. Clears + rebuilds azure_resource_relationships.
    → 'Collected' = re-runs API relationship collection (group members, role members, etc.)
    → 'Inferred' = analyzes stored properties to derive resource-to-resource links
    → 'All' = both (default)

Invoke-CIEMAzureEffectiveAccessComputation [-IdentityId <string>] [-IdentityType <string>]
    → Resolves the full identity → role assignment → role definition → permissions → scope chain.
    → No parameters = compute for ALL identities. With filters = compute for subset.
    → Clears + rebuilds azure_effective_access (or filtered subset).
```

**Public — Relationship queries:**

```
Get-CIEMAzureIdentityAccess [-IdentityId <string>] [-IdentityType <string>] [-IncludeInherited]
    → Returns all resources an identity can access (direct + via group). Reads from azure_effective_access.
    → [CIEMAzureEffectiveAccess[]]

Get-CIEMAzureResourceAccessors [-ResourceId <string>] [-ResourceType <string>] [-AccessType <string>]
    → Returns all identities that can access a resource. Inverse of Get-CIEMAzureIdentityAccess.
    → [CIEMAzureEffectiveAccess[]]

Get-CIEMAzureIdentityRelationship [-IdentityId <string>] [-Relationship <string>] [-Direction <'Source'|'Target'|'Both'>]
    → Returns relationships for a specific identity (group memberships, role assignments, etc.)
    → [CIEMAzureResourceRelationship[]]

Get-CIEMAzureResourceRelationshipGraph [-ResourceId <string>] [-Depth <int>]
    → Walks the relationship graph from a starting resource up to N hops. Default depth = 2.
    → [CIEMAzureResourceGraph]
```

**Public — CIEM analysis (consume effective access data):**

```
Get-CIEMAzureDormantAccess [-DaysSinceLastSignIn <int>] [-IdentityType <string>]
    → Identities with privileged roles but no sign-in within threshold (default 90 days).
    → Cross-refs azure_effective_access with signInActivity in azure_entra_resources.
    → [CIEMAzureDormantAccess[]]

Get-CIEMAzureOverprivilegedIdentity [-IdentityId <string>] [-IdentityType <string>]
    → Identities with broad roles (Owner, Contributor, User Access Admin) at high scope.
    → [CIEMAzureOverprivilegedIdentity[]]

Get-CIEMAzureRoleRightSizing [-IdentityId <string>] [-RoleName <string>]
    → Compares assigned permissions vs actually used (requires activity logs — Phase 2+).
    → [CIEMAzureRoleRightSizing[]]
```

**Private — Inferred relationship resolvers (one per pattern):**

```
ResolveCIEMArmManagedByRelationship
    → Scans managed_by column for disk → VM, etc.

ResolveCIEMArmNetworkRelationship
    → VM → NIC, NSG → NIC, Public IP → NIC from properties

ResolveCIEMArmStorageRelationship
    → VM → OS Disk, VM → Data Disks from properties

ResolveCIEMArmIdentityRelationship
    → VM/App Service/etc. → Managed Identity SP from identity column

ResolveCIEMRoleAssignmentRelationship
    → Role Assignment → Principal (cross-ref to entra) + Role Assignment → Role Definition

ResolveCIEMEntraAppRelationship
    → Application → Service Principal via appId matching
```

**Private — Effective access computation helpers:**

```
ResolveCIEMAzureRbacAccess [-IdentityId <string>] [-GroupIds <string[]>]
    → Finds role assignments (direct + inherited via groups), resolves role definitions, evaluates scope

ResolveCIEMEntraAppRoleAccess [-IdentityId <string>]
    → Resolves app role assignments (application permissions on Graph, etc.)

ResolveCIEMEntraOAuth2Access [-IdentityId <string>]
    → Resolves delegated permission grants

ResolveCIEMAzureRolePermissions [-RoleDefinitionId <string>]
    → Expands role definition into actions/dataActions, applies notActions/notDataActions
```

---

## Entra Graph API Endpoints

Graph API does not support auto-discovery — the following is a known, stable list. These endpoints are now registered as scoped rows in `azure_provider_apis` (where `service IS NOT NULL`), with their required permissions stored as JSON. `Get-CIEMRequiredPermission` aggregates permissions from both checks and these endpoint rows.

**Entity collections** (→ `azure_entra_resources`):

| Entity Type | Endpoint | Notes |
|-------------|----------|-------|
| `user` | `/users` | `$select` for common fields + `signInActivity` (requires Premium P1) |
| `group` | `/groups` | Security and M365 groups |
| `servicePrincipal` | `/servicePrincipals` | Apps + managed identities. `signInActivity` requires `/beta/servicePrincipals` (not v1.0). |
| `application` | `/applications` | App registrations |
| `directoryRole` | `/directoryRoles` | Only activated roles returned |

**Permission collections** (→ `azure_entra_resources` with type = `appRoleAssignment` / `oauth2PermissionGrant`):

| Entity Type | Endpoint | Notes |
|-------------|----------|-------|
| `appRoleAssignment` | `/servicePrincipals/{id}/appRoleAssignments` | Loop each SP |
| `oauth2PermissionGrant` | `/oauth2PermissionGrants` | Single paginated call |

**Relationship collections** (→ `azure_resource_relationships`):

| Relationship | Endpoint | Notes |
|-------------|----------|-------|
| Group → Member | `/groups/{id}/members` | Loop each group |
| Group → Owner | `/groups/{id}/owners` | Loop each group |
| Directory Role → Member | `/directoryRoles/{id}/members` | Loop each activated role |
| User → Transitive Groups | `/users/{id}/transitiveMemberOf` | Resolves nested group membership in one call |

**Premium license gating:** `signInActivity` requires Azure AD Premium P1. Discovery must handle 403 gracefully — collect what it can, skip what it can't, log what was skipped.

---

## Known Gaps / Future Considerations

| Gap | Impact | When |
|-----|--------|------|
| **PIM eligible assignments** | Invisible users with eligible privileged roles | Phase 2+ |
| **Conditional Access Policies** | Role assignment exists but access blocked by policy | Phase 3 |
| **Service principal credentials** | Key/certificate expiry risk assessment | Phase 2 |
| **Data actions vs control plane** | `actions` vs `dataActions` not distinguished in effective access | Phase 2 |
| **Cross-tenant / B2B** | Guest users with role assignments; complex scope resolution | Phase 3 |
| ~~**Rate limiting (Graph API)**~~ | ~~929 SPs × `/appRoleAssignments` = 929 calls~~ | **Moved to Phase 1 Implementation Constraints** |

---

## Migration Path

### Tables to Drop

| Table | Reason |
|-------|--------|
| `azure_service_data` | Replaced by `azure_arm_resources` + `azure_entra_resources` |
| `azure_resources` | Replaced by `azure_arm_resources` + `azure_entra_resources` |
| `azure_resource_relationships` (old) | Replaced by new `azure_resource_relationships` with different schema |
| `azure_resource_properties` | Eliminated — properties stored as JSON on resource row |
| `azure_resource_types` (old) | Incompatible schema — replaced by new auto-populated `azure_resource_types` |
| `provider_auth_methods` | Auth config lives in PSU Cache |
| `identity_types` | Implicit in `azure_entra_resources.type` |
| `resource_types` (generic) | Replaced by `azure_resource_types` |
| `permission_relationships` | Rebuild later if needed |
| `identity_resource_access` | Rebuild later if needed |

### Tables to Keep

| Table | Reason |
|-------|--------|
| `providers` | Shared provider registry (dropping `is_default`, update `CIEMProvider` class) |
| `azure_provider_apis` | Evolved — base rows (service IS NULL) for URL resolution; scoped endpoint rows (service IS NOT NULL) with `service`, `path`, `permissions`, `disabled` columns for discovery endpoint registry |
| `checks` | CSPM check metadata — separate subsystem |
| `scan_runs` | CSPM scan history — separate subsystem |
| `scan_results` | CSPM findings — separate subsystem |

### Code to Keep (with modifications)

| Component | Modification |
|-----------|-------------|
| `Invoke-AzureApi` | Add 429 retry: parse `Retry-After` header, exponential backoff (1s/2s/4s), max 5 retries, applies to all callers (not just discovery). Currently 429 falls into default switch arm and emits a warning — needs proper retry loop. |

### Code to Delete

| Component | Reason |
|-----------|--------|
| `Devolutions.CIEM.Identities` module (entire folder) | Replaced by `azure_resource_relationships` + `azure_effective_access` + relationship query functions |
| `Get-CIEMAzureEntraData` / `Save-CIEMAzureEntraData` | Replaced by discovery engine |
| `Get-CIEMAzureIAMData` / `Save-CIEMAzureIAMData` | Replaced by discovery engine |
| `Save/Get/Remove-CIEMAzureServiceData` | Replaced by generic CRUD |
| `CIEMAzureServiceData` class | Replaced by generic resource storage |
| Per-service collection functions | `Save-CIEMAzure{Vm,Policy,Network,Monitor,Defender}Data`, `Save/Get-CIEMCollectedData` — replaced by discovery engine |
| `Azure/Infrastructure/Public/` CRUD for old tables | `New/Get/Update/Save/Remove-CIEMAzureResource`, `*-CIEMAzureResourceRelationship` (old), `*-CIEMAzureResourceProperty` — replaced by new CRUD |
| `Azure/Permissions` folder (if empty after migration) | Fold remaining functions into `Azure/Discovery`; move `Test-EntraAuthorizationPolicyBooleanSetting` to `Azure/Infrastructure` (used by CSPM checks, not discovery) |

### New Dependencies

*None.* Resource Graph queries use the REST API (`POST .../providers/Microsoft.ResourceGraph/resources`) via existing `Invoke-AzureApi -Api ARM`. No Azure CLI dependency.

### Schema Migration Strategy

`New-CIEMDatabase` handles migration:

1. Detect old schema (presence of `azure_service_data`, `azure_resources`, `identity_types`, etc.)
2. Drop old tables listed in "Tables to Drop" (including `azure_resources`, `azure_resource_properties`, old `azure_resource_types`, old `azure_resource_relationships`)
3. Apply new schema (`azure_arm_resources`, `azure_entra_resources`, `azure_resource_types`, `azure_discovery_runs`)
4. Drop `is_default` column from `providers` (SQLite requires table rebuild: create new → copy data → drop old → rename)
5. Retain `checks`, `scan_runs`, `scan_results` untouched
6. Evolve `azure_provider_apis`: `ALTER TABLE ADD COLUMN` for `service`, `path`, `permissions`, `disabled`; `INSERT OR IGNORE` scoped endpoint rows

For existing installations, discovery data is ephemeral (re-collected on next scan), so dropping and recreating is safe. No data migration needed — just schema migration.

**psm1 update:** The root psm1 currently applies `schema.sql` + `azure_schema.sql`. After migration, it must also apply `discovery_schema.sql` from `Azure/Discovery/Data/`. The trimmed `azure_schema.sql` retains only `azure_provider_apis` + seed data.

### Phased Rollout

**Phase 1 (This work):**
- New schema + schema migration in `New-CIEMDatabase`
- CRUD functions for `azure_arm_resources`, `azure_entra_resources`, `azure_discovery_runs`
- `Start-CIEMAzureDiscovery` with full ARM (Resource Graph REST API + built-in roles) and Entra (entities + permissions) collection
- Rate limiting / 429 retry with `Retry-After` in `Invoke-AzureApi`
- Atomic collect-then-write with transaction wrapping
- Delete old collection code + `Devolutions.CIEM.Identities` module
- Drop `CIEMProvider.IsDefault`, clean up `Azure/Permissions` folder

**Phase 2:** Relationship mapping + effective access. Collected + inferred relationships. Effective access computed table. Identity → permission → resource chain with group inheritance and scope hierarchy. PIM eligible assignments. SP credential risk.

**Phase 3:** AWS provider support. Conditional Access Policies. Cross-tenant B2B resolution.

---

## Tenant Discovery Results (Reference)

From actual discovery against the development tenant (2026-03-10):

### ARM Resource Types (30 types)

| Type | Count |
|------|-------|
| `microsoft.alertsmanagement/smartdetectoralertrules` | 4 |
| `microsoft.web/serverfarms` | 3 |
| `microsoft.storage/storageaccounts` | 3 |
| `microsoft.web/sites` | 3 |
| `microsoft.insights/components` | 3 |
| `microsoft.operationalinsights/workspaces` | 3 |
| `microsoft.sql/servers/databases` | 2 |
| `microsoft.web/staticsites` | 2 |
| `microsoft.logic/workflows` | 2 |
| `microsoft.network/networksecuritygroups` | 2 |
| `microsoft.keyvault/vaults` | 2 |
| `microsoft.compute/virtualmachines/extensions` | 2 |
| `microsoft.network/virtualnetworks` | 2 |
| `microsoft.powerplatform/accounts` | 2 |
| `microsoft.sql/servers` | 1 |
| `microsoft.managedidentity/userassignedidentities` | 1 |
| `microsoft.insights/actiongroups` | 1 |
| `microsoft.web/customapis` | 1 |
| `microsoft.compute/virtualmachines` | 1 |
| `microsoft.migrate/movecollections` | 1 |
| `microsoft.web/certificates` | 1 |
| `microsoft.network/networkinterfaces` | 1 |
| `microsoft.web/sites/slots` | 1 |
| `microsoft.cognitiveservices/accounts` | 1 |
| `microsoft.portal/dashboards` | 1 |
| `microsoft.network/publicipaddresses` | 1 |
| `microsoft.devtestlab/schedules` | 1 |
| `microsoft.sqlvirtualmachine/sqlvirtualmachines` | 1 |
| `microsoft.network/networkwatchers` | 1 |
| `microsoft.compute/disks` | 1 |

### Resource Containers (2 types)

| Type | Notes |
|------|-------|
| `microsoft.resources/subscriptions` | Top-level subscription |
| `microsoft.resources/subscriptions/resourcegroups` | Resource groups |

### Authorization Resources (3 types)

| Type | Count |
|------|-------|
| `microsoft.authorization/roleassignments` | 48 |
| `microsoft.authorization/classicadministrators` | 7 |
| `microsoft.authorization/roledefinitions` | 1 (custom only) |

### Entra Resources (Graph API)

| Type | Count |
|------|-------|
| Users | 132 |
| Groups | 24 |
| Service Principals | 929 |
| Applications | 286 |
