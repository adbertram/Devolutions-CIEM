<overview>
These are the fixed Azure PSU instance facts and guardrails that should anchor
all troubleshooting and preflight work.
</overview>

<instance_facts>
- URL: `https://devolutions-ciem-psu.azurewebsites.net`
- Resource group: `devolutions-ciem-rg`
- Location: `West US 2`
- App Service Plan: `Standard S1 (Linux)`
- PSU version target: `5.5.4`
- Container image target: `ironmansoftware/universal:5.5.4-azure`
- CIEM app base URL: `/ciem`
- Diagnostics script: `scripts/azure-psu-diagnostics.ps1`
- Default diagnostics transcript: `_temp/azure-psu-diagnostics.log`
</instance_facts>

<expected_steady_state>
When the instance is healthy, expect most or all of the following:

- `/api/v1/alive` returns HTTP 200 and `loading=false`
- `LinuxFxVersion` is `DOCKER|ironmansoftware/universal:5.5.4-azure`
- `API__SecurityModel` is `Permissive`
- the CIEM app exists and is reachable
- the `Devolutions.CIEM` module is installed on PSU
- at least one app token exists
- the Azure runtime has an active authentication profile when Azure-auth flows
  are being tested
- `FailureSummary.PSUAppUnhealthy` is empty in the diagnostics report
</expected_steady_state>

<guardrails>
- Azure restarts are slow. Prefer `Restart-PSUApp` or configuration sync before a
  full web app restart.
- Never upload module files directly to Azure PSU.
- Kudu commands run in the sidecar container that shares `/home`; they are not a
  substitute for PSU runtime inspection.
- Do not use raw environment dumps or raw PSU job-object dumps as standard
  diagnostics in this repo.
- Use local PSU by default unless the user explicitly asks for Azure or
  production validation.
</guardrails>

<failure_plane_rules>
- Azure control plane: ARM site/config calls and some management endpoints.
- Kudu control plane: publishing credentials, status URLs, file access, Kudu
  command APIs, and log scraping through SCM.
- PSU runtime: `/api/v1/alive`, `Connect-PSU`, `Get-PSUInformation`,
  `Get-PSUApp`, `Get-PSUModule`, `Get-PSUAppToken`, and `Invoke-TestCommand`.

These planes fail independently. A broken ARM or Kudu path does not prove the
PSU runtime is down, and a healthy `/api/v1/alive` result does not prove auth
profiles, app tokens, or CIEM module state are valid.
</failure_plane_rules>
