---
description: Check management functions reference
paths: ["psu-app/modules/Devolutions.CIEM.Checks/**"]
---

# Check Management Functions

Development-only functions for managing CIEM checks, syncing Prowler checks, and provisioning Azure infrastructure. These are exported from the Checks module (`psu-app/modules/Devolutions.CIEM.Checks/`) and available after importing `Devolutions.CIEM`.

## Prowler Sync & Check Management

| Function | Purpose |
|----------|---------|
| `Sync-ProwlerCheck` | Sync Prowler checks from GitHub (sparse checkout) |
| `Get-ProwlerCheck` | List/filter Prowler checks from the upstream repo |
| `Enable-CIEMCheck` | Enable a check (set disabled flag to false) |
| `Disable-CIEMCheck` | Disable a check (set disabled flag to true) |
| `Compare-ProwlerCheck` | Diff upstream Prowler checks vs local CIEM checks |
| `Convert-ProwlerCheck` | Convert a Prowler check directory to CIEM format |

## Azure Infrastructure Provisioning

| Function | Purpose |
|----------|---------|
| `New-CIEMAzureManagedIdentity` | Configure Azure managed identity with CIEM permissions |
| `New-PSUAzureServicePrincipal` | Create Azure service principal for PSU |

## When to Use

- **Adding/removing/syncing checks:** `Sync-ProwlerCheck`, `Enable-CIEMCheck`, `Disable-CIEMCheck`
- **Querying check metadata:** `Get-CIEMCheck -Provider Azure -Service Entra`
- **Checking required permissions:** `Get-CIEMRequiredPermission -Service KeyVault`
- **Provisioning Azure resources:** `New-CIEMAzureManagedIdentity`, `New-PSUAzureServicePrincipal`
