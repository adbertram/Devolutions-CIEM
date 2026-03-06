# PSU Script Registration for Devolutions CIEM
# Module scripts must use -Module/-Command (not -FilePath)

New-PSUScript -Module 'Devolutions.CIEM' -Command 'New-CIEMScanRun' `
    -Description 'Run a CIEM security scan against configured cloud providers' `
    -TimeOut 30
