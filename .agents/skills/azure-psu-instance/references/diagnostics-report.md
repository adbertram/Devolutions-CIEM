<overview>
`scripts/azure-psu-diagnostics.ps1` is the mandatory first step for Azure PSU
instance work. It exists to replace slow, repetitive, broad reruns with one
deterministic report.
</overview>

<commands>
Baseline run:

```powershell
pwsh -NoProfile -File scripts/azure-psu-diagnostics.ps1 -Json
```

Expanded run:

```powershell
pwsh -NoProfile -File scripts/azure-psu-diagnostics.ps1 -JobLimit 30 -LogLineCount 100 -Json
```
</commands>

<default_behavior>
- The script overwrites `_temp/azure-psu-diagnostics.log` by default.
- It writes a transcript so the last long run can be inspected without rerunning.
- Azure CLI, ARM, and Kudu timeouts are intentionally long to avoid false
  negatives caused by impatient cutoffs.
- ARM REST is used for site, config, app settings, instance, and Kudu-credential
  paths instead of `az webapp ...` control-plane commands.
- Runtime probing is intentionally combined into one `Invoke-TestCommand` call to
  reduce PSU job overhead.
</default_behavior>

<sections>
- `Alive`: health endpoint status, latency, loading state
- `WebApp`: ARM site state and availability
- `Instances`: ARM instance list
- `InstanceStatus`: Kudu status URL details for each instance
- `LinuxFxVersion`: configured container image
- `AppSettings`: security model plus app-setting names
- `PSUVersion`: PSU version from runtime
- `CIEMApp`: app registration
- `CIEMModule`: installed module details
- `AppTokens`: token count and non-secret token metadata
- `Runtime`: combined module, installed environment, auth profile, variable-name,
  and recent job summary probe
- `LogExcerpts`: recent Kudu log lines
- `FailureSummary`: grouped failures by control-plane vs runtime plane
</sections>

<interpretation>
Hard blockers for Azure-dependent tests, publish verification, or runtime
validation:

- `Alive` fails or reports `loading=true`
- `PSUVersion`, `CIEMApp`, `CIEMModule`, or `Runtime` fails
- `AppTokens.Count` is `0`
- `AppSettings.SecurityModel` is neither `Permissive` nor `Integrated`
- the runtime shows no active Azure auth profile for work that depends on Azure
  authentication

Control-plane failures that add context but do not automatically prove the app is
down:

- `WebApp`
- `Instances`
- `InstanceStatus`
- `LogExcerpts`

When `FailureSummary.AzureControlPlaneUnavailable` is populated but
`FailureSummary.PSUAppUnhealthy` is empty, treat the issue as an Azure management
or Kudu visibility problem first, not a CIEM runtime outage.
</interpretation>

<usage_rules>
- If `_temp/azure-psu-diagnostics.log` already exists and answers the current
  question, inspect it before rerunning the script.
- Rerun the script when the user needs current state, after a recovery action, or
  when the previous transcript predates the current incident.
- Use absolute dates and current timestamps when reporting results from the
  diagnostics report.
</usage_rules>
