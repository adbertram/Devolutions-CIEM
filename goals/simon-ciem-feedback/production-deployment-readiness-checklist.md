# Production PSU Deployment Readiness Checklist

Status: design and validation plan for the Samuel/Nicolas sync. This document does not validate any live Devolutions production PSU instance.

## Readiness Decision

CIEM is ready to queue for production deployment only when the sync can produce evidence for all required checks below and the target topology matches the supported v1 shape in [sqlite-deployment-topology.md](sqlite-deployment-topology.md).

If the target is multi-node, scaled out, or uses more than one active app/job computer, CIEM is not production-ready until the team either pins all CIEM app and write workloads to one node with one durable `ciem.db` path, or redesigns CIEM state away from local SQLite.

## Non-Goals For This Increment

- No publish, deploy, restart, removal, schedule mutation, or PSU configuration change.
- No Azure production API call, customer tenant validation, or managed identity permission change.
- No direct inspection of secrets, `.env`, app tokens, or customer data.
- No claim that CIEM has been validated against Devolutions production PSU.

## Required Evidence Packet

Capture these artifacts for Samuel and Nicolas before a deploy decision:

| Area | Evidence to capture | Ready condition |
| --- | --- | --- |
| PSU version and persistence | PSU version, container/image or host install version, persistence provider, and scale count | Version is supported for CIEM; production PSU persistence is documented; scale count is known |
| Topology | Computer list, active app nodes, active job nodes, load balancer or App Service scale-out setting | Single active CIEM node, or a documented one-node constraint for CIEM app and write jobs |
| Module import | Loaded `Devolutions.CIEM` module path, module version, `$PSScriptRoot`, `$script:DataRoot`, and `Get-CIEMDatabasePath` from PSU runtime | App and automation runtime resolve the same module and same CIEM data root |
| App URL | Production app URL and base URL registration for `Devolutions CIEM` | `/ciem` or the approved production base URL renders the CIEM dashboard without PSU app-startup errors |
| Scripts | Registered PSU scripts for `Devolutions.CIEM\Start-CIEMAzureDiscovery`, `Devolutions.CIEM\New-CIEMScanRun`, and `Devolutions.CIEM\Invoke-CIEMAttackPathRemediation` | Exactly one active registration for each CIEM script, with module/command names matching `.universal/scripts.ps1` |
| Schedule support | `CIEM Azure Discovery` schedule state, cron, parameters, environment, computer/computer group, next run, and paused state | Schedule is disabled until launch, or enabled with a supported daily/weekly cron and a single approved runner |
| Managed identity | Authentication profile assignment for `ProviderDiscovery:Azure`, method, managed identity client ID when user-assigned, tenant, subscription scope list, and permission grant evidence | CIEM uses `ManagedIdentity` in Azure App Service and the identity has required ARM and Microsoft Graph read permissions |
| CIEM database | `ciem.db` path, storage mount type, file existence, writability, backup owner, backup path, retention, and restore contact | Database lives on durable storage and is backed up before deployment, upgrade, or removal |
| Manual vs scheduled overlap | Evidence that manual discovery, scheduled discovery, and Azure scan workflows share the same database and cannot overlap as writers | One single-writer rule exists for manual/scheduled discovery and Azure scans in the target topology |
| Rollback/removal | Removal command owner, state-retention decision, backup restore path, app/script/schedule/module cleanup expectations | Rollback can remove CIEM resources without deleting the only state backup |

## Validation Categories

### 1. PSU Version, Persistence, And Topology

Record the production PSU version and hosting shape before deployment. The current repo documents CIEM against PSU `5.5.4+`, with Azure production currently expected on the `ironmansoftware/universal:5.5.4-azure` image. PSU docs recommend SQL or PostgreSQL persistence for production and HA, while local SQLite persistence is recommended only for small or testing instances.

Evidence to capture:

- PSU version or image tag.
- Persistence provider: SQLite, SQL, or PostgreSQL.
- Azure App Service scale-out count or server/computer count.
- `Get-PSUComputer` output or equivalent admin-console export.
- Whether apps and jobs can run on one computer, all computers, or any available computer.

Gate:

- Single-node PSU can proceed to CIEM runtime validation.
- Multi-node PSU is blocked unless CIEM app access, manual discovery, scheduled discovery, and scans are pinned to the same durable CIEM database path and one writer.

### 2. Module Import Path And App URL

CIEM registers the PSU app from `psu-app/.universal/dashboards.ps1` as `Devolutions CIEM` at `/ciem`, and the app command is `New-DevolutionsCIEMApp`. The module resolves CIEM state under `$script:DataRoot`; when loaded from a PSU Repository module path, this should resolve to the Repository-level `data` folder so state survives module version upgrades.

Evidence to capture from an approved PSU runtime path:

```powershell
Import-Module Devolutions.CIEM -ErrorAction Stop
[pscustomobject]@{
    ModulePath   = (Get-Module Devolutions.CIEM).Path
    DatabasePath = Get-CIEMDatabasePath
}
```

Also capture the production URL that operators will open, the app name, the base URL, and a screenshot or text evidence that the CIEM dashboard renders and does not show `App is not running`.

Gate:

- The loaded module path is the deployed Gallery module, not an ad hoc upload.
- The app URL is approved and stable for Samuel/Nicolas to reference.
- The database path matches the topology decision.

### 3. Script Registration And Schedule Support

The active PSU script registration source is `psu-app/.universal/scripts.ps1`. It registers three module/command scripts:

- `Devolutions.CIEM\New-CIEMScanRun`
- `Devolutions.CIEM\Start-CIEMAzureDiscovery`
- `Devolutions.CIEM\Invoke-CIEMAttackPathRemediation`

The scheduled-discovery command uses the schedule name `CIEM Azure Discovery`, the script name `Devolutions.CIEM\Start-CIEMAzureDiscovery`, and only supports these v1 cron values:

- Daily: `0 2 * * *`
- Weekly: `0 2 * * 1`

Evidence to capture:

- PSU script inventory filtered to module `Devolutions.CIEM`.
- Schedule inventory for `CIEM Azure Discovery`.
- Environment, parameters, computer/computer group, paused state, next run, and last run status if present.

Gate:

- All three scripts are registered exactly once.
- The discovery schedule is absent or paused before the deployment window.
- If enabled for launch, the schedule uses a supported cron and one approved runner.

### 4. Managed Identity And Read Permissions

CIEM supports Azure `ManagedIdentity` authentication in Azure App Service when `IDENTITY_ENDPOINT` and `IDENTITY_HEADER` are available. The repo README lists required read permissions:

- Azure RBAC `Reader` on every target subscription.
- Microsoft Graph application permissions: `Directory.Read.All`, `Policy.Read.All`, `RoleManagement.Read.Directory`, `User.Read.All`, and `UserAuthenticationMethod.Read.All`.

Evidence to capture:

- CIEM authentication profile assigned to `ProviderDiscovery:Azure`.
- Profile method is `ManagedIdentity`.
- Managed identity type: system-assigned or user-assigned.
- Principal object ID and client ID when user-assigned.
- Subscription list and Reader assignment evidence.
- Microsoft Graph application permission grant evidence.
- No secret values.

Gate:

- The assigned profile is Azure `ManagedIdentity`.
- Every target subscription and required Microsoft Graph read permission is documented.
- No production scan is approved until missing read grants are resolved.

### 5. CIEM Database Path, Storage, And Backup

CIEM product state is separate from PSU persistence and is stored in CIEM's own SQLite file at `Get-CIEMDatabasePath`. Azure App Service container hosting requires persistent `/home` storage through `WEBSITES_ENABLE_APP_SERVICE_STORAGE=true`; otherwise local container writes can be lost.

Evidence to capture from each active app/job node:

- `Get-CIEMDatabasePath`.
- Whether the path is local disk, persistent App Service storage, mounted shared storage, or transient container storage.
- File existence and writability.
- File size and last modified time.
- Backup owner, backup location, retention, restore process, and restore contact.
- Whether `ciem.log` and generated evidence share the same durability expectations.

Gate:

- Single-node: one durable path is visible to the CIEM app and all CIEM jobs.
- Multi-node: all nodes resolve the same path and filesystem locking semantics are validated, or deployment is blocked.
- A backup exists before production deployment, upgrade, removal, or rollback.

### 6. Manual-Vs-Scheduled Overlap

CIEM has source-level guards that reject overlapping Azure discovery and Azure scan writers against the same SQLite database. Those guards do not prove cluster-wide single-writer safety when multiple PSU nodes can run the same job or when nodes resolve different database files.

Evidence to capture:

- Manual discovery path and scheduled discovery path both execute `Start-CIEMAzureDiscovery`.
- Azure scan path uses `New-CIEMScanRun`.
- Manual discovery, scheduled discovery, and scans all resolve the same `Get-CIEMDatabasePath`.
- PSU schedule computer selection proves one runner, not all computers.
- Operational rule for stale running jobs and cancellation ownership.

Gate:

- No deployment if manual and scheduled writers can run against different database files.
- No deployment if a schedule can run on all computers or drift to multiple runners.
- No deployment if there is no owner for clearing stale `Running` discovery or scan rows.

### 7. Rollback, Removal, And State Retention

Rollback must separate CIEM resource removal from state deletion. The supported removal path is the repo-owned `scripts/remove-psu.ps1` with the selected environment, but this sync should only agree on ownership and evidence, not run it.

Evidence to capture:

- Who can approve rollback.
- Which version to redeploy or remove.
- Whether `ciem.db`, `ciem.log`, and exported evidence are retained, backed up, or removed.
- Expected post-removal counts for CIEM app, scripts, schedules, module, active jobs, queued jobs, and retained job history.
- Communication path for Samuel/Nicolas if app load, script registration, schedule, or managed identity validation fails.

Gate:

- Rollback owner and state-retention choice are documented before deployment.
- No one deletes the only `ciem.db` copy during removal.

## Samuel/Nicolas Sync Agenda

1. Confirm target PSU production version, hosting model, persistence provider, and node count.
2. Decide whether production is in the supported v1 shape: one active CIEM write node and one durable `ciem.db` path.
3. Review CIEM module import path, `/ciem` app registration, and registered scripts.
4. Review managed identity Reader and Microsoft Graph read permissions.
5. Review schedule support and decide whether `CIEM Azure Discovery` starts disabled or enabled.
6. Review backup, rollback, and state-retention owner.
7. Decide one of:
   - Ready to queue deployment after approved runtime validation.
   - Blocked on topology/storage/schedule constraint.
   - Blocked on managed identity permissions.
   - Blocked on backup/rollback ownership.

## Source Evidence

- Simon deployment and SQLite concerns: [simon-feedback.md](simon-feedback.md) items 5 and 6.
- Phase 7 direction: [implementation-instructions.md](implementation-instructions.md#phase-7-production-psu-deployment-readiness).
- v1 topology answer: [sqlite-deployment-topology.md](sqlite-deployment-topology.md).
- CIEM module data root and database path: `psu-app/Devolutions.CIEM.psm1`, `psu-app/Public/Get-CIEMDatabasePath.ps1`.
- PSU app and script registrations: `psu-app/.universal/dashboards.ps1`, `psu-app/.universal/scripts.ps1`.
- Scheduled discovery behavior: `psu-app/modules/Azure/Discovery/Public/Set-CIEMAzureDiscoverySchedule.ps1`, `psu-app/modules/Azure/Discovery/Public/Start-CIEMAzureDiscovery.ps1`.
- Overlap guard: `psu-app/Private/AssertCIEMAzureMutationAllowed.ps1`.
- Managed identity and permissions: `psu-app/README.md`, `psu-app/modules/Azure/Infrastructure/Public/Connect-CIEMAzure.ps1`, `psu-app/modules/Devolutions.CIEM.PSU/Public/Get-PSUInstalledEnvironment.ps1`.
- PSU persistence, HA, computers, schedules, and Azure storage: `docs/psu-docs/config/persistence.md`, `docs/psu-docs/config/hosting/high-availability.md`, `docs/psu-docs/platform/computers.md`, `docs/psu-docs/automation/schedules.md`, `docs/psu-docs/config/hosting/azure.md`.
