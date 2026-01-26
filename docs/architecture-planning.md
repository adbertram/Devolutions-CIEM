# Devolutions CIEM - Architecture Planning Document

## Project Overview

Devolutions CIEM (Cloud Infrastructure Entitlement Management) is a PowerShell Universal (PSU) module that provides cloud security scanning functionality, focusing on identity and entitlement issues.

### Business Context

- **Distribution Model**: PSU app published to the PSU Gallery (not standalone deployment)
- **Pricing**: Free add-on for PSU customers (no additional cost beyond PSU license)
- **Strategic Purpose**: Lead generation for Devolutions PAM solution; CIEM is a Gartner inclusion criteria for PAM
- **Action Flow**: CIEM identifies findings → users are redirected to Devolutions PAM to take action

### Stakeholder Requirements (Marc-André Moreau)

Key requirements from project lead:

1. "For taking action on the findings, we'd redirect people to our PAM solution"
2. "Basically a goodie that enhances the value of PSU and covers CIEM (one of the Gartner inclusion criteria for PAM)"
3. "We'd give it away for free / open source - of course you'd need to pay for PSU, but it wouldn't cost more to use it"
4. "For instance, in Azure, run it as a PSU container in Az Web App with a managed Azure identity that has sufficient rights"
5. "The focus should be on finding overprivileged account and permissions issues"
6. "We could do a module for Active Directory through LDAP, mapping users permissions and groups" (future scope)
7. "If there's no good fit, we're fine with just building minimal functionality as a PowerShell module on top of the first-class PowerShell modules for each cloud"

---

## Architecture Decisions

### Core Approach: Native PowerShell Port

**Decision**: Port Prowler's identity-focused checks to native PowerShell (NOT a Python wrapper)

**Rationale**:
- Module must run on various environments: Azure App Service, on-prem PSU servers, Windows servers
- Cannot have Python dependency - customers shouldn't need to install Python
- Must work in offline/air-gapped environments
- Windows compatibility is essential

**Trade-offs**:
- Higher initial development effort to port checks
- Maintenance burden to keep parity with upstream Prowler
- Gain: Zero external runtime dependencies, pure PowerShell distribution

### Architecture Summary

| Aspect | Decision |
|--------|----------|
| **Approach** | Native PowerShell port (no Python dependency) |
| **V1 Providers** | Azure + AWS |
| **Check Scope** | Identity/entitlement focused only |
| **Compliance Mapping** | Not in v1 |
| **Cloud SDKs** | Az.* modules, AWS.Tools.* modules |
| **PSU Integration** | PSU App with Pages for scan config and results |
| **Data Persistence** | Job output (snapshot per scan, no historical queries) |
| **PAM Integration** | Link to documentation (placeholder for future) |
| **Distribution** | PSU Gallery via PowerShell Gallery with RequiredModules |
| **AD Support** | Architected for extensibility, not implemented in v1 |

---

## V1 Scope

### In Scope

#### Providers
- **Azure**: Identity-focused checks
- **AWS**: Identity-focused checks

#### Identity-Focused Check Categories

**Azure:**
- Entra ID (formerly AAD) - conditional access, MFA, privileged roles, guest users
- RBAC - overprivileged assignments, custom role definitions
- Managed Identity - usage patterns, permissions
- Key Vault access policies
- Storage account access (SAS tokens, public access)

**AWS:**
- IAM users, roles, policies, access keys
- STS/assume role patterns
- S3 bucket policies (identity aspect)
- Secrets Manager/Parameter Store access

#### Authentication Methods
- **Azure**: Managed Identity (auto-detect), Service Principal (env vars), Az CLI context
- **AWS**: Instance Profile (auto-detect), Access Keys, IAM role assumption

### Out of Scope for V1

- Compliance framework mapping (CIS, SOC2, ISO27001, etc.)
- Active Directory via LDAP
- Historical findings / trending
- Custom database tables
- GCP, Kubernetes, M365, GitHub, Oracle Cloud providers
- Deep PAM integration (API calls, ticket creation)
- Non-identity checks (network, encryption, etc.)

---

## Technical Architecture

### Module Structure

```
Devolutions.CIEM/
├── .universal/                    # PSU resource definitions
│   ├── apps.ps1                   # PSU App definition
│   └── scripts.ps1                # Background job definitions
├── Devolutions.CIEM.psd1          # Module manifest
├── Devolutions.CIEM.psm1          # Root module
├── Public/                        # Exported functions
│   ├── Invoke-CIEMScan.ps1
│   ├── Get-CIEMProviders.ps1
│   └── ...
├── Private/                       # Internal functions
│   ├── Core/
│   │   ├── Invoke-Check.ps1
│   │   └── New-Finding.ps1
│   ├── Azure/
│   │   ├── Connect-AzureProvider.ps1
│   │   └── Checks/
│   │       ├── Check-EntraIDMFA.ps1
│   │       ├── Check-RBACOverprivileged.ps1
│   │       └── ...
│   └── AWS/
│       ├── Connect-AWSProvider.ps1
│       └── Checks/
│           ├── Check-IAMAccessKeys.ps1
│           ├── Check-IAMPolicies.ps1
│           └── ...
└── Data/
    └── CheckMetadata.psd1         # Check definitions and metadata
```

### Module Manifest Dependencies

```powershell
# Devolutions.CIEM.psd1
@{
    ModuleVersion = '1.0.0'
    GUID = '<new-guid>'
    Author = 'Devolutions'
    CompanyName = 'Devolutions'
    Description = 'Cloud Infrastructure Entitlement Management for PowerShell Universal'

    RootModule = 'Devolutions.CIEM.psm1'

    RequiredModules = @(
        # Azure
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '4.0.0' }
        @{ ModuleName = 'Az.Resources'; ModuleVersion = '7.0.0' }
        @{ ModuleName = 'Az.KeyVault'; ModuleVersion = '6.0.0' }
        @{ ModuleName = 'Az.Storage'; ModuleVersion = '7.0.0' }
        # AWS (modular approach)
        @{ ModuleName = 'AWS.Tools.Common'; ModuleVersion = '4.1.0' }
        @{ ModuleName = 'AWS.Tools.IAM'; ModuleVersion = '4.1.0' }
        @{ ModuleName = 'AWS.Tools.S3'; ModuleVersion = '4.1.0' }
        @{ ModuleName = 'AWS.Tools.SecretsManager'; ModuleVersion = '4.1.0' }
    )

    FunctionsToExport = @(
        'Invoke-CIEMScan'
        'Get-CIEMProviders'
        'Get-CIEMChecks'
    )

    PrivateData = @{
        PSData = @{
            Tags = @('CIEM', 'Security', 'Cloud', 'Identity', 'PowerShellUniversal')
            LicenseUri = 'https://github.com/Devolutions/Devolutions-CIEM/blob/main/LICENSE'
            ProjectUri = 'https://github.com/Devolutions/Devolutions-CIEM'
        }
    }
}
```

### PSU App Definition

```powershell
# .universal/apps.ps1
New-PSUApp -Name 'Devolutions CIEM' -Module 'Devolutions.CIEM' -Command 'Show-CIEMApp' -BaseUrl '/ciem' -Description 'Cloud Infrastructure Entitlement Management'
```

### Data Model

#### Finding Object

```powershell
[PSCustomObject]@{
    CheckId          = 'azure_entra_mfa_disabled'
    Provider         = 'Azure'
    Severity         = 'High'              # Critical, High, Medium, Low, Informational
    Status           = 'FAIL'              # PASS, FAIL, MANUAL, SKIPPED
    ResourceType     = 'User'
    ResourceId       = '/users/abc123'
    ResourceName     = 'john.doe@contoso.com'
    Region           = 'global'
    SubscriptionId   = 'sub-123'           # Azure
    AccountId        = '123456789012'      # AWS
    Title            = 'MFA not enabled for user'
    Description      = 'User john.doe@contoso.com does not have MFA enabled'
    Remediation      = 'Enable MFA for this user in Entra ID > Users > Authentication methods'
    PAMLink          = 'https://devolutions.net/pam/...'
    Timestamp        = [DateTime]::UtcNow
}
```

---

## PSU Integration Details

### PSU Gallery Distribution

PSU Gallery modules are published to PowerShell Gallery with the `PowerShellUniversal` tag:

1. Module appears in PSU admin console under Platform > Gallery
2. Users click Install to add to their environment
3. PSU automatically resolves `RequiredModules` dependencies
4. Resources in `.universal/` folder are loaded as read-only

### App Pages (V1 Minimal)

1. **Scan Configuration Page**
   - Provider selection (Azure, AWS)
   - Authentication method selection
   - Scope selection (subscriptions/accounts)
   - Run Scan button

2. **Results Viewer Page**
   - Data grid of findings
   - Filter by severity, status, provider
   - Finding details panel
   - Link to PAM documentation

### Authentication Auto-Detection

```powershell
function Get-AzureAuthContext {
    # 1. Try Managed Identity (Azure environments)
    # 2. Try existing Az context
    # 3. Prompt for Service Principal credentials
}

function Get-AWSAuthContext {
    # 1. Try Instance Profile (EC2/ECS)
    # 2. Try environment variables
    # 3. Try AWS credential file
    # 4. Prompt for access keys
}
```

---

## Prowler Check Porting Strategy

### Prowler Check Structure (Python)

```python
# Example Prowler check structure
class entra_conditional_access_policy_require_mfa(Check):
    def execute(self):
        findings = []
        for policy in self.azure_client.conditional_access_policies:
            if not policy.requires_mfa:
                findings.append(
                    CheckFindings(
                        status="FAIL",
                        resource_name=policy.name,
                        resource_id=policy.id,
                        ...
                    )
                )
        return findings
```

### PowerShell Equivalent

```powershell
function Invoke-Check-EntraConditionalAccessMFA {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context
    )

    $findings = @()
    $policies = Get-AzADConditionalAccessPolicy

    foreach ($policy in $policies) {
        $requiresMFA = $policy.GrantControls.BuiltInControls -contains 'mfa'

        $findings += [PSCustomObject]@{
            CheckId      = 'azure_entra_conditional_access_mfa'
            Status       = if ($requiresMFA) { 'PASS' } else { 'FAIL' }
            ResourceId   = $policy.Id
            ResourceName = $policy.DisplayName
            # ... other fields
        }
    }

    return $findings
}
```

### Porting Approach

1. **Inventory**: Analyze Prowler codebase to list all identity-focused checks
2. **Prioritize**: Rank by severity and relevance to CIEM use case
3. **Port iteratively**: Start with highest-value checks
4. **Test**: Validate against real Azure/AWS environments
5. **Document**: Map Prowler check IDs to new PowerShell check IDs

---

## Open Questions / Decisions Needed

### 1. Check Inventory
Need to analyze Prowler's codebase and produce a concrete list of identity-focused checks to port for Azure and AWS. This provides actual scope and effort estimate.

### 2. Authentication UX
When configuring a scan, how should users specify credentials?
- **Option A**: Auto-detect and only prompt when needed
- **Option B**: Explicit fields for all auth options
- **Recommendation**: Auto-detect with fallback prompts

### 3. Scan Scope Selection
How granular should scope selection be in V1?
- **Azure**: Entire tenant? Specific subscriptions? Resource groups?
- **AWS**: Entire account? Specific regions? Specific services?
- **Recommendation**: Start with subscription/account level, add granularity later

### 4. Error Handling During Scans
If a check fails (insufficient permissions, API error):
- **Option A**: Stop entirely and report error
- **Option B**: Skip that check and continue, note as "SKIPPED"
- **Option C**: Retry with backoff
- **Recommendation**: Skip and continue (matches Prowler behavior)

### 5. Upstream Sync Strategy
How to stay current with Prowler's check updates:
- **Option A**: One-time port, independent evolution
- **Option B**: Periodic manual sync
- **Option C**: Automated transpilation (ambitious)
- **Recommendation**: Start with Option A, evaluate sync need based on Prowler release frequency

---

## Next Steps

1. [ ] Inventory Prowler identity-focused checks for Azure and AWS
2. [ ] Design check execution framework in PowerShell
3. [ ] Create module scaffold with PSU integration
4. [ ] Port highest-priority Azure checks
5. [ ] Port highest-priority AWS checks
6. [ ] Build PSU App UI (scan config + results viewer)
7. [ ] Test in Azure App Service environment
8. [ ] Publish to PowerShell Gallery with PSU tag

---

## References

- [Prowler GitHub](https://github.com/prowler-cloud/prowler)
- [PSU Gallery Documentation](../prowler/docs/psu-docs/platform/library.md)
- [PSU Modules Documentation](../prowler/docs/psu-docs/platform/modules.md)
- [PSU Persistence Documentation](../prowler/docs/psu-docs/config/persistence.md)
- [Az PowerShell Module](https://docs.microsoft.com/en-us/powershell/azure/)
- [AWS Tools for PowerShell](https://docs.aws.amazon.com/powershell/)
