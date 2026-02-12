# Prowler Check Anatomy

Structure and patterns of Prowler Python security checks.

## Table of Contents
- [Directory Structure](#directory-structure)
- [Metadata File](#metadata-file)
- [Check Implementation](#check-implementation)
- [Service Client Pattern](#service-client-pattern)
- [Common Check Patterns](#common-check-patterns)

---

## Directory Structure

Each Prowler check lives in its own directory:

```
prowler/providers/{provider}/services/{service}/{check_id}/
├── __init__.py                    # Package marker (empty)
├── {check_id}.metadata.json       # Check metadata
└── {check_id}.py                  # Check implementation
```

Example:
```
prowler/providers/azure/services/entra/entra_security_defaults_enabled/
├── __init__.py
├── entra_security_defaults_enabled.metadata.json
└── entra_security_defaults_enabled.py
```

## Metadata File

`{check_id}.metadata.json` contains all check metadata:

```json
{
  "Provider": "azure",
  "CheckID": "entra_security_defaults_enabled",
  "CheckTitle": "Ensure Security Defaults is enabled on Microsoft Entra ID",
  "CheckType": [],
  "ServiceName": "entra",
  "SubServiceName": "",
  "Severity": "high",
  "ResourceType": "#microsoft.graph.identitySecurityDefaultsEnforcementPolicy",
  "Description": "Security defaults in Microsoft Entra ID...",
  "Risk": "Security defaults provide secure default settings...",
  "RelatedUrl": "https://learn.microsoft.com/en-us/entra/fundamentals/security-defaults",
  "Remediation": {
    "Code": { "CLI": "", "NativeIaC": "", "Other": "", "Terraform": "" },
    "Recommendation": {
      "Text": "1. From Azure Home select...",
      "Url": "https://..."
    }
  },
  "Categories": [],
  "DependsOn": [],
  "RelatedTo": [],
  "Notes": ""
}
```

**Key fields for conversion:**
- `CheckID` → PowerShell function name (snake_case → PascalCase)
- `CheckTitle` → `.SYNOPSIS`
- `Description` → `.DESCRIPTION`
- `ServiceName` → service grouping (entra, iam, storage, keyvault)
- `Severity` → low, medium, high, critical
- `Remediation.Recommendation` → remediation metadata

## Check Implementation

Every Prowler check follows this exact structure:

```python
from prowler.lib.check.models import Check, Check_Report_Azure
from prowler.providers.azure.services.{service}.{service}_client import {service}_client


class {check_id}(Check):
    def execute(self) -> Check_Report_Azure:
        findings = []

        # Iterate over resources from the service client
        for key, resource in {service}_client.{resource_type}.items():
            report = Check_Report_Azure(
                metadata=self.metadata(), resource=resource
            )
            report.subscription = f"Tenant: {key}"  # or just key for subscriptions
            report.status = "FAIL"                   # Default to FAIL
            report.status_extended = "Failure message."

            # Check condition
            if some_condition:
                report.status = "PASS"
                report.status_extended = "Success message."

            findings.append(report)

        return findings
```

**Key elements:**
1. **Class name** = check ID (snake_case)
2. **Inherits** from `Check` base class
3. **Single method**: `execute()` → returns list of report objects
4. **Report object**: `Check_Report_Azure` (or `_AWS`, `_GCP`)
5. **Default FAIL**: Most checks default to FAIL, then set PASS on success
6. **Accumulate findings**: `findings.append(report)` in a loop

### Report Object Properties

| Property | Type | Description |
|----------|------|-------------|
| `metadata` | object | From `self.metadata()` — auto-loaded from JSON |
| `resource` | object | The resource being checked |
| `subscription` | string | Subscription/tenant identifier |
| `status` | string | `"PASS"`, `"FAIL"`, `"MANUAL"`, `"SKIPPED"` |
| `status_extended` | string | Human-readable result message |
| `resource_name` | string | Friendly name (optional, from resource) |
| `resource_id` | string | Unique ID (optional, from resource) |

## Service Client Pattern

Each service has a singleton client that pre-loads data:

```python
# {service}_client.py
from prowler.providers.azure.services.{service}.{service}_service import {ServiceClass}
from prowler.providers.common.provider import Provider

{service}_client = {ServiceClass}(Provider.get_global_provider())
```

The service class loads data in `__init__` via async methods:

```python
class Entra(AzureService):
    def __init__(self, provider):
        super().__init__(GraphServiceClient, provider)
        # Load data into instance attributes
        self.users = loop.run_until_complete(self._get_users())
        self.security_default = loop.run_until_complete(self._get_security_default())
        self.authorization_policy = loop.run_until_complete(self._get_authorization_policy())
        self.directory_roles = loop.run_until_complete(self._get_directory_roles())
        # etc.
```

**Data structure**: Service attributes are dictionaries keyed by tenant/subscription:
```python
self.security_default = {
    "tenant-domain.com": SecurityDefaultObject(is_enabled=True, ...)
}
self.storage_accounts = {
    "subscription-id-1": [StorageAccount(...), StorageAccount(...)],
    "subscription-id-2": [StorageAccount(...)]
}
```

## Common Check Patterns

### Pattern 1: Simple Boolean Property

```python
# Checks a single boolean attribute on a resource
if getattr(security_default, "is_enabled", False):
    report.status = "PASS"
```

**PowerShell equivalent pattern:** Direct property comparison, or delegate to a parameterized helper that iterates resources and compares a property path.

---

### Pattern 2: Count-Based

```python
# Checks the count of something
num_admins = len(getattr(role["Global Administrator"], "members", []))
if num_admins < 5:
    report.status = "PASS"
    report.status_extended = f"There are {num_admins} global administrators."
```

**PowerShell equivalent:** `$members.Count -lt 5` with null-safe `@(...)` wrapping.

---

### Pattern 3: Nested Property with None Guards

```python
# Checks deeply nested properties with None safety
if (keyvault.properties and keyvault.properties.enable_rbac_authorization):
    report.status = "PASS"
```

**PowerShell equivalent:** Navigate using `PSObject.Properties[]` per segment.

---

### Pattern 4: Array Search with any()

```python
# Searches an array for matching items
if any(
    "ManagePermissionGrantsForSelf.microsoft-user-default-legacy" in policy
    for policy in getattr(perms, 'permission_grant_policies_assigned', [])
):
    report.status = "FAIL"
```

**PowerShell equivalent:** `Where-Object` pipeline with `-match` or `-contains`.

---

### Pattern 5: Multi-Level Iteration

```python
# Iterates subscription → resources → per-resource check
for subscription, storage_accounts in storage_client.storage_accounts.items():
    for storage_account in storage_accounts:
        report = Check_Report_Azure(metadata=self.metadata(), resource=storage_account)
        report.subscription = subscription
        if not storage_account.enable_https_traffic_only:
            report.status = "FAIL"
```

**PowerShell equivalent:** Nested `foreach` over service dictionary keys and resource arrays.

---

### Pattern 6: Conditional Report Fields

```python
# Sets optional report fields based on data availability
report.resource_name = getattr(auth_policy, "name", "Authorization Policy")
report.resource_id = getattr(auth_policy, "id", "authorizationPolicy")
```

**PowerShell equivalent:** Ternary-style `if` expression with `PSObject.Properties[]` check.

---

### Pattern 7: Per-Item with Vault-Level Summary

```python
# Reports per-item failures but vault-level pass
has_item_without_exp = False
for key in vault_keys:
    if not key.expires and key.enabled:
        has_item_without_exp = True
        # FAIL per item
        findings.append(fail_report)

if not has_item_without_exp:
    # PASS for the whole vault
    findings.append(pass_report)
```

**PowerShell equivalent:** Boolean tracker `$hasFailure`, per-item FAIL emission, vault-level PASS at end.

---

### Naming Convention: Python → PowerShell

| Python check ID | PowerShell function name |
|-----------------|-------------------------|
| `entra_security_defaults_enabled` | `Test-EntraSecurityDefaultsEnabled` |
| `storage_secure_transfer_required_is_enabled` | `Test-StorageSecureTransferRequiredIsEnabled` |
| `keyvault_rbac_enabled` | `Test-KeyvaultRbacEnabled` |
| `iam_custom_role_has_permissions_to_administer_resource_locks` | `Test-IamCustomRoleHasPermissionsToAdministerResourceLocks` |

**Rule:** Split on `_`, PascalCase each segment, prefix with `Test-`.
