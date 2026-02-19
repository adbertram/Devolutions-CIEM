# Devolutions CIEM - Architecture Planning Document

## Project Overview

Devolutions CIEM (Cloud Infrastructure Entitlement Management) is a PowerShell Universal (PSU) module that provides cloud entitlement analysis, focusing on discovering overprivileged identities, dormant permissions, and role right-sizing.

### Business Context

- **Distribution Model**: PSU app published to the PSU Gallery (not standalone deployment)
- **Pricing**: Free add-on for PSU customers (no additional cost beyond PSU license)
- **Strategic Purpose**: Lead generation for Devolutions PAM solution; CIEM is a Gartner inclusion criteria for PAM
- **Differentiation**: CIEM is a niche segment where organizations see value in lightweight solutions — unlike CSPM which is a commodity already bundled free in cloud platforms (e.g., Defender for Cloud)
- **Action Flow**: CIEM identifies findings → users are redirected to Devolutions PAM to take action

### CSPM vs CIEM Distinction (CRITICAL)

Per stakeholder feedback, the project must be positioned as **true CIEM, not lightweight CSPM**.

**What we built initially (CSPM-like):**
- CIS best-practice validation checks (MFA enabled, key rotation, etc.)
- Prowler-ported checks that validate security posture
- This is commodity — cloud platforms already offer it for free

**What true CIEM requires:**
- **Control relationship discovery** — Map relationships between cloud objects and identify risks (e.g., an internet-exposed VM holding Azure privileges that allow pivoting into infrastructure)
- **Dormant permission detection** — Identify users/service principals holding privileged roles they haven't used in 180+ days (via Entra sign-in logs, AWS CloudTrail)
- **Role right-sizing** — Propose custom roles aligned with least privilege to replace overly broad roles detected in the environment
- **Risk-to-PAM mapping** — Connect detected risk levels and privileged roles to Devolutions PAM (this is closer to CIEM than posture checks)

### Stakeholder Feedback (Marc-André Moreau)

**Initial requirements:**
1. "For taking action on the findings, we'd redirect people to our PAM solution"
2. "Basically a goodie that enhances the value of PSU and covers CIEM (one of the Gartner inclusion criteria for PAM)"
3. "We'd give it away for free / open source - of course you'd need to pay for PSU, but it wouldn't cost more to use it"
4. "For instance, in Azure, run it as a PSU container in Az Web App with a managed Azure identity that has sufficient rights"
5. "The focus should be on finding overprivileged account and permissions issues"
6. "We could do a module for Active Directory through LDAP, mapping users permissions and groups" (future scope)
7. "If there's no good fit, we're fine with just building minimal functionality as a PowerShell module on top of the first-class PowerShell modules for each cloud"

**Demo review feedback (repositioning directive):**
- The initial demo delivered a lightweight CSPM, not a CIEM — checks only touch IAM superficially
- CSPM is a commodity; most cloud users already have one — limited added value
- Multi-cloud monitoring (AWS, Azure, GCP in one console) is the only CSPM value-add
- CIEM is a niche segment where a lightweight solution has real value because organizations haven't adopted one yet
- **Directive**: Keep the PSU showcase as foundation, but pivot to CIEM features — dormant roles via Entra sign-in logs, oversized role detection, least-privilege recommendations
- The PSU app itself was praised as "an excellent showcase of what PSU is capable of"

---

## Architecture Decisions

### Core Approach: Native PowerShell Port

**Decision**: Port Prowler's checks to native PowerShell (NOT a Python wrapper)

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
| **Approach** | Native PowerShell (no Python dependency) |
| **V1 Providers** | Azure + AWS |
| **Core Focus** | CIEM: dormant permissions, role right-sizing, control relationships |
| **CSPM Checks** | Retained as secondary feature (Prowler-ported posture checks) |
| **Cloud SDKs** | Az.* modules, AWS.Tools.* modules |
| **PSU Integration** | PSU App with Pages for scan config and results |
| **Data Persistence** | Job output (snapshot per scan, no historical queries) |
| **PAM Integration** | Risk-to-PAM mapping (connect findings to PAM privileged roles) |
| **Distribution** | PSU Gallery via PowerShell Gallery with RequiredModules |
| **AD Support** | Architected for extensibility, not implemented in v1 |

---

## V1 Scope

### Primary: CIEM Features (Differentiators)

These are the features that differentiate us from free CSPM tools and justify the project:

#### Dormant Permission Detection
- Analyze Entra sign-in logs to identify users/service principals with privileged roles unused in 180+ days
- Analyze AWS CloudTrail to detect IAM roles/users with unused permissions
- Flag dormant privileged accounts as high-risk findings

#### Role Right-Sizing
- Detect overly broad role assignments (e.g., Contributor/Owner at subscription scope)
- Propose custom roles aligned with least privilege based on actual usage patterns
- Compare assigned permissions vs. actually-used permissions

#### Control Relationship Discovery
- Map relationships between cloud objects (VMs, identities, network exposure)
- Identify high-risk combinations (e.g., internet-exposed VM with privileged Azure identity)
- Surface attack paths that chain entitlements together

#### Risk-to-PAM Mapping
- Connect detected risk levels and privileged roles to Devolutions PAM
- Deeper than a documentation link — map findings to PAM-actionable items

### Secondary: CSPM Posture Checks (Retained)

The existing Prowler-ported checks are retained as a secondary feature layer:
- CIS best-practice validation (MFA, key rotation, etc.)
- All synced Prowler checks for Azure and AWS
- Useful as a baseline but not the differentiator

### Providers
- **Azure**: Entra ID sign-in logs, RBAC analysis, resource relationships
- **AWS**: CloudTrail analysis, IAM policy analysis, resource relationships

### Authentication Methods
- **Azure**: Managed Identity (auto-detect), Service Principal (env vars), Az CLI context
- **AWS**: Instance Profile (auto-detect), Access Keys, IAM role assumption

### Out of Scope for V1

- Compliance framework mapping (CIS, SOC2, ISO27001, etc.)
- Active Directory via LDAP
- Historical findings / trending
- Custom database tables
- GCP, Kubernetes, M365, GitHub, Oracle Cloud providers
- Deep PAM API integration (ticket creation, automated onboarding)

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

1. **Inventory**: Analyze Prowler codebase to list all checks
2. **Prioritize**: Rank by severity and relevance to CIEM use case
3. **Port iteratively**: Start with highest-value checks
4. **Test**: Validate against real Azure/AWS environments
5. **Document**: Map Prowler check IDs to new PowerShell check IDs

---

## Prowler Check Sync Architecture

### Overview

Checks are sourced from [Prowler](https://github.com/prowler-cloud/prowler) and synced into the module as **scaffolding** — a JSON metadata entry in `ciem_checks.json` and a stub `.ps1` check script. The sync process does NOT fill in the PowerShell implementation logic; that is done manually.

### Key Commands

```powershell
Import-Module ./Devolutions.CIEM

# Discover what checks exist upstream (no local changes)
Get-ProwlerCheck                                    # All checks
Get-ProwlerCheck -Provider aws                      # AWS only
Get-ProwlerCheck -Provider azure -Service entra     # Specific service

# Sync new checks (creates JSON entry + stub script)
Sync-ProwlerCheck                                   # All providers
Sync-ProwlerCheck -Provider aws                     # AWS only
Sync-ProwlerCheck -Provider azure -Service keyvault # Specific service
Sync-ProwlerCheck -Ref 'v4.0.0'                     # From a specific tag/branch

# List synced checks in the module
Get-CIEMCheck                                       # All checks from ciem_checks.json
Get-CIEMCheck -Provider Azure -Service Entra        # Filter by provider/service
```

### What Sync Creates

For each new Prowler check, `Sync-ProwlerCheck` creates:

1. **JSON metadata entry** in `Devolutions.CIEM/ciem_checks.json` — contains id, title, description, risk, severity, remediation, permissions, and checkScript filename
2. **Stub PowerShell script** in `Devolutions.CIEM/Checks/{Provider}/Test-{Name}.ps1` — function skeleton with `$Check` and `$ServiceCache` parameters and a `# TODO` comment referencing the Prowler source

### How It Works Internally

1. `Get-GitHubRepoTree` fetches the Prowler repo tree via GitHub Trees API (single API call, cached)
2. Filters checks by provider/service using path patterns
3. Diffs against existing checks in `ciem_checks.json` (skips already-synced)
4. `Save-GitHubRepoSparseCheckout` bulk-downloads only the needed check directories via `git sparse-checkout`
5. `Convert-ProwlerCheck` converts each check:
   - Parses Prowler's `.metadata.json` → CIEM JSON format
   - Analyzes Python source to infer required permissions (Graph, ARM, IAM, KeyVault)
   - Generates PowerShell function stub

### File Layout

```
Devolutions.CIEM/
├── ciem_checks.json              # Central metadata for ALL checks (Azure + AWS)
├── Checks/
│   ├── Azure/                    # Azure check scripts
│   │   ├── Test-EntraNonPrivilegedUserHasMfa.ps1
│   │   └── ...
│   └── Aws/                      # AWS check scripts
│       ├── Test-IamUserMfaEnabled.ps1
│       └── ...
├── Public/
│   ├── Sync-ProwlerCheck.ps1     # Main sync orchestrator
│   ├── Get-ProwlerCheck.ps1      # Upstream check discovery
│   └── Get-CIEMCheck.ps1         # Local check listing
├── Private/
│   ├── Convert-ProwlerCheck.ps1  # Prowler → PowerShell converter
│   ├── Get-GitHubRepoTree.ps1    # GitHub Trees API client (cached)
│   └── Save-GitHubRepoSparseCheckout.ps1  # Sparse git clone
```

### Check Script Pattern

Every check script follows the same contract:

```powershell
function Test-SomeCheckName {
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check,                          # PSCustomObject from ciem_checks.json

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache  # Pre-fetched cloud data
    )

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'ServiceName' }).CacheData

    # Implementation logic here...

    [CIEMScanResult]::Create($Check, 'PASS', 'Description', 'resource-id', 'Resource Name')
}
```

### Important Notes

- Synced stubs contain `# TODO` — they will SKIP during scans until implemented
- `ciem_checks.json` is the single source of truth for check metadata
- The module manifest `FileList` must include new check scripts for PSGallery packaging
- GitHub API rate limit: 60/hr unauthenticated (tree is cached to minimize calls)

---

## Open Questions / Decisions Needed

### 1. Dormant Permission Data Sources
What log sources to use for detecting dormant permissions?
- **Azure**: Entra sign-in logs (requires Microsoft Graph `AuditLog.Read.All`), Azure Activity logs
- **AWS**: CloudTrail (requires `cloudtrail:LookupEvents`), IAM Access Analyzer
- **Question**: What lookback period? 90 days? 180 days? Configurable?

### 2. Right-Sizing Implementation Depth
How deep should role right-sizing go in V1?
- **Option A**: Flag overly broad roles only (Contributor/Owner at wide scope)
- **Option B**: Propose specific custom role definitions based on usage
- **Option C**: Full used-vs-assigned permission diff
- **Recommendation**: Start with Option A, add Option B as fast follow

### 3. Control Relationship Scope
How much infrastructure mapping in V1?
- **Option A**: Identity-to-resource mapping only (who has access to what)
- **Option B**: Add network exposure context (internet-facing resources with privileged identities)
- **Option C**: Full attack path analysis
- **Recommendation**: Option B — identity mapping plus network exposure gives high-value findings

### 4. Authentication UX
When configuring a scan, how should users specify credentials?
- **Option A**: Auto-detect and only prompt when needed
- **Option B**: Explicit fields for all auth options
- **Recommendation**: Auto-detect with fallback prompts

### 5. CSPM Check Retention
How to handle existing Prowler-ported CSPM checks?
- Keep as secondary feature layer (still runs, lower priority in UI)
- Do not invest further in porting new CSPM checks — focus effort on CIEM features
- Existing checks remain useful as baseline posture validation

---

## Next Steps

1. [ ] Design dormant permission detection for Azure (Entra sign-in logs)
2. [ ] Design dormant permission detection for AWS (CloudTrail)
3. [ ] Implement role right-sizing analysis (overly broad role detection)
4. [ ] Implement identity-to-resource relationship mapping
5. [ ] Add network exposure context to relationship mapping
6. [ ] Build risk-to-PAM mapping for findings
7. [ ] Update PSU App UI to surface CIEM findings (dormant roles, right-sizing recommendations)
8. [ ] Test against real Azure/AWS environments
9. [ ] Publish updated module to PowerShell Gallery

---

## References

- [Prowler GitHub](https://github.com/prowler-cloud/prowler)
- [PSU Gallery Documentation](psu-docs/platform/library.md)
- [PSU Modules Documentation](psu-docs/platform/modules.md)
- [PSU Persistence Documentation](psu-docs/config/persistence.md)
- [Az PowerShell Module](https://docs.microsoft.com/en-us/powershell/azure/)
- [AWS Tools for PowerShell](https://docs.aws.amazon.com/powershell/)
