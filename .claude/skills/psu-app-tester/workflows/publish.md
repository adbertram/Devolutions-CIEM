# Publish Workflow - Deploy Module Updates

<required_reading>
Module code: `./Devolutions.CIEM/Devolutions.CIEM.psm1`
Management module: `./scripts/PSUniversal.psm1`
</required_reading>

<process>
## Step 1: Make code changes

Edit the module files as needed:
- Main module: `./Devolutions.CIEM/Devolutions.CIEM.psm1`
- Manifest: `./Devolutions.CIEM/Devolutions.CIEM.psd1`

## Step 2: Publish to PSGallery

```bash
pwsh -NoProfile -Command "Import-Module ./scripts/PSUniversal.psm1; Publish-PSUModule -ModulePath ./Devolutions.CIEM"
```

This command:
1. Validates module structure
2. Auto-bumps patch version
3. Publishes to PowerShell Gallery
4. Auto-connects to PSU and imports the new version

Use `-BumpVersion Minor` or `-BumpVersion Major` for larger changes.
Use `-WhatIf` for dry run.

## Step 3: Restart the PSU App

**CRITICAL: The app MUST be restarted to load the new module version.**

```bash
pwsh -NoProfile -Command "Import-Module ./scripts/PSUniversal.psm1; Connect-PSU | Out-Null; Restart-PSUApp -Name 'Devolutions CIEM'"
```

## Step 4: Wait and verify

Wait 5 seconds for the app to restart, then test the changes.

## Full publish-and-test command

```bash
pwsh -NoProfile -Command "Import-Module ./scripts/PSUniversal.psm1; Publish-PSUModule -ModulePath ./Devolutions.CIEM" && \
sleep 3 && \
pwsh -NoProfile -Command "Import-Module ./scripts/PSUniversal.psm1; Connect-PSU | Out-Null; Restart-PSUApp -Name 'Devolutions CIEM'" && \
sleep 5
```

Then use Playwright to verify.
</process>

<success_criteria>
- Publish completes with "Publication Successful!" message
- Version number increments (e.g., 0.2.36 → 0.2.37)
- Module imports to PSU successfully
- App restarts without errors
- Changes are visible in the UI
</success_criteria>
