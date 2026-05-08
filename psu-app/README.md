# Devolutions.CIEM

Cloud Infrastructure Entitlement Management (CIEM) for PowerShell Universal. Detects dormant permissions, right-sizes roles, maps identity-to-resource relationships, and surfaces attack paths across Azure (and AWS, in progress).

The module ships as a self-contained PSU deployable: it registers its own apps, scripts, schedules, and database schema when imported.

## Requirements

| Requirement | Version |
|-------------|---------|
| PowerShell  | 7.4+ |
| PowerShell Universal | 5.5.4+ (tested on the `ironmansoftware/universal:5.5.4-azure` container image and on PSU 2026.1.x macOS ARM64 builds) |
| Azure CLI (Azure deployments only) | 2.60+ |

## Install

### Option 1: Direct from PSU UI

1. Open PSU > **Platform > Modules**.
2. Click **Add Module**, choose `Devolutions.CIEM`, and accept the latest version.
3. PSU downloads the package from PowerShell Gallery and runs the bundled `.universal/scripts.ps1` to register CIEM scripts and schedules.

### Option 2: PowerShell Gallery + Sync

```powershell
Install-Module -Name Devolutions.CIEM -Repository PSGallery -Scope AllUsers
Sync-PSUConfiguration                       # re-runs .universal/*.ps1 to register CIEM resources
```

After import, navigate to `/ciem` (or `/<app-base>/ciem`) and the dashboard renders.

## Azure Managed Identity Setup

When PSU runs on Azure App Service, configure a **system-assigned managed identity** so the CIEM module can authenticate to Azure and Microsoft Graph without storing a client secret.

### Required permissions

| Scope | Permission | Why |
|-------|-----------|-----|
| Each target subscription | `Reader` (Azure RBAC) | Covers every ARM read CIEM checks need: role definitions, diagnostic settings, Key Vault metadata, storage account configuration, network resources |
| Microsoft Graph (application) | `Directory.Read.All` | Read directory objects, including users/groups/service principals |
| Microsoft Graph (application) | `Policy.Read.All` | Read conditional access and authentication policies |
| Microsoft Graph (application) | `RoleManagement.Read.Directory` | Read Entra ID role assignments and definitions |
| Microsoft Graph (application) | `User.Read.All` | Read user profile data referenced by identity checks |
| Microsoft Graph (application) | `UserAuthenticationMethod.Read.All` | Inspect MFA / passwordless registration state |

Reader is intentionally read-only. CIEM does not modify Azure resources; remediation actions surface as guidance, not direct changes.

### Provisioning steps (Azure CLI)

Run from a shell signed in (`az login`) with rights to assign Azure RBAC roles and grant Microsoft Graph application permissions (Privileged Role Administrator or Global Administrator).

```bash
RG=devolutions-ciem-rg
SITE=devolutions-ciem-psu
SUB=$(az account show --query id -o tsv)

# 1. Enable system-assigned managed identity on the PSU App Service
PRINCIPAL_ID=$(az webapp identity assign \
  --name "$SITE" --resource-group "$RG" \
  --query principalId -o tsv)

# 2. Grant Reader on each target subscription (repeat per sub if multi-tenant)
az role assignment create \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role Reader \
  --scope "/subscriptions/$SUB"

# 3. Grant Microsoft Graph application permissions
GRAPH_SP_ID=$(az rest --method get \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals?\$filter=appId eq '00000003-0000-0000-c000-000000000000'" \
  --query 'value[0].id' -o tsv)

for PERM in Directory.Read.All Policy.Read.All RoleManagement.Read.Directory User.Read.All UserAuthenticationMethod.Read.All; do
  APP_ROLE_ID=$(az rest --method get \
    --url "https://graph.microsoft.com/v1.0/servicePrincipals/$GRAPH_SP_ID" \
    --query "appRoles[?value=='$PERM'].id | [0]" -o tsv)

  az rest --method post \
    --url "https://graph.microsoft.com/v1.0/servicePrincipals/$PRINCIPAL_ID/appRoleAssignments" \
    --headers 'Content-Type=application/json' \
    --body "{\"principalId\":\"$PRINCIPAL_ID\",\"resourceId\":\"$GRAPH_SP_ID\",\"appRoleId\":\"$APP_ROLE_ID\"}"
done

# 4. Restart the App Service so MSI env vars (IDENTITY_ENDPOINT / IDENTITY_HEADER) are injected
az webapp restart --name "$SITE" --resource-group "$RG"
```

### Provisioning steps (Devolutions.CIEM.Admin helper)

The `Devolutions.CIEM.Admin` companion module bundles `Initialize-CIEMPSUManagedIdentity`, which performs all of the above in one call:

```powershell
Import-Module ./Devolutions.CIEM.Admin
Initialize-CIEMPSUManagedIdentity `
  -ResourceGroup devolutions-ciem-rg `
  -SiteName      devolutions-ciem-psu `
  -SubscriptionId (Get-AzContext).Subscription.Id `
  -Restart
```

Pass `-GraphPermission @()` to skip Graph permission setup if you only need ARM (Azure resource) coverage.

### Configure CIEM to use the managed identity

After the identity is provisioned and the app restarts, open the CIEM **Configuration** page in PSU and create an Azure authentication profile with:

- **Auth Type**: `ManagedIdentity`
- **Subscription**: any subscription the identity has Reader on

CIEM uses `DefaultAzureCredential` under the hood; no secrets are stored.

## Local / Self-Hosted PSU

For PSU instances not running on Azure App Service, use one of:

- **Service Principal + secret** — create an Entra app registration, assign the same Reader / Graph permissions to its service principal, and configure an `Azure CLI Profile` in CIEM Configuration with the client ID + secret.
- **Certificate auth** — same app registration, upload a PFX to the PSU vault, and select `Certificate` as the auth type.
- **Azure CLI** — for ad-hoc evaluation only; relies on the developer's `az login` session.

The required permissions are identical to the managed identity table above.

## Post-Install Verification

```powershell
# Confirm CIEM scripts are registered
Get-PSUScript | Where-Object Module -eq 'Devolutions.CIEM'

# Should list: Start-CIEMAzureDiscovery, New-CIEMScanRun, Invoke-CIEMAttackPathRemediation
```

In the UI:

1. Visit `/ciem` and confirm the dashboard renders.
2. Open **Environment**, click **Start Discovery** — the run should report progress without an "Unknown script" toast.
3. Open **Scan**, select an Azure profile, click **Start Scan** — checks should execute against the discovered inventory.

## Uninstall

```powershell
Import-Module ./Devolutions.CIEM.Admin
Remove-CIEMPSUModule       # removes CIEM apps, scripts, schedules, and the module itself
```

Or manually: remove the `Devolutions CIEM` PSU app, delete the three CIEM-registered scripts, then `Uninstall-Module Devolutions.CIEM`.

## Project

- Source: https://github.com/adbertram/Devolutions-CIEM
- Issues / discussion: see the GitHub repository
