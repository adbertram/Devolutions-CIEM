<overview>
These are the Azure PSU failures and Azure-specific CIEM behaviors that should be
checked early before inventing new theories.
</overview>

<issue name="discovery-last-query-filter-order">
<symptom>
The global Last Discovery header disappears during a discovery run and PSU can
show `One or more errors occurred`.
</symptom>

<cause>
`Get-CIEMAzureDiscoveryRun -Status 'Completed' -Last 1` must apply `-Status`
before `-Last`. If `-Last` ignores filters, a newer `Running` row displaces the
latest completed run.
</cause>

<action>
Treat this as application behavior that can look like an Azure instance problem.
Verify the fix in `psu-app/modules/Azure/Discovery/Public/Get-CIEMAzureDiscoveryRun.ps1`
and its tests before blaming the Azure host.
</action>
</issue>

<issue name="app-startup-must-not-register-scripts">
<symptom>
`/ciem` returns HTTP 200 but the page body says `App is not running`. Logs can
show `Failed to get dashboard. Specify a computer name or use the
Connect-PSUServer command.` or gRPC cancellation errors.
</symptom>

<cause>
`New-DevolutionsCIEMApp.ps1` must not call `Import-CIEMScript` from dashboard
startup. PSU app startup cannot reliably perform PSU management cmdlets in Azure.
</cause>

<action>
Inspect the generated app startup path and `Repository/.universal/apps.ps1`.
Run script registration as an explicit management action after `Connect-PSU`,
not during app creation or render.
</action>
</issue>

<issue name="get-psuapp-name-filter-can-miss-ciem-app">
<symptom>
`scripts/azure-psu-diagnostics.ps1` can report `CIEMApp = null` even when
`Get-PSUApp` lists `Devolutions CIEM` and `/ciem` renders the dashboard.
</symptom>

<cause>
On Azure PSU, `Get-PSUApp -Name '*CIEM*'` can return no rows while the unfiltered
`Get-PSUApp` result contains the CIEM app.
</cause>

<action>
Diagnostics must query `Get-PSUApp` without `-Name` and filter locally for the
exact app name `Devolutions CIEM`. Keep the regression test
`Devolutions.CIEM.Admin/Tests/Unit/AzurePSUDiagnostics.Tests.ps1`.
</action>
</issue>

<issue name="app-tokens-can-disappear">
<symptom>
`Connect-PSU` returns HTTP 401 while `/api/v1/alive` is healthy, or publish to
PowerShell Gallery works but Azure import fails.
</symptom>

<cause>
The Azure PSU database can lose all app tokens after recovery or reset events.
</cause>

<action>
Check `AppTokens` in the diagnostics report first. Recover through the supported
local-admin/bootstrap path, regenerate an app token, and update `.env` without
printing the token value.
</action>
</issue>

<issue name="get-psuscript-name-cancel">
<symptom>
`Import-CIEMScript` fails on Azure with
`Status(StatusCode="Cancelled", Detail="No message returned from method.")`
when a script is absent.
</symptom>

<cause>
Azure PSU cancels `Get-PSUScript -Name` calls for missing scripts.
</cause>

<action>
Do not use named PSU script lookups for CIEM registration. Query all scripts
once and match locally.
</action>
</issue>

<issue name="unsupported-2026-image">
<symptom>
An instance on `ironmansoftware/universal:2026.1.5-azure` shows first-run login
behavior, 401s on local-admin bootstrap endpoints, or can crash when forcing
form authentication.
</symptom>

<cause>
The 2026.1.5 Azure image is not a supported recovery target for this CIEM
instance.
</cause>

<action>
Keep the Azure CIEM PSU instance on `ironmansoftware/universal:5.5.4-azure`.
If Azure keeps pulling the wrong image, recreate the web app with 5.5.4 as the
initial image.
</action>
</issue>

<operational_lessons>
- Broad Azure failures often come from four separate state planes: App Service or
  container config, PSU runtime config, CIEM module or runtime behavior, and
  CIEM auth or secret state.
- `API__SecurityModel=Permissive` is part of the expected Azure steady state for
  this repo.
- Missing Azure auth profiles or required variables can break tests and scans
  while `/api/v1/alive` remains healthy.
- Kudu-side inspection and PSU-runtime inspection answer different questions.
- `WarningOutput` is a real PSU job state and should be preserved in summaries,
  not collapsed away.
</operational_lessons>
