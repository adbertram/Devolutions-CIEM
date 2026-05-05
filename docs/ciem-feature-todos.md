# CIEM Feature Todos

This document is a feature backlog for CIEM discovery, analysis, and action workflow ideas.

Discovery-only features are the default. Write/action features must not perform cloud, IdP, PAM, ticketing, or infrastructure write operations unless the user explicitly re-scopes the work and identifies the target environment.

## Feature Principles

- Prefer identity-first CIEM value over generic CSPM coverage.
- Keep cloud and PAM systems read-only during discovery workflows.
- Show evidence for every finding: source API, identity, entitlement, scope, inherited path, activity timestamp, and risk reason.
- Output recommendations as preview artifacts unless the user explicitly asks for an action workflow.
- Treat Devolutions PAM integration as fit analysis and routing context unless write operations have been explicitly requested.
- Treat the dashboard as an investigation and progress-measurement surface, not the only place risks are discovered.

## Product Feedback

Security team feedback: the dashboard is interesting as an investigation tool, but the missing product piece is surfacing new risk and pushing that signal into systems where security teams already work, such as a SIEM or alert management system. The dashboard should become the drill-in destination after a change in exposure has alerted the team, rather than assuming analysts or IT administrators will manually check CIEM on a recurring calendar task.

Product implications:

- Prioritize exposure-change detection over static dashboard browsing.
- Produce alert-ready findings with enough evidence to route into SIEM, alert management, ticketing, or PSU automation workflows.
- Keep the dashboard valuable for teams already living in PSU by making it fast to pivot from an alert into investigation.
- Support project-based work, especially PAM implementation, by showing exposure baseline, remediation progress, remaining blockers, and before/after evidence.

Implementation framing from follow-up response: CIEM currently scans an Azure tenant, stores discovered data, and parses that data with rules to build the environment hierarchy, identify attack paths, and surface risk. Ongoing risk detection requires scheduled discovery scans, then comparison of newly discovered data against prior snapshots. Notification delivery should be modeled as an optional connector feature wired to discovery results, with supported destinations such as email, SIEM messages, alert management systems, webhooks, ticketing, or PSU automation. PAM value should be evaluated as an add-on path by identifying where CIEM findings create better PAM adoption, JIT migration, remediation tracking, and exposure reduction.

## Discovery Recommended Build Order

1. Scheduled discovery scans
2. Exposure change detection
3. AWS effective access graph
4. Least-privilege recommendation preview
5. Privilege drift detection
6. Sensitive resource access inventory
7. Expanded attack path patterns
8. Discovery coverage report

## Discovery-Only Features

### Effective Permission Explorer

Show who can do what to which resource across direct role assignments, group inheritance, app roles, directory roles, inherited cloud scopes, trust relationships, and resource policies.

### Unused Privilege Detection

Identify identities with privileged permissions that have no matching usage evidence in sign-in logs, Azure activity logs, AWS CloudTrail, or equivalent audit data.

### Overprivileged Role Analysis

Detect broad roles such as Azure Owner, Contributor, User Access Administrator, AWS AdministratorAccess, wildcard IAM policies, permission-management roles, and high-risk custom roles. Output suggested reductions as text only.

### Least-Privilege Recommendation Preview

Generate proposed Azure custom role JSON or AWS IAM policy JSON as a preview artifact. Do not create, update, assign, or delete any role or policy.

### AWS Effective Access Graph

Read IAM users, roles, groups, inline policies, managed policies, permission boundaries, trust policies, resource policies, SCPs, and IAM Identity Center assignments. Compute effective access locally.

### Privilege Inheritance Map

Show how each identity receives access: direct assignment, group membership, nested group, role-assignable group, app role assignment, directory role, AWS group, AWS role assumption, SCP, or resource policy.

### Privileged Group Risk

Find privileged groups, nested privileged groups, guest members, disabled members, stale members, ownerless groups, and groups that grant admin-equivalent cloud access.

### Non-Human Identity Inventory

Inventory service principals, managed identities, AWS roles, access keys, certificate metadata, secret metadata, workload identities, and CI/CD principals. Flag stale, overprivileged, ownerless, or externally trusted identities.

### Sensitive Resource Access Inventory

Mark high-value targets such as Key Vaults, storage accounts, SQL databases, production subscriptions, backups, secrets, private endpoints, and critical-tagged assets. Show every identity that can read, write, manage, grant access to, or exfiltrate data from them.

### Public Exposure And Privilege Correlation

Discover public VMs, public IPs, internet-facing apps, open management ports, public buckets or storage, and correlate them with attached identities or reachable privileged resources.

### Attack Path Pattern Expansion

Add read-only attack path detections:

- Public workload with privileged managed identity
- Public workload with Key Vault access
- CI/CD identity with subscription owner
- Guest user with privileged group path
- Service principal that can grant app permissions
- Identity that can modify role assignments
- Storage or data access path from public workload
- AKS workload identity to cloud privilege

### Identity Activity Timeline

For each identity, show last interactive sign-in, last non-interactive sign-in, token or activity event, role assignment change, key or certificate age, and last observed cloud API usage.

### Privilege Drift Detection

Compare two local discovery snapshots and report changes:

- New privileged assignment
- Removed privileged assignment
- Guest gained access
- Public resource gained managed identity
- New attack path appeared
- Dormant identity became privileged

### Scheduled Discovery Scans

Run discovery on a schedule so CIEM can detect new exposure without requiring a user to manually start scans or check the dashboard. Scheduled scans should use the same discovery pipeline as manual scans, persist scan metadata, record success or failure evidence, and make the resulting snapshot available for exposure-change comparison.

### Exposure Change Detection

Compare discovery snapshots and generate alert-ready signal candidates when exposure changes. Include new risk, removed risk, risk score increase, impacted identity, impacted resource, first seen timestamp, previous state, current state, and evidence. This feature should only produce local findings and outbound-ready payload previews unless an integration workflow is explicitly scoped.

### Risk Evidence View

Every finding should show the data behind the conclusion: source API, role name, scope, inherited path, last activity timestamp, resource sensitivity, and score inputs.

### Cloud-To-IdP Correlation

Read Okta, Entra ID, or other IdP group membership and map IdP groups to cloud entitlements. Do not change groups, users, assignments, or apps.

### Custom Role Risk Analysis

Parse Azure custom roles and AWS custom policies to identify wildcard actions, privilege escalation actions, data exfiltration permissions, permission-management rights, and dangerous trust relationships.

### Role Assignment Blast Radius

For any role assignment, show all impacted resources beneath that scope and classify the access level: read, write, manage, permission-admin, data-access, or secret-access.

### Dormant Access Review Report

Generate reviewer-ready reports for dormant privileged identities, guest privileged access, non-human privileged access, ownerless identities, and access to sensitive resources.

### Discovery Coverage Report

Show what data was collected and what could not be collected because of missing read permissions, disabled audit logs, unavailable premium features, inaccessible subscriptions, or inaccessible accounts.

### Read-Only PAM Fit Analysis

Report which findings are PAM candidates without creating PAM records or changing access:

- Should be JIT-only
- Should require approval
- Should require session recording
- Should use secret rotation
- Should be reviewed by owner

### PAM Implementation Progress View

Track project progress for PAM implementation and entitlement cleanup. Show exposure baseline, current exposure, risk burn-down, findings converted to PAM candidates, remaining privileged standing access, accepted exceptions, before/after evidence for stakeholders, and where CIEM findings increase PAM value.

## Write Operation Guardrails

These ideas intentionally perform actions. Do not implement or execute them from the discovery backlog alone.

- Require explicit user scope before implementing: target provider, target environment, allowed operations, and rollback expectation.
- Start every write workflow with preview, validation, and confirmation steps.
- Prefer creating a proposed change record before changing cloud state.
- Log every write operation with actor, target, before state, after state, and correlation ID.
- Never hide failed writes behind fallback behavior. Fail clearly and preserve evidence.
- Keep action features narrow: one action, one object type, one target scope.

## Action Recommended Build Order

1. Outbound risk signal delivery
2. Finding-to-action queue
3. PAM-backed JIT request workflow
4. Manual approval and evidence capture
5. Least-privilege change package generation
6. Controlled role or policy update workflow
7. Automatic expiration and revocation workflow

## Write/Action Features

### Outbound Risk Signal Delivery

Push new exposure-change signals to an explicitly scoped external system through a connector wired to discovery results. Supported connector targets can include email, SIEM message delivery, alert management platforms, ticketing queues, webhook endpoints, or PSU automation. Payloads should include finding evidence, previous state, current state, severity, owner or routing context when known, dashboard drill-in link, and verification steps.

### Finding-To-Action Queue

Create an action queue that converts findings into tracked remediation candidates. Each item should include the finding, impacted identity, target resource, recommended action, owner, status, approval state, and evidence. This can start as local state and later integrate with PAM or ticketing systems.

### PAM-Backed JIT Access Requests

Create a workflow that lets users request temporary privileged access through Devolutions PAM. The workflow should support request, approval, grant, expiration, revocation, audit evidence, and mapping back to the original CIEM finding.

### Standing Privilege To JIT Migration

For risky standing assignments, generate and execute a controlled migration plan: remove the standing role assignment after a matching JIT access path exists. The workflow must validate that a replacement access path exists before removing standing access.

### Least-Privilege Role Creation

Create Azure custom roles or AWS IAM policies from least-privilege recommendations. The workflow should preview the generated definition, validate syntax, show the permission diff, create the role or policy, and record the created object ID.

### Role Assignment Replacement

Replace broad assignments with narrower roles or policies. The workflow should create or select the replacement role, add the new assignment, validate access coverage, then remove the old broad assignment.

### Privileged Assignment Revocation

Remove stale, dormant, guest, disabled, or excessive privileged role assignments. The workflow should require explicit target selection and preserve before/after evidence for audit.

### Temporary Access Expiration

Track temporary cloud assignments created by CIEM/PAM workflows and remove them automatically at expiration. Include renewal, owner approval, and expiry evidence.

### PAM Candidate Onboarding

Create PAM records for identities, secrets, privileged accounts, or resources that CIEM identifies as PAM candidates. This should map CIEM evidence to PAM fields and link the PAM object back to the finding.

### Secret Rotation Workflow

For secrets, access keys, certificates, or service principal credentials identified as stale or risky, trigger a managed rotation workflow through PAM or the cloud provider. Include validation that dependent apps have moved to the new credential before revoking the old one.

### Ticket Creation And Sync

Create Jira, ServiceNow, or other ticketing records for findings and sync status back to CIEM. Tickets should include finding evidence, recommended action, owner, severity, due date, and verification steps.

### Notification And Approval Routing

Send Slack, Teams, or email approval requests to resource owners or security reviewers. Approval results should be stored with the finding and used to gate write operations.

### Policy-As-Code Pull Requests

Generate pull requests against Terraform, Bicep, ARM, or CloudFormation repositories for least-privilege changes. CIEM should write the proposed code change and attach finding evidence to the PR body.

### Cloud Guardrail Deployment

Deploy preventive guardrails such as Azure Policy, AWS SCPs, or IAM permission boundaries that block risky privilege patterns. Each guardrail should start from a finding pattern and include preview, impact analysis, and rollback steps.

### Attack Path Auto-Containment

For critical attack paths, execute a containment action such as removing a public management port, disabling a risky assignment, or moving the identity to JIT-only access. This should require explicit enablement and must preserve evidence.

### Identity Disable Or Quarantine

Disable, block, or quarantine identities that match high-confidence risk patterns such as disabled-but-privileged inconsistency, compromised account signal, stale privileged guest, or orphaned non-human identity. This is high-impact and must require explicit target confirmation.

### Ownership Metadata Updates

Write owner, app, environment, business unit, exception, or review metadata back into CIEM, cloud tags, PAM records, or ticketing systems. This supports accountability and access review workflows.

### Access Review Campaigns

Create review campaigns for privileged identities, guest access, non-human identities, and sensitive resource access. Campaigns should collect approve/remove decisions and optionally execute approved removals.

### Exception Management

Create time-bound exceptions for accepted risks. Exceptions should include owner, justification, expiration date, compensating control, and automatic re-open when expired.

### Remediation Verification

After a write operation, re-run the relevant discovery or targeted validation and close or update the action item only when the original evidence no longer reproduces the risk.
