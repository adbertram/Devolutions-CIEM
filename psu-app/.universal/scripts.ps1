# PSU Script Registration for Devolutions CIEM
# Module scripts must use -Module/-Command (not -FilePath)

New-PSUScript -Module 'Devolutions.CIEM' -Command 'New-CIEMScanRun' `
    -Description 'Run a CIEM security scan against configured cloud providers' `
    -TimeOut 30

New-PSUScript -Module 'Devolutions.CIEM' -Command 'Start-CIEMAzureDiscovery' `
    -Description 'Discover Azure ARM and Entra resources and store in the local database' `
    -TimeOut 600
