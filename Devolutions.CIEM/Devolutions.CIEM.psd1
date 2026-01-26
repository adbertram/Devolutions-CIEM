@{
    # Module manifest for Devolutions.CIEM
    # Cloud Infrastructure Entitlement Management

    # Script module or binary module file associated with this manifest.
    RootModule = 'Devolutions.CIEM.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.0'

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
    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '4.0.0' }
    )

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = '*'

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
            Tags = @('Azure', 'CIEM', 'Security', 'Identity', 'IAM', 'Entra', 'RBAC', 'Compliance')

            # A URL to the license for this module.
            # LicenseUri = ''

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/Devolutions/Devolutions-CIEM'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = @'
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
            Prerelease = 'alpha'
        }
    }
}
