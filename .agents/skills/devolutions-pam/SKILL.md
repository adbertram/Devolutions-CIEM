---
name: devolutions-pam
description: |
  MANDATORY: Official Devolutions PAM domain knowledge for Devolutions Server, Hub Business/Cloud,
  Gateway, RDM, providers, vaults, checkout/check-in, rotation, JIT, discovery,
  password propagation, access brokering, reports, package requirements, and integrations.
  Use for CIEM-to-PAM handoffs, PAM features, or Devolutions PAM implementation details.
  Triggers: "PAM", "privileged access", "Devolutions PAM", "Server PAM", "Hub PAM",
  "Devolutions Cloud PAM", "PAM provider", "managed provider", "custom PAM provider",
  "AnyIdentity", "access brokering", "checkout", "check-in", "JIT elevation",
  "PAM vault", "password propagation", "session recording", "PAM report", "PAM package",
  "Kubernetes Operator", "Terraform provider", "Ansible module", "CyberArk", "BeyondTrust",
  "Delinea".
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
Devolutions PAM is a privileged access management solution across the Devolutions ecosystem:
Devolutions Server, Devolutions Hub Business / Devolutions Cloud, Devolutions Gateway,
Remote Desktop Manager (RDM), Devolutions Workspace, Devolutions PowerShell, and Devolutions Portal.
It manages privileged account lifecycle and access control through secure password vaulting,
discovery, heartbeat, password rotation, password propagation, checkout/check-in, approval workflows,
JIT elevation/provisioning, access brokering, session recording, RBAC, built-in MFA, and reporting.

RDM is a PAM client/admin surface for dashboards, checkout/check-in, privileged account use,
custom-time checkout requests, privileged access risk, and privileged session monitoring. It is not
the PAM backend by itself; backend behavior depends on the connected Devolutions Server or
Hub/Cloud data source.

Key strategic context: Devolutions PAM complements CIEM (Cloud Infrastructure Entitlement Management)
practices. CIEM identifies excessive permissions and entitlement risks; PAM provides the enforcement
and adoption layer for JIT access, credential/session governance, access brokering, evidence capture,
and privileged-account onboarding.
</overview>

<key-concepts>

<providers>
A provider is a logical object representing an external identity provider. It orchestrates authentication,
policy enforcement, and identity validation between Devolutions PAM and the identity source.

Three provider types:
- **Managed** — Fully integrated, built and maintained by Devolutions. Support full lifecycle: discovery, heartbeat, password rotation.
  - Server providers: AWS IAM, Domain user, Entra ID user, Local SSH user, MongoDB user, PostgreSQL user, SQL Server user, SSH key, Windows user
  - Hub/Cloud providers: AWS IAM, Cisco user, Domain user, Entra ID user, Local SSH user, MongoDB user, MySQL user, Oracle user, PostgreSQL user
- **Unmanaged (password reset only)** — Manual configuration, simpler/legacy systems. Password reset only.
  - MySQL user, Cisco user, Oracle user
- **Custom PAM providers (formerly AnyIdentity providers)** — User-defined templates with custom action scripts for discovery, heartbeat, and rotation.
  - Built-in examples/templates include Azure Key Vault secret, Microsoft SQL Server Login, and Windows local accounts

For detailed provider setup: [references/server/providers.md](references/server/providers.md)
For managed providers: [references/server/providers/managed-providers.md](references/server/providers/managed-providers.md)
For custom providers: [references/server/providers/anyidentity-providers.md](references/server/providers/anyidentity-providers.md)
For MongoDB Server provider details: [references/server/providers/managed-providers/mongodb-user-provider.md](references/server/providers/managed-providers/mongodb-user-provider.md)
For MongoDB Hub/Cloud provider details: [references/hub/providers/mongodb-provider.md](references/hub/providers/mongodb-provider.md)
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

<password-propagation>
Password propagation is the broader PAM capability for updating dependent systems after a password changes.
Propagation scripts are the Devolutions Server implementation detail that pushes the new password
to dependent systems (services, scheduled tasks, IIS app pools, etc.) that use the rotated credential.

For details: [references/server/propagation-scripts.md](references/server/propagation-scripts.md)
For creating templates: [references/server/propagation-scripts/create-script-template.md](references/server/propagation-scripts/create-script-template.md)
</password-propagation>

<account-brokering>
Account brokering separates viewing a privileged password from using it. `View password` lets a user
see the checked-out password. `Connect (execute)` lets RDM inject or use the credential for a session
without exposing the password to the user.

Use this distinction whenever CIEM findings recommend controlled access to privileged resources: a
PAM-backed outcome can be "launch or execute through brokering" instead of "show the password".

For details: [references/server/view-sensitive-data-account-brokering.md](references/server/view-sensitive-data-account-brokering.md)
</account-brokering>

<devolutions-gateway>
Devolutions Gateway is the brokered remote-access component for PAM scenarios. It supports segmented
network access, domain provider connectivity across networks, credential injection, and session
recording/monitoring scenarios without broad VPN-style exposure.

For remote PAM concepts: [references/concepts/remote-privileged-access-management.md](references/concepts/remote-privileged-access-management.md)
For domain provider through Gateway: [references/kb/how-to-articles/configure-pam-provider-through-dgw.md](references/kb/how-to-articles/configure-pam-provider-through-dgw.md)
</devolutions-gateway>

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
- Secure password vaulting
- Logging and reporting
- Built-in MFA
- Access brokering
- Role-based access control
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
Cloud-hosted PAM. Current documentation may surface this area as Devolutions Hub Business,
Devolutions Hub, or Devolutions Cloud depending on page age and navigation. Verify current product
naming before writing public-facing copy.

Hub/Cloud PAM requires Devolutions Hub Services / Devolutions Cloud Services to communicate with
internal resources. The service installer can enable PAM, encryption, and reporting services; multiple
service instances can run for high availability, with standby instances used if the first service fails.

Capabilities include:
- Privileged account management
- Request/approve access workflows
- Password rotation policies
- PAM vaults
- Secure password injection
- Privileged access reports
- Provider support (AWS IAM, Cisco, Domain, Entra ID, Local SSH, MongoDB, MySQL, Oracle, PostgreSQL)
- Session recording

For complete hub PAM docs: [references/hub/](references/hub/)
For services setup: [references/hub/pam-service.md](references/hub/pam-service.md)
</devolutions-hub-business>

<remote-desktop-manager>
Client/admin interface for PAM with:
- PAM dashboard
- Privileged account management
- Checkout/check-in management
- Custom-time checkout requests from PAM vaults
- Privileged access risk assessment
- Privileged session monitoring
- Recording management for previous privileged sessions
- Personal PAM account flows through user-vault linked credentials or prompted account selection

For RDM PAM docs: [references/rdm/](references/rdm/)
For personal PAM account methods: [references/kb/knowledge-base/privileged-account-entries.md](references/kb/knowledge-base/privileged-account-entries.md)
</remote-desktop-manager>

</deployment-platforms>

<additional-concepts>
For any of these topics, read the corresponding reference file:

- Account lifecycle policy: [references/concepts/account-lifecycle-policy.md](references/concepts/account-lifecycle-policy.md)
- Action scripts (custom providers): [references/concepts/action-script.md](references/concepts/action-script.md)
- Agentless deployment: [references/concepts/agentless-deployment.md](references/concepts/agentless-deployment.md)
- Application-to-application password management: [references/concepts/application-to-application-password-management.md](references/concepts/application-to-application-password-management.md)
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
- Password propagation: [references/concepts/propagation.md](references/concepts/propagation.md)
- Privileged remote access: [references/concepts/privileged-remote-access.md](references/concepts/privileged-remote-access.md)
- Privileged sessions: [references/concepts/privileged-session.md](references/concepts/privileged-session.md)
- Privileged task automation: [references/concepts/privileged-task-automation.md](references/concepts/privileged-task-automation.md)
- User behavior analytics: [references/concepts/privileged-user-behavior-analytics.md](references/concepts/privileged-user-behavior-analytics.md)
- Remote privilege access management: [references/concepts/remote-privileged-access-management.md](references/concepts/remote-privileged-access-management.md)
- Reporting and dashboards: [references/concepts/reporting-dashboards.md](references/concepts/reporting-dashboards.md)
- Secrets management: [references/concepts/secrets-management.md](references/concepts/secrets-management.md)
- Session management: [references/concepts/session-management.md](references/concepts/session-management.md)
- Session recording: [references/concepts/session-recording.md](references/concepts/session-recording.md)
- Zero standing privileges: [references/concepts/zero-standing-privileges.md](references/concepts/zero-standing-privileges.md)
- External PAM integrations in RDM: [references/rdm/external-pam-integrations.md](references/rdm/external-pam-integrations.md)
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
- Package/license requirements by PAM action
- PAM partner integrations for CyberArk, BeyondTrust Password Safe, and Delinea Secret Server
- Kubernetes Operator, Terraform provider, and Ansible module integration surfaces
</knowledge-base>

<validated>
Validated by validate-skill on 2026-05-05 11:33
</validated>
