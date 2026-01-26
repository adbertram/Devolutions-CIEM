# Devolutions CIEM App Registration
# This file registers the app with PowerShell Universal

New-PSUApp -Name "DevolutionsCIEM" -FilePath "apps\DevolutionsCIEM\app.ps1" -BaseUrl "/ciem" -Description "Cloud Infrastructure Entitlement Management - Security Findings Dashboard" -AutoDeploy -DisableAutoStart:$false
