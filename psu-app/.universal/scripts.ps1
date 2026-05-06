$ErrorActionPreference = 'Stop'

Import-Module Devolutions.CIEM -ErrorAction Stop

$managedScriptNotes = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json'

New-PSUScript -Module 'Devolutions.CIEM' -Command 'New-CIEMScanRun' -Description 'Run a CIEM security scan against configured cloud providers' -Status 'Published' -TimeOut 30 -Notes $managedScriptNotes
New-PSUScript -Module 'Devolutions.CIEM' -Command 'Start-CIEMAzureDiscovery' -Description 'Discover Azure ARM and Entra resources and store in the local database' -Status 'Published' -TimeOut 600 -Notes $managedScriptNotes
New-PSUScript -Module 'Devolutions.CIEM' -Command 'Invoke-CIEMAttackPathRemediation' -Description 'Execute the resolved remediation script for a CIEM attack path' -Status 'Published' -TimeOut 600 -Notes $managedScriptNotes
