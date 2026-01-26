# Devolutions CIEM - Data Model

## Overview

Devolutions CIEM uses the **Open Cybersecurity Schema Framework (OCSF)** as the standard format for findings output. Specifically, we use the **IAM Analysis Finding [2008]** event class, which is purpose-built for Cloud Infrastructure Entitlement Management (CIEM) use cases.

## JSON Schemas

All data structures are defined as JSON Schema (draft 2020-12):

| Schema | Purpose |
|--------|---------|
| [`rule-definition.schema.json`](../schemas/rule-definition.schema.json) | Detection rule definitions |
| [`discovery-output.schema.json`](../schemas/discovery-output.schema.json) | Phase 1 Discovery output |
| [`finding.schema.json`](../schemas/finding.schema.json) | OCSF IAM Analysis Finding |
| [`scan-report.schema.json`](../schemas/scan-report.schema.json) | Complete scan report wrapper |

## Why OCSF?

| Benefit | Description |
|---------|-------------|
| **Industry Standard** | Backed by AWS, Splunk, IBM, and 100+ security vendors |
| **IAM-Specific** | Class 2008 designed specifically for IAM/CIEM analysis |
| **Vendor-Agnostic** | Works with Azure, AWS, GCP, and future providers |
| **LLM-Friendly** | Structured format that AI models understand well |
| **Extensible** | Profiles for Cloud, Container, Host contexts |
| **Well-Documented** | Full schema at [schema.ocsf.io](https://schema.ocsf.io) |

## OCSF Version

This project targets **OCSF v1.7.0**.

---

## IAM Analysis Finding Structure

The IAM Analysis Finding class evaluates IAM policies, access patterns, and configurations for security risks. It supports both:

- **Identity-centric analysis**: What can this identity do?
- **Resource-centric analysis**: Who can access this resource?

### Core Schema

```json
{
  "class_uid": 2008,
  "class_name": "IAM Analysis Finding",
  "category_uid": 2,
  "category_name": "Findings",
  "activity_id": 1,
  "activity_name": "Create",
  "type_uid": 200801,

  "time": "2026-01-19T14:30:00.000Z",
  "timezone_offset": 0,

  "severity_id": 4,
  "severity": "High",

  "status_id": 1,
  "status": "New",

  "finding_info": { },
  "cloud": { },
  "user": { },
  "resources": [ ],
  "permission_analysis_results": [ ],
  "remediation": { },
  "metadata": { }
}
```

---

## Required Attributes

### `finding_info` - Finding Information

Core details about the finding.

```json
{
  "finding_info": {
    "uid": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "title": "Orphaned Role Assignment",
    "desc": "Role assignment points to a deleted identity (ObjectType = Unknown)",
    "created_time": "2026-01-19T14:30:00.000Z",
    "modified_time": "2026-01-19T14:30:00.000Z",
    "first_seen_time": "2026-01-19T14:30:00.000Z",
    "last_seen_time": "2026-01-19T14:30:00.000Z",
    "product": {
      "name": "Devolutions CIEM",
      "vendor_name": "Devolutions",
      "version": "0.1.0"
    },
    "types": ["Identity Hygiene"],
    "analytic": {
      "uid": "AZURE-RBAC-001",
      "name": "Orphaned Role Assignment Detection",
      "type": "Rule",
      "version": "1.0.0"
    }
  }
}
```

### `cloud` - Cloud Environment

Details about the cloud environment where the finding was detected.

```json
{
  "cloud": {
    "provider": "Azure",
    "account": {
      "uid": "12345678-1234-1234-1234-123456789012",
      "name": "Production Subscription",
      "type": "Subscription"
    },
    "region": "eastus",
    "org": {
      "uid": "87654321-4321-4321-4321-210987654321",
      "name": "Contoso Tenant"
    }
  }
}
```

**Provider values**: `Azure`, `AWS`, `GCP`

### `metadata` - Event Metadata

Required context about the event itself.

```json
{
  "metadata": {
    "version": "1.7.0",
    "product": {
      "name": "Devolutions CIEM",
      "vendor_name": "Devolutions",
      "version": "0.1.0",
      "lang": "en"
    },
    "profiles": ["cloud"],
    "uid": "scan-550e8400-e29b-41d4-a716-446655440000"
  }
}
```

---

## Recommended Attributes

### `user` - Identity Being Analyzed

The identity (user, service principal, role, managed identity) that is the subject of the finding.

```json
{
  "user": {
    "uid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "name": "svc-backup-app",
    "type": "ServicePrincipal",
    "type_id": 2,
    "account": {
      "uid": "12345678-1234-1234-1234-123456789012",
      "name": "Production Subscription"
    }
  }
}
```

**User type_id values**:
| ID | Type |
|----|------|
| 0 | Unknown |
| 1 | User |
| 2 | Service/ServicePrincipal |
| 3 | Group |
| 4 | Role |

### `resources` - Affected Resources

Resources involved in the finding.

```json
{
  "resources": [
    {
      "uid": "/subscriptions/12345678.../roleAssignments/abc123",
      "name": "Owner Assignment",
      "type": "Microsoft.Authorization/roleAssignments",
      "cloud_partition": "Azure",
      "region": "global",
      "labels": ["RBAC", "Subscription-Level"],
      "data": {
        "role_definition_name": "Owner",
        "scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
        "principal_type": "Unknown"
      }
    }
  ]
}
```

### `permission_analysis_results` - Permission Analysis

For identity-centric analysis (what can this identity do?).

```json
{
  "permission_analysis_results": [
    {
      "query_type": "EffectivePermissions",
      "privileges": [
        {
          "name": "*",
          "type": "Action",
          "state": "Granted"
        }
      ],
      "policies": [
        {
          "uid": "/providers/Microsoft.Authorization/roleDefinitions/owner-guid",
          "name": "Owner",
          "type": "BuiltInRole",
          "is_managed": true
        }
      ],
      "scope": "/subscriptions/12345678-1234-1234-1234-123456789012"
    }
  ]
}
```

### `remediation` - Fix Guidance

Recommended steps to address the finding.

```json
{
  "remediation": {
    "desc": "Remove the orphaned role assignment to reduce attack surface.",
    "references": [
      "https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-remove"
    ],
    "kb_articles": [
      "Use Remove-AzRoleAssignment to delete orphaned assignments"
    ]
  }
}
```

---

## Severity Scale

OCSF defines a normalized severity scale:

| ID | Name | Description | Use For |
|----|------|-------------|---------|
| 0 | Unknown | Severity unknown | - |
| 1 | Informational | No action required | Audit trails |
| 2 | Low | User decides if action needed | Minor hygiene issues |
| 3 | Medium | Action required, not urgent | Stale credentials, unused roles |
| 4 | High | Action required immediately | Over-privileged access, orphaned admins |
| 5 | Critical | Immediate action, broad scope | Wildcard permissions, super identities |
| 6 | Fatal | Too late for remediation | Confirmed breach indicators |

---

## Risk Level Scale

Separate from severity, risk measures potential impact:

| ID | Level | Description |
|----|-------|-------------|
| 0 | Info | Informational, no risk |
| 1 | Low | Minimal potential impact |
| 2 | Medium | Moderate potential impact |
| 3 | High | Significant potential impact |
| 4 | Critical | Severe potential impact |

---

## Finding Status Lifecycle

| ID | Status | Description |
|----|--------|-------------|
| 1 | New | Finding is new, not yet reviewed |
| 2 | In Progress | Finding is under review |
| 3 | Suppressed | Determined to be benign/false positive |
| 4 | Resolved | Remediated and resolved |
| 5 | Archived | Finding archived |
| 6 | Deleted | Finding deleted (created in error) |

---

## Detection Rule Mapping

Each detection rule maps to OCSF attributes:

| Rule Attribute | OCSF Attribute |
|----------------|----------------|
| Rule ID | `finding_info.analytic.uid` |
| Rule Name | `finding_info.analytic.name` |
| Rule Version | `finding_info.analytic.version` |
| Category | `finding_info.types[]` |
| Severity | `severity_id` |
| Confidence | `confidence_id` |
| Description | `finding_info.desc` |
| Remediation | `remediation.desc` |

---

## Complete Finding Example

```json
{
  "class_uid": 2008,
  "class_name": "IAM Analysis Finding",
  "category_uid": 2,
  "category_name": "Findings",
  "activity_id": 1,
  "activity_name": "Create",
  "type_uid": 200801,
  "type_name": "IAM Analysis Finding: Create",

  "time": "2026-01-19T14:30:00.000Z",
  "timezone_offset": 0,

  "severity_id": 4,
  "severity": "High",
  "confidence_id": 3,
  "confidence": "High",
  "risk_level_id": 3,
  "risk_level": "High",

  "status_id": 1,
  "status": "New",

  "message": "Role assignment for principal 'a1b2c3d4-...' points to a deleted identity",

  "finding_info": {
    "uid": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
    "title": "Orphaned Role Assignment",
    "desc": "A role assignment exists that references a principal (user, group, or service principal) that has been deleted from Entra ID. This creates unnecessary attack surface and indicates poor identity lifecycle management.",
    "created_time": "2026-01-19T14:30:00.000Z",
    "first_seen_time": "2026-01-19T14:30:00.000Z",
    "last_seen_time": "2026-01-19T14:30:00.000Z",
    "product": {
      "name": "Devolutions CIEM",
      "vendor_name": "Devolutions",
      "version": "0.1.0"
    },
    "types": ["Identity Hygiene", "Orphaned Assignment"],
    "analytic": {
      "uid": "AZURE-RBAC-001",
      "name": "Orphaned Role Assignment Detection",
      "type": "Rule",
      "type_id": 1,
      "version": "1.0.0"
    }
  },

  "cloud": {
    "provider": "Azure",
    "account": {
      "uid": "12345678-1234-1234-1234-123456789012",
      "name": "Production Subscription",
      "type": "Subscription",
      "type_id": 10
    },
    "org": {
      "uid": "87654321-4321-4321-4321-210987654321",
      "name": "Contoso"
    }
  },

  "user": {
    "uid": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "name": "Unknown (Deleted)",
    "type": "Unknown",
    "type_id": 0
  },

  "resources": [
    {
      "uid": "/subscriptions/12345678-1234-1234-1234-123456789012/providers/Microsoft.Authorization/roleAssignments/abc12345-def6-7890-ghij-klmnopqrstuv",
      "name": "Contributor Assignment",
      "type": "Microsoft.Authorization/roleAssignments",
      "cloud_partition": "Azure",
      "data": {
        "role_definition_name": "Contributor",
        "role_definition_id": "/subscriptions/12345678.../providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c",
        "scope": "/subscriptions/12345678-1234-1234-1234-123456789012",
        "principal_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "principal_type": "Unknown",
        "created_on": "2024-06-15T10:30:00.000Z"
      }
    }
  ],

  "remediation": {
    "desc": "Remove the orphaned role assignment using Azure Portal or PowerShell.",
    "kb_articles": [
      "Remove-AzRoleAssignment -ObjectId 'a1b2c3d4-...' -RoleDefinitionName 'Contributor' -Scope '/subscriptions/12345678-...'"
    ],
    "references": [
      "https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-remove"
    ]
  },

  "metadata": {
    "version": "1.7.0",
    "product": {
      "name": "Devolutions CIEM",
      "vendor_name": "Devolutions",
      "version": "0.1.0",
      "lang": "en"
    },
    "profiles": ["cloud"],
    "uid": "scan-550e8400-e29b-41d4-a716-446655440000",
    "logged_time": "2026-01-19T14:30:05.000Z"
  }
}
```

---

## Scan Report Wrapper

Individual findings are wrapped in a scan report for the REST API:

```json
{
  "scan_metadata": {
    "scan_id": "550e8400-e29b-41d4-a716-446655440000",
    "instance_id": "psu-prod-01",
    "scan_timestamp": "2026-01-19T14:30:00.000Z",
    "scan_duration_ms": 45230,
    "provider": "Azure",
    "scope": "12345678-1234-1234-1234-123456789012",
    "status": "completed"
  },
  "findings": [
    { /* OCSF IAM Analysis Finding */ },
    { /* OCSF IAM Analysis Finding */ }
  ],
  "summary": {
    "total_findings": 47,
    "by_severity": {
      "critical": 2,
      "high": 15,
      "medium": 20,
      "low": 10
    },
    "by_category": {
      "Permission Issues": 12,
      "Identity Hygiene": 25,
      "Access Risks": 10
    },
    "by_status": {
      "new": 47
    }
  }
}
```

---

## References

- [OCSF Schema Browser](https://schema.ocsf.io)
- [IAM Analysis Finding Class](https://schema.ocsf.io/1.7.0/classes/iam_analysis_finding)
- [OCSF GitHub](https://github.com/ocsf)
- [OCSF Documentation](https://github.com/ocsf/ocsf-docs)
