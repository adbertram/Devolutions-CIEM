---
name: psu-app-tester
description: "MANDATORY for ANY PSU app testing. Triggers: test psu, test the psu, psu test, verify psu, check psu, psu app."
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, WebSearch, mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot, mcp__playwright__browser_click, mcp__playwright__browser_fill_form, mcp__playwright__browser_type, mcp__playwright__browser_wait_for
---

<objective>
Test, publish, and debug the Devolutions CIEM PowerShell Universal (PSU) app. Manages the complete testing lifecycle from code changes through Playwright UI verification.
</objective>

<quick_start>
1. For UI testing: Navigate with Playwright, take snapshots, interact with elements
2. For publishing: Run Publish-PSUModule, then restart the app
3. For debugging: Run `./scripts/get-psu-logs.sh 100 --search "CIEM"` first, then check app status
</quick_start>

<essential_principles>
ALWAYS restart the PSU app after publishing a new module version.

PSU app URL has double path: `https://devolutions-ciem-psu.azurewebsites.net/ciem/ciem/[page]`

Use `mcp__playwright__browser_snapshot` to see page state (better than screenshots).

Module changes require: edit code → publish → restart app → test.

PSU secrets use `-Vault 'Database'` (not BuiltInLocalVault) on Linux/Azure.

When docs don't have the answer, use WebSearch for PSU v5 documentation.
</essential_principles>

<project_structure>
Module: `./Devolutions.CIEM/Devolutions.CIEM.psm1` (contains New-DevolutionsCIEMApp)
Manifest: `./Devolutions.CIEM/Devolutions.CIEM.psd1`
Management: `./scripts/PSUniversal.psm1` (Publish-PSUModule, Connect-PSU, Restart-PSUApp)
PSU Docs: `./prowler/docs/psu-docs/`
Azure URL: https://devolutions-ciem-psu.azurewebsites.net/ciem/ciem/
</project_structure>

<intake>
Determine user intent:
1. Testing UI? → workflows/test.md
2. Publishing changes? → workflows/publish.md
3. Debugging issues? → workflows/debug.md
</intake>

<routing>
| User Intent | Workflow | Indicators |
|-------------|----------|------------|
| Test UI with Playwright | workflows/test.md | "test", "playwright", "verify", "check page" |
| Publish module changes | workflows/publish.md | "publish", "deploy", "update", "push" |
| Debug issues | workflows/debug.md | "error", "not working", "debug", "logs" |
</routing>

<reference_index>
PSU Documentation: `./prowler/docs/psu-docs/`
- apps/ - PSU App component docs
- cmdlets/ - PSU cmdlet reference
- platform/variables.md - Secret management
</reference_index>

<success_criteria>
- UI tests verify expected elements present and functional
- Module publishes to PSGallery and imports to PSU
- Debug workflows identify root cause with evidence
</success_criteria>
