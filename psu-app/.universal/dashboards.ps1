# PSU App Registration for Devolutions CIEM
# This file is auto-discovered by PowerShell Universal when the module is installed

New-PSUApp -Name 'Devolutions CIEM' -BaseUrl '/ciem' -Module 'Devolutions.CIEM' -Command 'New-DevolutionsCIEMApp' -Authenticated -Role @('User', 'Administrator') -Description 'Cloud Infrastructure Entitlement Management (CIEM) - Azure identity and access security scanner'
