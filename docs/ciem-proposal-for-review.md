# Devolutions CIEM - Project Proposal

## Summary

This document outlines the proposed architecture for Devolutions CIEM, a PowerShell Universal (PSU) module that scans cloud environments for identity and entitlement issues. The module will be distributed free through the PSU Gallery as a lead generation tool for Devolutions PAM.

---

## Background: Prowler

[Prowler](https://github.com/prowler-cloud/prowler) is an open-source cloud security tool (Apache 2.0 licensed) that performs security assessments across AWS, Azure, GCP, and other cloud providers. It includes:

- **584 AWS checks** across 85 services
- **169 Azure checks** across 22 services
- Compliance mapping to CIS, SOC2, ISO27001, NIST, and 30+ frameworks
- A Python CLI that outputs findings in various formats

Prowler has already solved the hard problem of defining *what to check* for cloud security issues. We can leverage their check definitions and security logic as a reference for building our PowerShell implementation.

### Example Identity Checks from Prowler

**Azure - Privileged User MFA Check:**
| Field | Value |
|-------|-------|
| Check ID | `entra_privileged_user_has_mfa` |
| Title | Ensure that 'Multi-Factor Auth Status' is 'Enabled' for all Privileged Users |
| Severity | High |
| Risk | Without MFA, an attacker only needs to compromise one authentication factor to gain access to privileged accounts |
| Remediation | Enable MFA for users in Microsoft Entra ID |

**AWS - Privilege Escalation Detection:**
| Field | Value |
|-------|-------|
| Check ID | `iam_policy_allows_privilege_escalation` |
| Title | Customer managed IAM policy does not allow actions that can lead to privilege escalation |
| Severity | High |
| Risk | Privilege-escalation permissions let principals assume higher-privilege roles or attach admin policies |
| Remediation | Apply least privilege - avoid wildcards, remove broad `iam:PassRole` permissions |

### Sample Output

When Prowler runs these checks, it produces findings like:

```
FAIL - Privileged user john.doe@contoso.com does not have MFA
PASS - Privileged user admin@contoso.com has MFA
FAIL - Custom Policy arn:aws:iam::123456789012:policy/DevOps allows privilege
       escalation using the following actions: iam:CreatePolicyVersion, iam:AttachRolePolicy
```

Our PowerShell module will produce similar findings that can be displayed in the PSU App interface.

### Other Identity Checks We'd Port

**Azure Entra ID / IAM (17 checks):**
- `entra_privileged_user_has_mfa` - MFA for privileged users
- `entra_non_privileged_user_has_mfa` - MFA for all users
- `entra_global_admin_in_less_than_five_users` - Limit Global Admin count
- `entra_policy_guest_invite_only_for_admin_roles` - Guest invite restrictions
- `entra_policy_guest_users_access_restrictions` - Guest access limitations
- `entra_conditional_access_policy_require_mfa_for_management_api` - MFA for Azure Management
- `iam_subscription_roles_owner_custom_not_created` - No custom Owner roles
- `iam_custom_role_has_permissions_to_administer_resource_locks` - Resource lock permissions

**AWS IAM (50+ checks):**
- `iam_policy_allows_privilege_escalation` - Detect escalation paths
- `iam_root_mfa_enabled` - Root account MFA
- `iam_no_root_access_key` - No root access keys
- `iam_rotate_access_key_90_days` - Key rotation policy
- `iam_user_mfa_enabled_console_access` - User MFA requirements
- `iam_avoid_root_usage` - Root account usage monitoring
- `iam_policy_attached_only_to_group_or_roles` - No direct user policies
- `iam_customer_attached_policy_no_administrative_privileges` - Least privilege

---

## Proposed Approach

### PSU App + PowerShell Module

CIEM will be delivered as two components:

1. **PSU App** - A visual interface within PowerShell Universal for configuring scans, viewing results, and exploring findings
2. **PowerShell Module** - The engine that performs the actual identity checks, built on Az.* and AWS.Tools.* modules

Both components are packaged together and distributed through the PSU Gallery.

**Benefits:**
- Zero external dependencies - no Python, no additional runtimes
- Works anywhere PSU runs: Azure App Service, on-prem Windows, Linux containers
- Installs cleanly from PSU Gallery with automatic dependency resolution
- Aligns with PSU's PowerShell-first ecosystem
- Module can also be used standalone via command line if needed
- Easy for PSU customers to understand, extend, and troubleshoot

**Technical Approach:**
- Port Prowler's identity-focused check logic to PowerShell
- Use Az.* modules for Azure API calls
- Use AWS.Tools.* modules for AWS API calls
- App calls module functions to execute scans and display results

---

## V1 Scope

### What's Included

| Feature | Details |
|---------|---------|
| **Cloud Providers** | Azure and AWS |
| **Check Focus** | Identity and entitlement issues only |
| **Azure Checks** | Entra ID (MFA, privileged roles, guest users), RBAC assignments, Managed Identity, Key Vault access |
| **AWS Checks** | IAM users/roles/policies, access keys, S3 bucket policies, Secrets Manager |
| **Authentication** | Auto-detect Managed Identity / Instance Profile, fall back to credentials |
| **PSU Integration** | App with scan configuration and results viewer |
| **PAM Integration** | Link to PAM documentation from findings |

### What's Deferred (Future Versions)

| Feature | Rationale |
|---------|-----------|
| Active Directory (LDAP) | Different architecture, can add as provider later |
| Compliance frameworks | Not needed for CIEM use case |
| Historical trending | Adds database complexity; v1 shows latest scan only |
| GCP, M365, Kubernetes | Can add providers incrementally |
| Deep PAM integration | Requires PAM API work; link to docs sufficient for v1 |

---

## User Experience

### Scan Configuration
User selects:
1. Provider (Azure or AWS)
2. Authentication is auto-detected (Managed Identity in Azure, Instance Profile in AWS)
3. Scope (which subscriptions/accounts to scan)
4. Click "Run Scan"

### Results View
- Table of findings with severity, resource, and description
- Filter by severity (Critical, High, Medium, Low)
- Filter by status (Pass, Fail)
- Click finding to see details and remediation steps
- "Learn about Devolutions PAM" link for taking action

---

## Distribution

The module will be published to **PowerShell Gallery** with the `PowerShellUniversal` tag, making it automatically discoverable in PSU's Gallery page.

**Installation for customers:**
1. Open PSU Admin Console
2. Navigate to Platform > Gallery
3. Find "Devolutions CIEM"
4. Click Install

PSU handles all dependency installation automatically.

---

## Check Architecture

Each identity check follows a consistent pattern, making it easy to add new checks over time.

### Check Structure

```
Checks/
├── Azure/
│   ├── EntraPrivilegedUserHasMFA/
│   │   ├── EntraPrivilegedUserHasMFA.ps1      # Check logic
│   │   └── EntraPrivilegedUserHasMFA.json     # Metadata
│   └── ...
└── AWS/
    ├── IAMPolicyAllowsPrivilegeEscalation/
    │   ├── IAMPolicyAllowsPrivilegeEscalation.ps1
    │   └── IAMPolicyAllowsPrivilegeEscalation.json
    └── ...
```

### Check Script (Example)

```powershell
# EntraPrivilegedUserHasMFA.ps1
function Invoke-EntraPrivilegedUserHasMFA {
    param([object]$Context)

    $findings = @()
    $users = Get-MgUser -Filter "assignedRoles/any()"

    foreach ($user in $users) {
        $hasMFA = Test-UserHasMFA -UserId $user.Id

        $findings += [PSCustomObject]@{
            CheckId      = 'entra_privileged_user_has_mfa'
            Status       = if ($hasMFA) { 'PASS' } else { 'FAIL' }
            Severity     = 'High'
            ResourceId   = $user.Id
            ResourceName = $user.UserPrincipalName
            Message      = if ($hasMFA) {
                "Privileged user $($user.UserPrincipalName) has MFA"
            } else {
                "Privileged user $($user.UserPrincipalName) does not have MFA"
            }
        }
    }
    return $findings
}
```

### Check Metadata (Example)

```json
{
  "CheckId": "entra_privileged_user_has_mfa",
  "Title": "Ensure MFA is enabled for all privileged users",
  "Provider": "Azure",
  "Service": "Entra",
  "Severity": "High",
  "Description": "Privileged users should have MFA enabled to protect against credential compromise.",
  "Risk": "Without MFA, compromised credentials grant immediate access to privileged resources.",
  "Remediation": "Enable MFA in Entra ID > Users > Authentication methods",
  "PAMLink": "https://devolutions.net/pam"
}
```

### Adding a New Check

1. Create a folder under `Checks/<Provider>/`
2. Add a `.ps1` file with the check function following the naming convention `Invoke-<CheckName>`
3. Add a `.json` metadata file with check details
4. The module auto-discovers checks on load - no registration required

This pattern mirrors Prowler's structure, making it straightforward to port existing checks and create new ones.

---

## Next Steps

Once you approve this direction:

1. **Check Inventory** - Analyze Prowler and list specific checks to port
2. **Module Scaffold** - Create PowerShell module structure with PSU integration
3. **Azure Provider** - Port identity checks, test against real environment
4. **AWS Provider** - Port identity checks, test against real environment
5. **PSU App** - Build scan UI and results viewer
6. **Testing** - Validate on the Azure App Service PSU instance
7. **Publish** - Release to PowerShell Gallery

---

Let me know if you have questions or want to discuss any of these decisions.
