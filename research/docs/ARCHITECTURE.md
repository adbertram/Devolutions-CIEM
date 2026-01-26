# Devolutions CIEM - Architecture

## Overview

Devolutions CIEM follows a three-phase pipeline architecture that separates concerns and enables extensibility:

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  DISCOVERY  │ -> │  ANALYSIS   │ -> │  REPORTING  │
│             │    │             │    │             │
│ Scan cloud  │    │ Apply rules │    │ Generate    │
│ resources & │    │ to identify │    │ JSON output │
│ permissions │    │ issues      │    │ for LLMs    │
└─────────────┘    └─────────────┘    └─────────────┘
```

---

## Phase 1: Discovery

**Purpose**: Collect all relevant data from cloud providers without applying any business logic.

### Responsibilities

- Authenticate to cloud providers (Azure, AWS)
- Enumerate resources and permissions
- Normalize data into a common internal format
- Store raw discovery data for analysis phase

### Azure Discovery

| Data Type | Source | PowerShell Command |
|-----------|--------|-------------------|
| Role Assignments | RBAC | `Get-AzRoleAssignment -IncludeClassicAdministrators` |
| Role Definitions | RBAC | `Get-AzRoleDefinition` |
| Service Principals | Entra ID | `Get-AzADServicePrincipal` |
| SP Credentials | Entra ID | `Get-AzADSpCredential` |
| Managed Identities | ARM | Via role assignment ObjectType |
| Subscriptions | ARM | `Get-AzSubscription` |

### AWS Discovery

| Data Type | Source | PowerShell Command |
|-----------|--------|-------------------|
| IAM Users | IAM | `Get-IAMUser` |
| IAM Roles | IAM | `Get-IAMRole` |
| IAM Policies | IAM | `Get-IAMPolicy` |
| Policy Documents | IAM | `Get-IAMPolicyVersion` |
| Access Keys | IAM | `Get-IAMAccessKey` |
| Last Used Info | IAM | `Get-IAMAccessKeyLastUsed` |

### Discovery Output Schema

See [`schemas/discovery-output.schema.json`](../schemas/discovery-output.schema.json) for the complete JSON Schema.

```json
{
  "provider": "Azure",
  "scope": {
    "id": "subscription-id",
    "type": "Subscription",
    "name": "Production"
  },
  "discovered_at": "2026-01-19T14:30:00.000Z",
  "data": {
    "roleAssignments": [...],
    "roleDefinitions": [...],
    "servicePrincipals": [...],
    "servicePrincipalCredentials": [...]
  }
}
```

---

## Phase 2: Analysis

**Purpose**: Apply detection rules to discovery data and identify security issues.

### Responsibilities

- Load discovery data from Phase 1
- Execute detection rules against the data
- Classify findings by severity
- Preserve evidence for each finding

### Rule Structure

Rules are defined in JSON following [`schemas/rule-definition.schema.json`](../schemas/rule-definition.schema.json).

Each rule is a self-contained detection that:
1. Has a unique ID and metadata
2. Specifies required data sources
3. Defines detection logic (query or script)
4. Returns findings with severity and evidence

```json
{
  "id": "AZURE-RBAC-001",
  "name": "Orphaned Role Assignment",
  "description": "Detects role assignments that reference deleted identities",
  "severity_id": 4,
  "severity": "High",
  "confidence_id": 3,
  "provider": "Azure",
  "category": "Identity Hygiene",
  "version": "1.0.0",
  "detection": {
    "data_sources": ["roleAssignments"],
    "logic": "query",
    "conditions": [
      { "field": "ObjectType", "operator": "eq", "value": "Unknown" }
    ]
  },
  "remediation": {
    "description": "Remove the orphaned role assignment",
    "references": ["https://learn.microsoft.com/..."]
  }
}
```

### Detection Categories

| Category | Description | Example Rules |
|----------|-------------|---------------|
| Permission Issues | Over-privileged access | Wildcard permissions, subscription-level Owner |
| Identity Hygiene | Stale or orphaned identities | Orphaned assignments, unused credentials |
| Access Risks | Dangerous access patterns | Super identities, cross-account trust |

### MVP Detection Rules

| ID | Name | Severity | Description |
|----|------|----------|-------------|
| AZURE-RBAC-001 | Orphaned Role Assignment | High | ObjectType = "Unknown" |
| AZURE-RBAC-002 | Subscription-Level Owner | High | Owner at subscription scope |
| AZURE-RBAC-003 | Wildcard Custom Role | Critical | Actions contains "*" |
| AZURE-RBAC-004 | Classic Administrator | Medium | Legacy admin roles |
| AZURE-SP-001 | Password-Only Service Principal | High | No certificate credentials |
| AWS-IAM-001 | Unused IAM User | Medium | No activity in 90+ days |
| AWS-IAM-002 | Wildcard Policy | Critical | Resource or Action = "*" |
| AWS-IAM-003 | Inactive Access Key | Medium | Not used in 90+ days |

### Analysis Output

Each rule produces findings in **OCSF IAM Analysis Finding** format (class_uid 2008).

See [DATA-MODEL.md](DATA-MODEL.md) for the complete schema specification.

---

## Phase 3: Reporting

**Purpose**: Transform analysis results into the final JSON output format optimized for LLM consumption.

### Responsibilities

- Format findings as OCSF IAM Analysis Finding objects
- Calculate summary statistics
- Add scan metadata wrapper
- Expose via REST API

### Data Model

Findings use the **Open Cybersecurity Schema Framework (OCSF)** v1.7.0, specifically the **IAM Analysis Finding [2008]** event class.

**JSON Schemas:**
- [`schemas/finding.schema.json`](../schemas/finding.schema.json) - Individual finding (OCSF)
- [`schemas/scan-report.schema.json`](../schemas/scan-report.schema.json) - Complete scan report

See [DATA-MODEL.md](DATA-MODEL.md) for detailed documentation.

### Output Structure

```json
{
  "scan_metadata": {
    "scan_id": "550e8400-e29b-41d4-a716-446655440000",
    "instance_id": "psu-prod-01",
    "scan_timestamp": "2026-01-19T14:30:00.000Z",
    "scan_duration_ms": 45230,
    "provider": "Azure",
    "scope": { "id": "subscription-id", "type": "Subscription" },
    "status": "completed"
  },
  "findings": [
    { /* OCSF IAM Analysis Finding (class_uid: 2008) */ }
  ],
  "summary": {
    "total_findings": 47,
    "by_severity": { "critical": 2, "high": 15, "medium": 20, "low": 10 },
    "by_category": { "Permission Issues": 12, "Identity Hygiene": 25, "Access Risks": 10 }
  }
}
```

---

## REST API

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/scans` | Trigger a new scan |
| `GET` | `/api/scans` | List all scans |
| `GET` | `/api/scans/{scanId}` | Get scan status |
| `GET` | `/api/scans/{scanId}/results` | Get scan results (JSON report) |
| `DELETE` | `/api/scans/{scanId}` | Delete scan |
| `GET` | `/api/health` | Health check |
| `GET` | `/api/providers` | List configured providers |

### Scan Lifecycle

```
POST /api/scans { provider: "azure", scope: "sub-id" }
    │
    ▼
┌──────────┐
│ pending  │
└────┬─────┘
     │
     ▼
┌──────────┐    ┌───────────┐    ┌───────────┐
│ running  │ -> │ Discovery │ -> │ Analysis  │ -> Reporting
└────┬─────┘    └───────────┘    └───────────┘
     │
     ▼
┌───────────┐         ┌────────┐
│ completed │   OR    │ failed │
└───────────┘         └────────┘
```

---

## Module Structure

```
powershell_module/
├── DevolutionsCIEM.psd1          # Module manifest
├── DevolutionsCIEM.psm1          # Module loader
├── Public/
│   ├── Start-CIEMScan.ps1        # Orchestrator
│   ├── Invoke-CIEMDiscovery.ps1  # Phase 1 entry point
│   ├── Invoke-CIEMAnalysis.ps1   # Phase 2 entry point
│   ├── Invoke-CIEMReport.ps1     # Phase 3 entry point
│   └── Get-CIEMFinding.ps1       # Query findings
├── Private/
│   ├── Discovery/
│   │   ├── Get-AzureRoleAssignments.ps1
│   │   ├── Get-AzureRoleDefinitions.ps1
│   │   ├── Get-AzureServicePrincipals.ps1
│   │   ├── Get-AwsIamUsers.ps1
│   │   └── Get-AwsIamRoles.ps1
│   ├── Analysis/
│   │   ├── Rules/
│   │   │   ├── AZURE-RBAC-001.ps1
│   │   │   ├── AZURE-RBAC-002.ps1
│   │   │   └── ...
│   │   └── Invoke-DetectionRule.ps1
│   └── Reporting/
│       ├── Format-Finding.ps1
│       └── New-ScanReport.ps1
└── Rules/
    └── rules.json                # Rule definitions metadata
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         Start-CIEMScan                          │
│  (Orchestrator - coordinates all three phases)                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Invoke-CIEMDiscovery                        │
│  Input:  Provider, Scope, Credentials                           │
│  Output: $DiscoveryData (hashtable with all raw cloud data)     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Invoke-CIEMAnalysis                        │
│  Input:  $DiscoveryData                                         │
│  Output: $Findings (array of finding objects)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Invoke-CIEMReport                         │
│  Input:  $DiscoveryData, $Findings, $ScanMetadata               │
│  Output: Final JSON report                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Provider Abstraction

To support multiple cloud providers, each provider implements a discovery interface:

```powershell
# Provider interface contract
[PSCustomObject]@{
    Name        = 'Azure'
    Initialize  = { param($Credentials) ... }
    Discover    = { param($Scope) ... }
    GetRules    = { ... }
}
```

This enables:
- Adding new providers without changing core logic
- Provider-specific discovery implementations
- Shared analysis and reporting infrastructure

---

## Configuration

Configuration is managed through PSU variables (not in code):

| Setting | Description |
|---------|-------------|
| `CIEM_AZURE_TENANT_ID` | Azure tenant ID |
| `CIEM_AZURE_CLIENT_ID` | Service principal app ID |
| `CIEM_AZURE_CLIENT_SECRET` | Service principal secret |
| `CIEM_AWS_ACCESS_KEY` | AWS access key ID |
| `CIEM_AWS_SECRET_KEY` | AWS secret access key |
| `CIEM_AWS_REGION` | Default AWS region |
