---
name: devolutions-pam
description: |
  Devolutions PAM (Privileged Access Management) domain knowledge from official documentation.
  Use when discussing or working with PAM concepts, Devolutions PAM features, providers,
  checkout/check-in workflows, password rotation, JIT elevation, account discovery, scan
  configurations, vaults, propagation scripts, or any Devolutions Server/Hub PAM functionality.
  Triggers: "PAM", "privileged access", "Devolutions PAM", "Devolutions Server PAM",
  "Hub Business PAM", "PAM provider", "managed provider", "AnyIdentity", "identity provider",
  "password rotation", "checkout", "check-in", "JIT elevation", "account discovery",
  "PAM vault", "propagation", "scan configuration", "privileged account", "session recording",
  "PAM report".
---

<objective>
Provide comprehensive Devolutions PAM domain knowledge so Codex can accurately answer questions
about PAM concepts, guide users through provider configuration, explain checkout/check-in workflows,
and reference official documentation for Devolutions Server, Hub Business, and RDM PAM features.
</objective>

<quick_start>
This is a background knowledge skill. When PAM-related topics arise, reference the key concepts
below for core understanding. For detailed procedures and configuration steps, read the corresponding
reference files linked in each section.
</quick_start>

<success_criteria>
- Answers about Devolutions PAM are grounded in official documentation, not assumptions
- Provider types, workflows, and concepts are described accurately per the reference material
- Users are pointed to specific reference files for detailed implementation steps
</success_criteria>

<overview>
Devolutions PAM is a privileged access management solution integrated into Devolutions Server and
Devolutions Hub Business. It manages the full lifecycle of privileged accounts: discovery, credential
storage, password rotation, checkout/check-in access control, JIT elevation, session recording, and
compliance reporting.

PAM is also available through Remote Desktop Manager (RDM) as a client interface.

Key strategic context: Devolutions PAM complements CIEM (Cloud Infrastructure Entitlement Management)
practices. CIEM identifies excessive permissions and entitlement risks; PAM provides the enforcement
layer to manage and control privileged access to those systems.
</overview>

<key-concepts>

<providers>
A provider is a logical object representing an external identity provider. It orchestrates authentication,
policy enforcement, and identity validation between Devolutions PAM and the identity source.

Three provider types:
- **Managed** — Fully integrated, built and maintained by Devolutions. Support full lifecycle: discovery, heartbeat, password rotation.
  - Domain user, Entra ID user, AWS IAM, Local SSH user, SSH key, SQL Server user, PostgreSQL user, Windows user
- **Unmanaged (password reset only)** — Manual configuration, simpler/legacy systems. Password reset only.
  - MySQL user, Cisco user, Oracle user
- **Custom (AnyIdentity)** — User-defined templates with custom action scripts for discovery, heartbeat, and rotation.
  - Examples: Azure Key Vault secret, SQL Server login, Windows local account

For detailed provider setup: [references/server/providers.md](references/server/providers.md)
For managed providers: [references/server/providers/managed-providers.md](references/server/providers/managed-providers.md)
For custom providers: [references/server/providers/anyidentity-providers.md](references/server/providers/anyidentity-providers.md)
</providers>

<password-rotation>
Automated process of changing stored passwords on a schedule to reduce credential exposure risk.

Lifecycle: discover accounts → compare stored vs actual passwords (heartbeat) → rotate when needed → store securely.

Password rotation vs reset:
- **Rotation**: Recurring, proactive, automated, scheduled
- **Reset**: One-time, reactive, manual, triggered by specific events

For details: [references/concepts/password-rotation.md](references/concepts/password-rotation.md)
</password-rotation>

<checkout-checkin>
Check-out reserves a privileged account for exclusive use (locks it from others).
Check-in releases the lock, typically followed by password rotation.

Check-in modes: manual, automatic (end of checkout period), or on session close (RDM).

With JIT access, group/role memberships are temporarily modified at checkout and restored at check-in.

Checkout can require approval workflows.

For server checkout: [references/server/checkout-process/request-checkout.md](references/server/checkout-process/request-checkout.md) and [references/server/checkout-process/approve-checkout.md](references/server/checkout-process/approve-checkout.md)
For hub checkout: [references/hub/privileged-accounts.md](references/hub/privileged-accounts.md)
</checkout-checkin>

<jit-elevation>
Just-In-Time (JIT) elevation temporarily grants elevated privileges only when needed.

Two modes:
- **Standard accounts**: Adds group memberships/roles at checkout, removes at check-in
- **Zero-Standing Privilege (ZSP) accounts**: No memberships at rest; fully assigned at checkout, fully revoked at check-in

For details: [references/concepts/jit-elevation.md](references/concepts/jit-elevation.md)
For JIT provisioning: [references/concepts/jit-provisioning.md](references/concepts/jit-provisioning.md)
For server JIT: [references/server/just-in-time.md](references/server/just-in-time.md)
</jit-elevation>

<account-discovery>
Scan configurations discover privileged accounts from identity providers. Supported discovery types:
- Entra ID user accounts
- Domain accounts
- SQL accounts
- SSH accounts
- Windows user accounts

For scan configurations: [references/server/scan-configurations.md](references/server/scan-configurations.md)
For getting started: [references/server/getting-started/create-run-scan-configuration.md](references/server/getting-started/create-run-scan-configuration.md)
</account-discovery>

<vaults>
PAM vaults are dedicated containers for privileged accounts, separate from standard credential vaults.
They provide isolation, role-based access control, and audit trails.

For server vaults: [references/server/pam-vaults.md](references/server/pam-vaults.md)
For hub vaults: [references/hub/pam-vaults.md](references/hub/pam-vaults.md)
</vaults>

<propagation-scripts>
After password rotation, propagation scripts push the new password to dependent systems
(services, scheduled tasks, IIS app pools, etc.) that use the rotated credential.

For details: [references/server/propagation-scripts.md](references/server/propagation-scripts.md)
For creating templates: [references/server/propagation-scripts/create-script-template.md](references/server/propagation-scripts/create-script-template.md)
</propagation-scripts>

<privileged-accounts>
Account types managed by PAM:
- Application accounts (background software operations)
- Domain administrator accounts (AD domain/user control)
- Emergency/break-glass accounts (temporary elevated access)
- Local administrator accounts (individual machine admin)
- Root/administrator accounts (system-level software install/config)
- Service accounts (background processes, rarely human-used)
- System accounts (OS-level operations)

For details: [references/concepts/privileged-account.md](references/concepts/privileged-account.md)
</privileged-accounts>

</key-concepts>

<deployment-platforms>

<devolutions-server>
Full PAM implementation with:
- Provider management (managed, unmanaged, custom)
- Account discovery via scan configurations
- Password rotation and heartbeat
- Checkout/check-in with approval workflows
- JIT elevation
- Propagation scripts
- PAM reports and usage policies
- Roles and permissions

For complete server PAM docs: [references/server/](references/server/)
For getting started: [references/server/getting-started.md](references/server/getting-started.md)
</devolutions-server>

<devolutions-hub-business>
Cloud-hosted PAM with:
- Privileged account management
- Request/approve access workflows
- Password rotation policies
- PAM vaults
- Privileged access reports
- Provider support (AWS IAM, Entra ID, Cisco, Domain, SSH, MySQL, Oracle, PostgreSQL)
- Session recording

For complete hub PAM docs: [references/hub/](references/hub/)
</devolutions-hub-business>

<remote-desktop-manager>
Client interface for PAM with:
- PAM dashboard
- Privileged account management
- Privileged access risk assessment
- Privileged session monitoring

For RDM PAM docs: [references/rdm/](references/rdm/)
</remote-desktop-manager>

</deployment-platforms>

<additional-concepts>
For any of these topics, read the corresponding reference file:

- Account lifecycle policy: [references/concepts/account-lifecycle-policy.md](references/concepts/account-lifecycle-policy.md)
- Action scripts (custom providers): [references/concepts/action-script.md](references/concepts/action-script.md)
- Agentless deployment: [references/concepts/agentless-deployment.md](references/concepts/agentless-deployment.md)
- AnyIdentity templates: [references/concepts/anyidentity-template.md](references/concepts/anyidentity-template.md)
- CI/CD automation: [references/concepts/cicd-automation.md](references/concepts/cicd-automation.md)
- CIEM: [references/concepts/cloud-infrastructure-entitlement-management.md](references/concepts/cloud-infrastructure-entitlement-management.md)
- Compliance reporting: [references/concepts/compliance-reporting.md](references/concepts/compliance-reporting.md)
- Credential management: [references/concepts/credential-management.md](references/concepts/credential-management.md)
- Dual account principle: [references/concepts/dual-account-principle.md](references/concepts/dual-account-principle.md)
- Identity providers: [references/concepts/identity-providers.md](references/concepts/identity-providers.md)
- Least privilege: [references/concepts/least-privilege.md](references/concepts/least-privilege.md)
- PAM maturity model: [references/concepts/pam-maturity.md](references/concepts/pam-maturity.md)
- PEDM (Privilege Elevation and Delegation): [references/concepts/privilege-elevation-delegation-management.md](references/concepts/privilege-elevation-delegation-management.md)
- Privileged remote access: [references/concepts/privileged-remote-access.md](references/concepts/privileged-remote-access.md)
- Privileged sessions: [references/concepts/privileged-session.md](references/concepts/privileged-session.md)
- Privileged task automation: [references/concepts/privileged-task-automation.md](references/concepts/privileged-task-automation.md)
- User behavior analytics: [references/concepts/privileged-user-behavior-analytics.md](references/concepts/privileged-user-behavior-analytics.md)
- Reporting and dashboards: [references/concepts/reporting-dashboards.md](references/concepts/reporting-dashboards.md)
- Secrets management: [references/concepts/secrets-management.md](references/concepts/secrets-management.md)
- Session management: [references/concepts/session-management.md](references/concepts/session-management.md)
- Session recording: [references/concepts/session-recording.md](references/concepts/session-recording.md)
- Zero standing privileges: [references/concepts/zero-standing-privileges.md](references/concepts/zero-standing-privileges.md)
</additional-concepts>

<knowledge-base>
How-to articles, troubleshooting guides, and knowledge base articles are available for practical implementation questions.

- How-to articles: [references/kb/how-to-articles/](references/kb/how-to-articles/)
- Troubleshooting: [references/kb/troubleshooting-articles/](references/kb/troubleshooting-articles/)
- Knowledge base: [references/kb/knowledge-base/](references/kb/knowledge-base/)

Key how-to topics include:
- Configuring PAM providers and password rotation
- Creating Entra ID and Windows user providers
- JIT elevation and provisioning setup
- Quick AD PAM deployment
- Importing computers from domain providers
- Least privileges for AD providers
</knowledge-base>

<validated>
Validated by validate-skill on 2026-02-18 12:48
</validated>
