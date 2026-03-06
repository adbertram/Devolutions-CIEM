---
name: publish-psu-module
description: Publishes the Devolutions.CIEM module to a PSU instance (local or Azure). Use when deploying, publishing, or importing module changes to PSU.
argument-hint: "[local|azure]"
allowed-tools: Bash, AskUserQuestion
---

<objective>
Imports the Devolutions.CIEM.Admin module and calls Publish-PSUModule to deploy the Devolutions.CIEM module to a PSU instance. Supports both local development and Azure production targets.
</objective>

<quick_start>
Parse $ARGUMENTS to determine target:
- `local` → Local PSU at http://localhost:5001 (skips PSGallery)
- `azure` → Azure PSU (publishes to PSGallery first, then imports)

If no argument provided, ask which target using AskUserQuestion.

Then run the appropriate PowerShell command.
</quick_start>

<workflow>
<step name="parse-target">
Determine target from $ARGUMENTS:
- "local" or "dev" → local
- "azure" or "prod" or "production" → azure
- Empty or unclear → prompt user with AskUserQuestion
</step>

<step name="prompt-if-needed" condition="no valid target">
Use AskUserQuestion with options:
- **Local** - Import to local PSU (http://localhost:5001), skips PSGallery publish
- **Azure** - Publish to PSGallery and import to Azure PSU (production)
</step>

<step name="publish-local" condition="target is local">
```bash
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app -LocalOnly"
```

This skips PSGallery and imports directly to local PSU.
</step>

<step name="publish-azure" condition="target is azure">
```bash
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app"
```

This publishes to PSGallery (auto-bumps version), verifies, then imports to Azure PSU.
</step>
</workflow>

<step name="verify-restart" condition="after publish succeeds">
Verify the publish output includes a successful app restart message. If the output does NOT confirm the app was restarted, run explicitly:
```bash
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Connect-PSU -Local; Restart-PSUApp -Name 'Devolutions CIEM' -Integrated"
```
For azure target, omit `-Local` from `Connect-PSU`.
</step>

<success_criteria>
- PowerShell command completes without error
- Module version and status reported to user
- App restart confirmed (either from publish output or explicit restart step)
- For azure: PSGallery URL provided
</success_criteria>

<validated>
Validated by validate-skill on 2026-02-09 15:48
</validated>
