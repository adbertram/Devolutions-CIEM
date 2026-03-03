# PSU Script Registration for Devolutions CIEM
# Registers module commands as PSU scripts for async job execution

New-PSUScript -Module 'Devolutions.CIEM' -Command 'New-CIEMScanRun' `
    -Description 'Run a CIEM security scan against configured cloud providers' `
    -TimeOut 30
