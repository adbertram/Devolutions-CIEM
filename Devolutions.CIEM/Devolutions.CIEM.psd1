@{
    # Module manifest for Devolutions.CIEM
    # Cloud Infrastructure Entitlement Management

    # Script module or binary module file associated with this manifest.
    RootModule = 'Devolutions.CIEM.psm1'

    # Version number of this module.
    ModuleVersion = '0.2.4'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = '9366afae-77e5-4cdd-ac2a-92846dc31d9c'

    # Author of this module
    Author = 'Adam Bertram'

    # Company or vendor of this module
    CompanyName = 'Devolutions Inc.'

    # Copyright statement for this module
    Copyright = '(c) 2025 Devolutions Inc. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Cloud Infrastructure Entitlement Management (CIEM) module for Azure identity and access security checks. Provides 46 identity-focused checks for Entra ID, IAM/RBAC, KeyVault, and Storage services.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.4'

    # Modules that must be imported into the global environment prior to importing this module
    # Az.Accounts is auto-installed by the module loader (psm1) if not present
    RequiredModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Get-CIEMAuthenticationContext',
        'Get-CIEMCheck',
        'Get-CIEMProvider',
        'Get-ProwlerCheck',
        'Invoke-CIEMScan',
        'New-DevolutionsCIEMApp',
        'Sync-ProwlerCheck'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Azure', 'CIEM', 'Security', 'Identity', 'IAM', 'Entra', 'RBAC', 'Compliance', 'PowerShellUniversal', 'app')

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/Devolutions/Devolutions-CIEM'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
## 0.2.4 - PSU App Auto-Registration Fix
- Fixed: Include .universal directory in published module
- PSU now auto-discovers and creates the CIEM app when module is installed
- App registration uses -Module/-Command pattern for PSU Gallery compatibility

## 0.2.3 - Az.Accounts Auto-Install
- Auto-installs Az.Accounts when module loads if not present
- Removed RequiredModules dependency (PSU Gallery does not auto-install dependencies)
- Removed runtime checks from individual functions (handled at module load)
- Module now works out-of-the-box when installed from PSU Gallery

## 0.2.2 - PSU App Load Fix
- Removed Az.Accounts from RequiredModules to fix PSU app loading
- Az.Accounts was preventing module import on servers without Azure modules
- Added runtime module checks to Get-CIEMAuthenticationContext and Invoke-CIEMScan
- PSU app now loads without Azure modules; scans require Az.Accounts at runtime

## 0.2.0 - PSU App Integration
- Added New-DevolutionsCIEMApp function for PSU module-based discovery
- Switched from -FilePath to -Module/-Command pattern for PSU Gallery compatibility
- App now auto-discovers when module is installed to PSU Modules directory

## 0.1.0 - Initial Release
- 46 Azure identity-focused security checks
- Entra ID: 15 checks (MFA, conditional access, security defaults, etc.)
- IAM/RBAC: 3 checks (custom roles, permissions)
- KeyVault: 10 checks (access policies, RBAC, expiration)
- Storage: 18 checks (access controls, encryption, network rules)
- Parallel check execution with ForEach-Object -Parallel
- Auto-detect Azure authentication (Managed Identity, CLI, Interactive)
'@

            # Prerelease string of this module
            # Prerelease = ''
        }
    }
}
