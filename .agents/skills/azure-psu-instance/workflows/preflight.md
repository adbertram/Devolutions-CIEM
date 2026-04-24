<required_reading>
- [references/instance-baseline.md](../references/instance-baseline.md)
- [references/diagnostics-report.md](../references/diagnostics-report.md)
- [references/inspection-tools.md](../references/inspection-tools.md)
</required_reading>

<process>
<step_1>
Check `_temp/azure-psu-diagnostics.log` first. If it is recent enough for the
user's question and already captures the needed evidence, use it before
rerunning the diagnostics script.
</step_1>

<step_2>
If current evidence is missing or stale, run the diagnostics script:

```powershell
pwsh -NoProfile -File scripts/azure-psu-diagnostics.ps1 -Json
```

Use larger `-JobLimit` or `-LogLineCount` only when the question needs more
history.
</step_2>

<step_3>
Apply the preflight gate.

Hard blockers:
- `Alive` failed or reports `loading=true`
- `PSUVersion`, `CIEMApp`, `CIEMModule`, or `Runtime` failed
- `AppTokens.Count` is `0`
- `AppSettings.SecurityModel` is not `Permissive` or `Integrated`
- the runtime lacks the active Azure auth profile required for the requested
  Azure validation

Control-plane warnings:
- `WebApp`, `Instances`, `InstanceStatus`, or `LogExcerpts` failed while runtime
  sections are healthy

Treat hard blockers as "stop broad Azure work and debug the instance first."
Treat control-plane warnings as "the instance may still be healthy, but Azure or
Kudu visibility is degraded."
</step_3>

<step_4>
If the gate fails, switch to [debug-instance.md](debug-instance.md). Do not
start broad Azure tests, broad publish retries, or full web app restarts before
the failure plane is understood.
</step_4>

<step_5>
If the gate passes but the user still needs runtime proof, run one combined
runtime probe instead of several smaller ones. Use the example in
[references/inspection-tools.md](../references/inspection-tools.md).
</step_5>

<step_6>
Report the preflight state with exact timestamps and the blocking sections by
name. Be explicit about whether the concern is PSU runtime health, Azure control
plane visibility, or both.
</step_6>
</process>

<success_criteria>
- [ ] The last diagnostics transcript was considered before rerunning long checks
- [ ] A current diagnostics report exists when the user needs live Azure state
- [ ] Hard blockers and control-plane warnings are separated correctly
- [ ] Azure-dependent work proceeds only when the runtime gate is actually green
</success_criteria>
