# Devolutions CIEM Project Context

Strategic context, business model, stakeholders, and positioning. Loaded by agents on demand; not in every-session CLAUDE.md.

## Developer Context

- **Role:** Devolutions contractor (25 hrs/week), full-time dev since March 2025 (previously split with product marketing)
- **Focus:** CIEM project exclusively — PSU app, PowerShell module, identity security
- **Previous work:** RDM Pester tests, PAM AnyIdentity providers/propagation scripts, content/datasheets
- **PSU Ownership:** PowerShell Universal is owned by Devolutions (acquired from Ironman Software)

## CIEM Business Model

Key context from discussions with Marc-André Moreau:

- **Distribution:** PSU app published to the PSU Gallery (not standalone deployment)
- **Business Model:** Free add-on for PSU customers (no additional cost beyond PSU license)
- **Strategic Purpose:** Lead generation for Devolutions PAM solution; CIEM is a Gartner inclusion criteria for PAM
- **Differentiation:** CIEM is niche and valuable — CSPM is a commodity already bundled free in cloud platforms
- **Action Flow:** CIEM identifies findings → users are redirected to Devolutions PAM to take action

## Product Purpose And Expected Features

`docs/ciem-feature-todos.md` is the source of truth for the project's purpose and expected product capabilities. Treat it as project direction, not an optional idea list.

CIEM should discover cloud and identity entitlement data, build the environment hierarchy, detect attack paths, detect exposure changes over time, and make findings actionable through existing security and PAM workflows.

**Discovery priorities:** scheduled discovery scans, exposure change detection, AWS effective access graph, least-privilege recommendation previews, privilege drift detection, sensitive resource access inventory, expanded attack path patterns, discovery coverage reporting.

**Action and connector priorities:** outbound risk signal delivery, finding-to-action queue, PAM-backed JIT access requests, manual approval and evidence capture, least-privilege change packages, controlled role or policy updates, automatic expiration or revocation.

Discovery remains read-only by default. Action, connector, PAM, SIEM, ticketing, IdP, or cloud write workflows require explicit re-scoping before implementation.

## CSPM vs CIEM Positioning

Per Simon Chalifoux's detailed review (March 2026): the initial implementation was CSPM (CIS best-practice checks), not true CIEM. CSPM is a commodity — Azure Defender for Cloud offers it free. The project must focus on **CIEM-specific features** that differentiate from free tools:

- **Identity-first data model (CRITICAL)** — The entire system is modeled around **identities**, not resources. Graph/control relationships are the right representation, but the primary axis is identity → entitlements.
- **Identity drill-down view** — Users must be able to drill down from an identity to all entitlements it holds, surfacing compound risk (e.g., "this VM has a managed identity with Owner role on the subscription, a public IP, and RDP open on the network").
- **Dormant permission detection** — Users/service principals with unused privileged roles (via sign-in logs).
- **Role right-sizing** — Propose least-privilege custom roles to replace overly broad assignments.
- **Control relationship discovery** — Map identity-to-resource relationships and surface attack paths.
- **Risk-to-PAM mapping** — Connect findings to Devolutions PAM privileged roles.

Existing Prowler-ported CSPM checks are retained as a secondary feature but are NOT the differentiator.

**Reference Products (from Simon Chalifoux's analysis):**
- **Delinea** Privilege Control for Cloud Entitlements
- **BeyondTrust Entitle** (2025 GigaOm Radar Leader)
- **BloodHound / AzureHound** for attack path detection methodology
- Microsoft retired **Entra Permissions Management** (formerly CloudKnox) Nov 2025, redirected to Delinea — gap to fill in Azure ecosystem
- Gartner's four CIEM pillars: Entitlement visibility, Permission right-sizing, Advanced analytics, Compliance automation

## Stakeholders & Team

### CIEM Core Team

| Person | Slack ID | Role |
|--------|----------|------|
| Marc-André Moreau | mamoreau | VP/Project Sponsor — gave CIEM vision, strategic direction, approval authority |
| Simon Chalifoux | schalifoux | Security Architect — gave critical CSPM-vs-CIEM feedback (March 2026), expert on Gartner CIEM pillars. Shaped the identity-first pivot. |
| David Hervieux | dhervieux | Engineering Lead — wants demo video, discussed JSON-first approach with Marc-André. Bilingual (FR/EN). |
| Luc Fauvel | lfauvel | Security — interested in CIEM, introduced by Marc-André, saw demo |
| Adam Driscoll | adriscoll | PSU Creator — module dependency expert, gave PSU license |

### Engineering/Management

| Person | Slack ID | Role |
|--------|----------|------|
| Sébastien Duquette | sduquette | Engineering Manager (RDM PowerShell) — gave Jira/GitHub access, aware of CIEM |
| Maxime Bernier | mbernier | RDM PowerShell Dev — PR reviewer |
| Maxime Trottier | mtrottier | Contract/HR Manager — handles SoW renewals |

For Slack interactions, use the `devolutions-team-member` agent (knows Adam's style and team relationships) and the `--profile devolutions` flag on the `slack` CLI.

## Architecture Key Decisions

| Aspect | Decision |
|--------|----------|
| Runtime | Pure PowerShell (no Python) |
| V1 Providers | Azure, AWS |
| Data Model Axis | Identity-first (drill identity → entitlements), not resource-first |
| Core Focus | CIEM: dormant permissions, role right-sizing, control relationships |
| CSPM Checks | Retained as secondary layer (Prowler-ported) |
| Compliance Mapping | Not in v1 |
| Historical Data | Not in v1 (snapshot per scan) |
| AD Support | Future (architected for extensibility) |
| PAM Integration | Risk-to-PAM mapping (deeper than link to docs) |

Full architecture: `docs/devolutions-ciem-app-architecture.md`. Resource icons: `psu-app/modules/Devolutions.CIEM.PSU/Data/icons/` (Azure, Entra, AWS source packs in `source-packs/`, curated SVGs in `resources/`, `resource-icon-map.json` for type→asset mapping).
