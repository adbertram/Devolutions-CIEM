---
description: Safe usage of PSU admin cmdlets and local PSU operations
paths: ["Devolutions.CIEM.Admin/**", "scripts/**"]
---

# PSU Admin Cmdlet Safety

Before using ANY PSU cmdlet (Get-PSUApp, Start-PSUApp, Remove-PSUApp, etc.), verify it exists and check its parameters:
```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Get-Command *PSUApp* | Select-Object Name"
```

Always suppress Connect-PSU output when chaining commands:
```powershell
$null = Connect-PSU -Local; <next command>
```

## NEVER Reset Local PSU Without User Approval

`setup-local-psu.sh reset` destroys all local PSU state (license, tokens, app registrations, dev mode settings). Follow the escalation ladder in CLAUDE.md Troubleshooting section instead.
