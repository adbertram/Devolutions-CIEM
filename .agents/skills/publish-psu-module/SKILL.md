---
name: "publish-psu-module"
description: >
  MANDATORY: Use this skill when publishing a new Devolutions.CIEM version to
  PowerShell Gallery. PSGallery-only — DOES NOT install into any PSU instance.
  Use `deploy-psu-module` for installing a published version into local or
  Azure PSU. DO NOT run Publish-PSUModule ad hoc without this workflow.
---

<objective>
Publish the Devolutions.CIEM module to PowerShell Gallery via
`Devolutions.CIEM.Admin\Publish-PSUModule`, after bumping the manifest version
using the rationale below. This skill never deploys to a PSU instance.
</objective>

<quick_start>
1. Inspect the pending change set and choose the semantic version bump (`Patch`, `Minor`, or `Major`).
2. Run `Publish-PSUModule -ModulePath ./psu-app -BumpVersion <Patch|Minor|Major>` from the repository root.
3. Report the published version and Gallery URL.
4. If the user also wants the new version installed into a PSU instance, hand off to `deploy-psu-module`.
</quick_start>

<workflow>
<step_1>
Run commands from the repository root containing `Devolutions.CIEM.Admin` and `psu-app`.
</step_1>

<step_2>
Determine the semantic version bump. Do not rely on the default. Always pass
`-BumpVersion` explicitly.

Inspect the change set first:

```powershell
git status --short
git diff --stat
git diff --name-only
```

Classify the highest-impact change:

- `Major`: breaking public/module contract changes, removed or renamed exported commands, incompatible parameter changes, incompatible schema or persisted-data changes, required manual migrations, removed UI/API workflows, changed authentication/profile formats, or behavior changes that make existing automation invalid.
- `Minor`: backwards-compatible user-visible capability, new exported command, new PSU page or workflow, new provider/check/attack-path capability, additive schema changes, new optional parameters, or new configuration that existing users can ignore.
- `Patch`: bug fix, test fix, documentation-only change, internal refactor with no public behavior change, performance improvement with the same contract, or republish of equivalent behavior.

If multiple categories apply, choose the highest: `Major` > `Minor` > `Patch`.
If the impact is ambiguous after inspecting the diff, ask the user one targeted
question and include your recommended bump. Do not publish until the ambiguity
is resolved.
</step_2>

<step_3>
Publish to PSGallery:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app -BumpVersion <Patch|Minor|Major>"
```

This bumps the manifest, publishes via `Publish-PSResource`, and verifies the
new version appears in the Gallery. It does NOT connect to any PSU instance,
install the module into PSU, or restart any app.
</step_3>

<step_4>
Report the new version, the bump category with diff-based rationale, and the
Gallery URL. If the user wants the version installed into a PSU instance,
recommend `deploy-psu-module` next.
</step_4>
</workflow>

<safety>
- `Publish-PSUModule` is PSGallery-only. It does not call `Connect-PSU`,
  `Install-PSUModule`, `Restart-CIEMPSUApp`, or any PSU-side operation.
- Requires `NUGET_API_KEY` from environment or `.env`. If missing, the command
  throws with the exact options for setting one.
- The published package excludes `Tests/`, `ui/e2e/`, `node_modules/`,
  `playwright-report/`, `test-results/`, `source-packs/`, and all `*.db`,
  `*.db-shm`, `*.db-wal`, `*.log` files.
- Do not bump and republish to "fix" a PSU import failure. PSU import is
  `deploy-psu-module`'s problem; fix it there.
</safety>

<success_criteria>
- The publish command completes without error.
- The chosen `Patch`, `Minor`, or `Major` bump is reported with the diff-based rationale.
- The new module version and Gallery URL are reported.
- No PSU connection or installation was attempted.
</success_criteria>
