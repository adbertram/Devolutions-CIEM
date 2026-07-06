# SQLite Deployment Topology Answer

Status: design answer for the Samuel/Nicolas deployment sync. This does not validate any live Devolutions production PSU instance.

## Source-Backed Answer

For v1, CIEM supports a single active PSU instance using one CIEM SQLite database path. The database is resolved by the module as `$script:DataRoot/ciem.db`; when CIEM is loaded from a PSU Repository module path, `$script:DataRoot` resolves to the Repository-level `data` folder so state survives module version upgrades. Module setup calls `New-CIEMDatabase`, creates the database directory if needed, applies the base, Azure, discovery, and graph schemas, and then verifies required tables.

This means Simon's single-instance question has a clear v1 answer: disk-written SQLite is acceptable only when the CIEM app runspaces, manual discovery jobs, scheduled discovery jobs, and scan jobs all resolve to the same local `ciem.db` path on the same PSU node.

Multi-instance PSU is not a supported CIEM v1 shape until it is validated. PSU itself supports multiple computers through shared SQL/PostgreSQL persistence and a shared git repository, and schedules can target any computer, all computers, or a selected computer. CIEM's own product state is separate from PSU's persistence database and is currently stored in the local CIEM SQLite file, so a PSU HA topology does not automatically make CIEM state shared or writer-safe across nodes.

## Supported V1 Shape

- One PSU instance or one active CIEM write node.
- One CIEM module install path whose Repository-level `data/ciem.db` path is used by both the CIEM app and CIEM automation scripts.
- The CIEM app, `Devolutions.CIEM\Start-CIEMAzureDiscovery`, scan commands, exposure-change comparison, notification previews, and schedule metadata all read and write that same SQLite file.
- One CIEM-owned Azure discovery schedule named `CIEM Azure Discovery`, backed by `Devolutions.CIEM\Start-CIEMAzureDiscovery`.
- Manual and scheduled discovery are operationally treated as single-writer workflows. Existing SQLite transactions and `BEGIN IMMEDIATE` protect some mutation paths from overlapping writers, but they are not a substitute for a cluster-wide scheduling and storage design.

## Single-Instance Assumptions

- The CIEM database file is local and durable for the PSU instance. In Azure App Service, confirm the resolved path is on persistent app storage, not a transient container layer.
- Every CIEM runspace sees the same `$script:DataRoot` and `Get-CIEMDatabasePath` result.
- The configured auth profile can read Azure through the chosen identity, including ARM/Resource Graph and Microsoft Graph read permissions required by discovery.
- The PSU schedule runs the CIEM discovery script in the expected environment and records status back into `azure_discovery_schedules`.
- Scheduled discovery cadence remains one of the currently supported values: daily `0 2 * * *` or weekly `0 2 * * 1`.

## Multi-Instance Risks

- Different nodes can resolve different local SQLite files. That produces split-brain CIEM state: node A scans and writes data that node B's app cannot see.
- A shared filesystem path for SQLite still needs explicit validation. SQLite file locking depends on filesystem semantics; network shares and platform-mounted storage can behave differently than a local disk.
- PSU schedules default to any available computer unless constrained. In a multi-node topology, CIEM's current schedule creation does not specify a `-Computer` or `-ComputerGroup`, so the selected runner is not pinned by CIEM code.
- If the schedule is configured for all computers or duplicated by configuration drift, multiple nodes can start the same discovery workflow against one CIEM state store.
- Manual discovery from the UI and scheduled discovery can overlap. The current app checks for running discovery runs for display/cancel flow, but production readiness still needs a hard single-writer rule for scheduled/manual overlap.
- PSU HA guidance relies on SQL/PostgreSQL to share PSU job queues, identities, and app tokens. That does not migrate CIEM's separate SQLite data model.

## Validation Checklist For Samuel/Nicolas

1. Confirm the target PSU deployment model: single node, active/passive, load-balanced multi-node, Azure App Service scale-out, or another cluster shape.
2. Confirm PSU version and persistence provider. If the topology is HA, confirm whether PSU uses SQL or PostgreSQL, not local SQLite, for PSU's own database.
3. On every active node, run the CIEM module path/database-path validation through an approved PSU runtime path and record:
   - loaded `Devolutions.CIEM` module path
   - `$script:DataRoot`
   - `Get-CIEMDatabasePath`
   - whether the file exists and is writable
   - whether the path is local, mounted shared storage, or ephemeral container storage
4. Confirm whether every active app/job node resolves the same CIEM database path and sees the same file contents.
5. Confirm where schedules run: any computer, all computers, selected computer, selected computer group, or one dedicated automation node.
6. If production is multi-node, choose one of these before deployment:
   - constrain CIEM schedules and write workflows to one node and route the CIEM app to that same node, or
   - redesign CIEM state around a production shared database instead of local SQLite.
7. Validate manual discovery and scheduled discovery cannot run concurrently in the target topology.
8. Confirm the managed identity has ARM/Resource Graph Reader scope and Microsoft Graph application permissions required by discovery.
9. Confirm backup/retention expectations for `ciem.db`, `ciem.log`, and generated evidence.
10. Confirm rollback behavior: what happens to CIEM state if the module is removed, reinstalled, or upgraded.

## Non-Goals For This Increment

- No PSU publish, deployment, restart, or live production validation.
- No PSU schedule creation or modification.
- No cloud, IdP, PAM, ticketing, SIEM, email, or webhook write behavior.
- No migration from SQLite to SQL/PostgreSQL.
- No claim that multi-instance CIEM is production-supported.
- No direct database manipulation outside repo documentation.

## Source Evidence

- Simon deployment/storage questions: `goals/simon-ciem-feedback/simon-feedback.md`
- Product guardrails and scheduled discovery direction: `docs/ciem-feature-todos.md`
- Implementation phase requiring the topology answer: `goals/simon-ciem-feedback/implementation-instructions.md`
- CIEM data root and bundled SQLite module loading: `psu-app/Devolutions.CIEM.psm1`
- CIEM database path and initialization: `psu-app/Public/Get-CIEMDatabasePath.ps1`, `psu-app/Public/New-CIEMDatabase.ps1`, `psu-app/setup.ps1`
- SQLite query and transaction behavior: `psu-app/Public/Invoke-CIEMQuery.ps1`, `psu-app/Private/InvokeCIEMImmediateTransaction.ps1`, `psu-app/modules/PSUSQLite/Public/Open-PSUSQLiteConnection.ps1`
- SQLite schema and schedule table: `psu-app/data/schema.sql`, `psu-app/modules/Azure/Discovery/Data/discovery_schema.sql`
- CIEM schedule behavior: `psu-app/modules/Azure/Discovery/Public/Set-CIEMAzureDiscoverySchedule.ps1`, `psu-app/modules/Azure/Discovery/Public/Get-CIEMAzureDiscoverySchedule.ps1`, `psu-app/modules/Azure/Discovery/Public/Start-CIEMAzureDiscovery.ps1`
- PSU persistence, HA, computers, and schedules docs: `docs/psu-docs/config/persistence.md`, `docs/psu-docs/config/hosting/high-availability.md`, `docs/psu-docs/platform/computers.md`, `docs/psu-docs/automation/schedules.md`
