# Devolutions CIEM - Requirements

## Project Overview

Build an open-source Cloud Infrastructure Entitlement Management (CIEM) tool on PowerShell Universal (PSU) that scans cloud permissions and produces JSON reports for analysis.

## Source

Requirements gathered from stakeholder discussions with Marc-André Moreau (Devolutions) via Slack, January 2026.

---

## Business Context

### Strategic Purpose

CIEM is a **Gartner inclusion criteria for PAM** (Privileged Access Management). This tool positions Devolutions to meet that criteria while driving adoption of their PAM solution.

### Business Model

| Aspect | Decision |
|--------|----------|
| **Pricing** | Free / open-source |
| **PSU Licensing** | Customers pay for PSU license; CIEM adds no additional cost |
| **Monetization** | Lead generation for Devolutions PAM solution |

### Deployment Model

| Aspect | Decision |
|--------|----------|
| **Hosting** | Customer self-hosted (not SaaS) |
| **Tenant** | Deployed in customer's own Azure/AWS tenant |
| **Data Residency** | All data stays within customer environment |

### User Journey

```
CIEM identifies permission issues
         ↓
User reviews findings in PSU dashboard
         ↓
For remediation, user is redirected to Devolutions PAM
         ↓
PAM handles the actual fix/action
```

> "For taking action on the findings, we'd redirect people to our PAM solution" - Marc-André Moreau

---

## Core Requirements

### R1: Platform

| ID | Requirement | Priority |
|----|-------------|----------|
| R1.1 | Built on PowerShell Universal (PSU) | Must |
| R1.2 | Packaged as installable PSU app | Must |
| R1.3 | Open source (free add-on for PSU customers) | Must |
| R1.4 | Self-hosted in customer's own tenant | Must |
| R1.5 | Integration hook to Devolutions PAM for remediation | Should |

### R2: Cloud Provider Support

| ID | Requirement | Priority |
|----|-------------|----------|
| R2.1 | Scan Azure permissions | Must (MVP) |
| R2.2 | Scan AWS permissions | Must (MVP) |
| R2.3 | Extensible architecture for future cloud providers | Should |

### R3: Authentication

| ID | Requirement | Priority |
|----|-------------|----------|
| R3.1 | Azure: Service principal authentication | Must |
| R3.2 | AWS: Explicit credentials (access key/secret) | Must |
| R3.3 | No credential storage in scan results | Must |

### R4: Output Format

| ID | Requirement | Priority |
|----|-------------|----------|
| R4.1 | Generate JSON reports | Must |
| R4.2 | JSON optimized for LLM analysis (Claude/ChatGPT) | Must |
| R4.3 | Expose JSON via REST API endpoint | Must |
| R4.4 | Include instance metadata for aggregation tracking | Should |

### R5: Operation Mode

| ID | Requirement | Priority |
|----|-------------|----------|
| R5.1 | Read-only scanning (no remediation) | Must |
| R5.2 | Surface permission issues without attempting fixes | Must |
| R5.3 | Sufficient permissions to list resources and permissions | Must |

### R6: Aggregation Support

| ID | Requirement | Priority |
|----|-------------|----------|
| R6.1 | Each PSU instance returns findings independently | Must |
| R6.2 | JSON format supports external aggregation | Must |
| R6.3 | Support one PSU per cloud, aggregate externally | Must |

---

## MVP Scope

### In Scope (MVP)

1. **Azure Scanning**
   - Role assignments via `Get-AzRoleAssignment`
   - Role definitions via `Get-AzRoleDefinition`
   - Orphaned assignments (ObjectType = "Unknown")
   - Wildcard permissions in custom roles
   - Overprivileged built-in roles (Owner/Contributor at subscription level)

2. **AWS Scanning**
   - IAM users via `Get-IAMUser`
   - IAM roles via `Get-IAMRole`
   - Policy analysis for wildcards and broad permissions
   - Unused roles/users (last used timestamps)

3. **Output**
   - JSON report format
   - REST API endpoint to fetch results
   - Basic severity levels (Critical/High/Medium/Low)

4. **Authentication**
   - Service principal for Azure
   - Access key/secret for AWS

### Out of Scope (MVP)

- Remediation/auto-fix capabilities (handled by Devolutions PAM)
- Built-in visualization/dashboard
- Usage tracking (requires historical activity logs)
- Azure AD Premium sign-in tracking
- Cross-account trust analysis
- Built-in aggregation endpoint
- Scheduled scans (on-demand only for MVP)
- Caching layer
- SaaS/hosted offering (customer self-hosted only)

---

## Technical Constraints

### Dependencies

| Component | Module/Tool |
|-----------|-------------|
| Azure scanning | Az PowerShell module |
| AWS scanning | AWS.Tools PowerShell module |
| Platform | PowerShell Universal |

### Required Permissions

**Azure:**
- "User Access Administrator" role (for RBAC audit)
- Entra ID "Directory Reader" (for identity resolution)
- Read access to subscriptions being scanned

**AWS:**
- `iam:GetUser`, `iam:ListUsers`
- `iam:GetRole`, `iam:ListRoles`
- `iam:GetPolicy`, `iam:GetPolicyVersion`
- `iam:GetAccountAuthorizationDetails`

---

## CIEM Detection Categories

Based on research of commercial CIEM products, the following detection categories should inform feature development:

### Permission Issues
- Over-privileged identities (permissions granted but unused)
- Wildcard permissions in role definitions
- Excessive admin privileges (standing admin access)
- Permission creep over time

### Identity Hygiene
- Orphaned role assignments (pointing to deleted identities)
- Inactive/dormant accounts (no sign-in activity)
- Stale credentials (unused service principal credentials)
- Unused roles (never assumed)

### Access Risks
- Cross-account access (external trust relationships)
- Public exposure (publicly accessible resources)
- Super identities (unlimited access at root/subscription level)

---

## JSON Schema Considerations

The JSON output should include:

```json
{
  "scanMetadata": {
    "instanceId": "unique-identifier",
    "scanTimestamp": "ISO-8601",
    "cloudProvider": "azure|aws",
    "scope": "subscription-id or account-id"
  },
  "findings": [
    {
      "id": "finding-uuid",
      "type": "detection-type",
      "severity": "critical|high|medium|low",
      "resource": {
        "type": "resource-type",
        "id": "resource-identifier",
        "name": "display-name"
      },
      "description": "human-readable issue description",
      "evidence": {
        "field": "value"
      }
    }
  ],
  "summary": {
    "totalFindings": 0,
    "bySeverity": {
      "critical": 0,
      "high": 0,
      "medium": 0,
      "low": 0
    }
  }
}
```

---

## Success Criteria

1. User can install the PSU app and configure Azure/AWS credentials
2. User can trigger a scan via REST API
3. Scan produces JSON report with identified permission issues
4. JSON can be uploaded to Claude/ChatGPT for visualization and analysis
5. Multiple PSU instances can be deployed and their JSON aggregated externally
6. Users can navigate from findings to Devolutions PAM for remediation actions

---

## Resolved Questions

Based on stakeholder discussions with Marc-André Moreau:

| Question | Decision | Rationale |
|----------|----------|-----------|
| **Hosting Model** | Self-hosted by customer | Data stays in customer environment; no SaaS offering |
| **Pricing** | Free / open-source | Lead gen for PAM; enhances PSU value proposition |
| **Remediation** | Detection only; PAM handles fixes | Users redirected to Devolutions PAM for action |

---

## Open Questions

1. **JSON Schema**: Follow AWS Security Finding Format (ASFF) or custom schema?
2. **Multi-subscription**: Single subscription per scan or all accessible subscriptions?
3. **AWS Regions**: Global IAM only or include regional resource permissions?
4. **Partial Failures**: Return partial results on API errors or fail completely?
5. **Remediation Guidance**: Include how-to-fix in findings or detection only?
6. **Module Structure**: Single unified module or separate per cloud provider?
7. **License**: MIT, Apache 2.0, or other?
8. **PAM Integration**: Deep link format for redirecting to Devolutions PAM?

---

## References

- PowerShell Universal documentation
- Azure Az PowerShell module
- AWS.Tools PowerShell module
- AWS IAM Access Analyzer
- Commercial CIEM: Palo Alto, Wiz, CyberArk, Microsoft Entra Permissions Management
- Stakeholder conversations: Slack DM with Marc-André Moreau (`slack dm read mamoreau`)
