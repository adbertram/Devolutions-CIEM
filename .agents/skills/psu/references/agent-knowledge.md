# Extracted PSU Expert Knowledge

Source files:
- `.codex/agents/psu-expert.toml`
- `.claude/agents/psu-expert.md`
- `AGENTS.md`

## Scope

Use this skill for PowerShell Universal (PSU) v5 questions and work involving servers, apps, dashboards, APIs, scripts, jobs, schedules, triggers, terminals, hosting, security, licensing, marketplace distribution, and Devolutions CIEM PSU workflows.

## Core Responsibilities

- Create PSU apps and dashboards with proper component structure, pages, layouts, themes, data grids, forms, and charts.
- Build APIs with REST endpoints, OpenAPI documentation, authentication, and rate limiting.
- Build automation with scripts, schedules, triggers, jobs, terminals, and tests.
- Configure installation and hosting for Docker, Windows Service, IIS, persistence, Git integration, environments, and security.
- Troubleshoot errors from logs, runtime symptoms, local PSU docs, and project inspection tools.

## Working With PSU Files

- Ask where PSU files should be created when the target path is not clear from the request or existing repo structure.
- Use standard PSU conventions for file structure.
- Include concise comments only where a PSU section or runtime behavior is not self-explanatory.

## Documentation Source

PSU v5 documentation is available locally at `docs/psu-docs`.

Use this order:

1. Read `docs/psu-docs/SUMMARY.md` to identify relevant documentation files.
2. Search `docs/psu-docs` with `rg` for exact terms, cmdlet names, API paths, settings, and component names.
3. Read the relevant local documentation files.
4. Cite the files used.

Do not use web search for PSU behavior unless the user explicitly asks for current external information or the local docs are insufficient and the user approves external lookup.

## Documentation Structure

- `SUMMARY.md` - table of contents and navigation
- `getting-started/` - installation, Docker, upgrades, migration
- `api/` - REST API endpoints, OpenAPI, event hubs, security, rate limiting
- `automation/` - scripts, jobs, schedules, terminals, tests, triggers
- `apps/` - dashboards, components, themes, sessions, static apps
- `portal/` - portal pages and widgets
- `platform/` - cache, modules, monitoring, plugins, variables, published folders
- `security/` - authentication, authorization, enterprise SSO
- `config/` - settings, hosting, Git, environments, persistence, repository, management API
- `development/` - debugging, logging, profiling, VS Code extension
- `cmdlets/` - PowerShell cmdlet reference

## Connection Model

There are two connection mechanisms:

`Connect-PSUServer` is the official PSU cmdlet from the `Universal` module.
- Required for official PSU cmdlets such as `Get-PSUScript`, `Invoke-PSUScript`, `Get-PSUJob`, and `Get-PSUApp`.
- Without it, official cmdlets can error with: `Specify a computer name or use the Connect-PSUServer command.`
- Key parameters: `-ComputerName`, `-AppToken`, `-Credential`, `-UseDefaultCredentials`, `-Scope`.
- Scope is `Process` by default or `Runspace` for the current runspace.
- Uses gRPC for communication, with gRPC-Web fallback for HTTP.
- Disconnect with `Disconnect-PSUServer`.

`Connect-PSU` is the custom Devolutions.CIEM.Admin wrapper.
- Reads `.env` values such as `LOCAL_PSU_URL`, `LOCAL_PSU_TOKEN`, `AZURE_PSU_URL`, and `AZURE_PSU_TOKEN`.
- Stores connection info for `Invoke-PSUCommand`.
- Calls `Connect-PSUServer` when available so official PSU cmdlets work.
- Use `Connect-PSU -Local` for the local PSU instance.
- Suppress output when chaining: `$null = Connect-PSU -Local; <next command>`.

## Integrated Mode

The `-Integrated` switch only works inside a PSU process such as Apps, Scripts, APIs, and Schedules.

- It uses the internal backchannel TCP connection.
- It bypasses the external HTTP API.
- It needs no credentials or URL.
- It requires PSU `SecurityModel` to be `Permissive` or `Integrated`.
- It does not work from external terminals or CI jobs.

Security model values:

- `Strict` - no `-Integrated`; user context required; external API only.
- `Permissive` - default; `-Integrated` allowed; user context passed when available.
- `Integrated` - all calls use backchannel; no user context; no auth needed.

## Script Registration

`New-PSUScript -Module 'ModuleName' -Command 'CommandName'` exposes a module function as a PSU script.

- The module must be installed on the PSU server.
- Do not add `-Name` with the `-Module` and `-Command` parameter set.
- The script name is derived as `ModuleName\CommandName`.
- Configuration is stored in `.universal/scripts.ps1`.
- PSU startup loads that configuration, so changes require restart or configuration sync depending on the workflow.

## Safety Rules

- Never modify PSU `database.db` directly with sqlite or SQL tools.
- Use PSU REST APIs or cmdlets for PSU-managed state.
- Local PSU admin API endpoints require authentication.
- Do not use bare `curl` against `/api/v1/*` admin endpoints.
- For CIEM runtime validation, use `Invoke-TestCommand` after tests are in place.
- `scripts/azure_psu_file_manager.sh` and `scripts/invoke_command_in_azure_webapp.sh` are inspection tools, not deployment tools.

## Job Lifecycle

- `DELETE /api/v1/job/{id}` returns 200 but does not delete or archive jobs.
- There is no `Remove-PSUJob` or `Set-PSUJob` cmdlet.
- `$JobId` is not an automatic variable available in PSU script context.
- `Invoke-PSUScript -Parameters @{...}` does not pass parameters to scripts registered with `-Module -Command`; use PSU Cache to pass configuration between a page and a job.

## Cache Rules

- `Set-PSUCache -Value $null` throws because PSU rejects null cache values.
- Use `Set-PSUCache -Value @{} -Persist` to clear an object-like cache key, or use `Remove-PSUCache`.
- Use `-Integrated` for `Get-PSUCache` and `Set-PSUCache` inside PSU context.
- Use `-ErrorAction SilentlyContinue` when reading cache keys that may not exist.

## Efficiency Rule

Combine related runtime checks into a single `Invoke-TestCommand` call. Each call creates a PSU job with startup and timeout overhead.

Example:

```powershell
Invoke-TestCommand -ScriptBlock { Get-PSUScript; Get-PSUJob -First 5 -Integrated }
```

## Module Manifest Convention

For this project, `FunctionsToExport = @('*')` is preferred in module manifests. The `.psm1` handles explicit exports via `Export-ModuleMember`. Do not flag this as a best practice violation in this repo.

## Log Debugging

Use `scripts/download-psu-logs.sh` to download Azure PSU logs, then search the downloaded log files locally.

Useful search terms include:

- `CIEM`
- `error`
- `authentication`
- module names
- app names
- exact exception text

Log sources:

- Database logs: app-level `[App-Devolutions CIEM]` messages, usually most useful for app issues.
- Docker logs: Azure container stdout for infrastructure issues.
- API logs: PSU REST API logs.

## CIEM App Management

Create the CIEM app on a fresh or reset PSU instance with:

```powershell
New-PSUApp -Name 'Devolutions CIEM' -BaseUrl '/ciem' -Module 'Devolutions.CIEM' -Command 'New-DevolutionsCIEMApp'
```

Do not use `-Authenticated` for local development because it blocks E2E tests.

After a full local PSU reset, the user must complete browser-based setup, create the admin account, enter the license, and create a new App Token for `.env` before API calls work.
