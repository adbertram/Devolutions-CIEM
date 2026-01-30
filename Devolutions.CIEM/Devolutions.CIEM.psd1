@{
    # Module manifest for Devolutions.CIEM
    # Cloud Infrastructure Entitlement Management

    # Script module or binary module file associated with this manifest.
    RootModule = 'Devolutions.CIEM.psm1'

    # Version number of this module.
    ModuleVersion = '0.2.44'

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
    # Note: Dependencies are auto-installed by the PSM1 for PSU Gallery compatibility
    RequiredModules = @()

    # Functions to export from this module - controlled by Export-ModuleMember in the .psm1 file
    FunctionsToExport = @('*')

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()

    # List of all files packaged with this module (explicitly include .universal for PSU auto-discovery)
    FileList = @(
        '.universal\dashboards.ps1',
        'AzureChecks.json',
        'AzureChecks.schema.json',
        'Checks/Azure/Test-EntraConditionalAccessPolicyRequireMfaForManagementApi.ps1',
        'Checks/Azure/Test-EntraNonPrivilegedUserHasMfa.ps1',
        'Checks/Azure/Test-EntraPolicyDefaultUserCannotCreateSecurityGroup.ps1',
        'Checks/Azure/Test-EntraPolicyEnsureDefaultUserCannotCreateApp.ps1',
        'Checks/Azure/Test-EntraPolicyEnsureDefaultUserCannotCreateTenant.ps1',
        'Checks/Azure/Test-EntraPolicyGuestInviteOnlyForAdminRole.ps1',
        'Checks/Azure/Test-EntraPolicyGuestUserAccessRestriction.ps1',
        'Checks/Azure/Test-EntraPolicyRestrictUserConsentForApp.ps1',
        'Checks/Azure/Test-EntraPolicyUserConsentForVerifiedApp.ps1',
        'Checks/Azure/Test-EntraPrivilegedUserHasMfa.ps1',
        'Checks/Azure/Test-EntraSecurityDefaultsEnabled.ps1',
        'Checks/Azure/Test-EntraTrustedNamedLocationExist.ps1',
        'Checks/Azure/Test-EntraUserCannotCreateMicrosoft365Group.ps1',
        'Checks/Azure/Test-EntraUserWithVmAccessHasMfa.ps1',
        'Checks/Azure/Test-IamCustomRoleHasPermissionToAdministerResourceLock.ps1',
        'Checks/Azure/Test-IamRoleUserAccessAdminRestricted.ps1',
        'Checks/Azure/Test-IamSubscriptionRolesOwnerCustomNotCreated.ps1',
        'Checks/Azure/Test-KeyvaultKeyExpirationSetInNonRbac.ps1',
        'Checks/Azure/Test-KeyvaultKeyRotationEnabled.ps1',
        'Checks/Azure/Test-KeyvaultLoggingEnabled.ps1',
        'Checks/Azure/Test-KeyvaultNonRbacSecretExpirationSet.ps1',
        'Checks/Azure/Test-KeyvaultPrivateEndpoint.ps1',
        'Checks/Azure/Test-KeyvaultPublicNetworkAccessDisabled.ps1',
        'Checks/Azure/Test-KeyvaultRbacEnabled.ps1',
        'Checks/Azure/Test-KeyvaultRbacKeyExpirationSet.ps1',
        'Checks/Azure/Test-KeyvaultRbacSecretExpirationSet.ps1',
        'Checks/Azure/Test-KeyvaultRecoverable.ps1',
        'Checks/Azure/Test-StorageAccountKeyAccessDisabled.ps1',
        'Checks/Azure/Test-StorageBlobPublicAccessLevelIsDisabled.ps1',
        'Checks/Azure/Test-StorageBlobVersioningIsEnabled.ps1',
        'Checks/Azure/Test-StorageCrossTenantReplicationDisabled.ps1',
        'Checks/Azure/Test-StorageDefaultNetworkAccessRuleIsDenied.ps1',
        'Checks/Azure/Test-StorageDefaultToEntraAuthorizationEnabled.ps1',
        'Checks/Azure/Test-StorageEnsureAzureServicesAreTrustedToAccessIsEnabled.ps1',
        'Checks/Azure/Test-StorageEnsureEncryptionWithCustomerManagedKey.ps1',
        'Checks/Azure/Test-StorageEnsureFileSharesSoftDeleteIsEnabled.ps1',
        'Checks/Azure/Test-StorageEnsureMinimumTlsVersion12.ps1',
        'Checks/Azure/Test-StorageEnsurePrivateEndpointInStorageAccount.ps1',
        'Checks/Azure/Test-StorageEnsureSoftDeleteIsEnabled.ps1',
        'Checks/Azure/Test-StorageGeoRedundantEnabled.ps1',
        'Checks/Azure/Test-StorageInfrastructureEncryptionIsEnabled.ps1',
        'Checks/Azure/Test-StorageKeyRotation90Day.ps1',
        'Checks/Azure/Test-StorageSecureTransferRequiredIsEnabled.ps1',
        'Checks/Azure/Test-StorageSmbChannelEncryptionWithSecureAlgorithm.ps1',
        'Checks/Azure/Test-StorageSmbProtocolVersionIsLatest.ps1',
        'config.json',
        'Devolutions.CIEM.psd1',
        'Devolutions.CIEM.psm1',
        'Private/Assert-CIEMAuthenticated.ps1',
        'Private/Convert-ProwlerCheck.ps1',
        'Private/Get-AllGraphPage.ps1',
        'Public/Get-CIEMConfigPath.ps1',
        'Private/Get-AzureAuthContext.ps1',
        'Private/Get-CheckMetadata.ps1',
        'Private/Get-CIEMConfig.ps1',
        'Private/Get-SupportedProvider.ps1',
        'Private/Initialize-EntraService.ps1',
        'Private/Initialize-IAMService.ps1',
        'Private/Initialize-KeyVaultService.ps1',
        'Private/Initialize-StorageService.ps1',
        'Private/Invoke-AzureApi.ps1',
        'Private/New-CIEMFinding.ps1',
        'Private/Set-CIEMConfig.ps1',
        'Private/Test-AzureChecksSchema.ps1',
        'Private/Test-AzureConnection.ps1',
        'Private/Test-EntraAuthorizationPolicyBooleanSetting.ps1',
        'Private/Test-GitRemote.ps1',
        'Private/Test-KeyVaultItemExpiration.ps1',
        'Private/Test-StorageAccountProperty.ps1',
        'Public/Connect-CIEM.ps1',
        'Public/Get-CIEMAuthenticationContext.ps1',
        'Public/Get-CIEMCheck.ps1',
        'Public/Get-CIEMProvider.ps1',
        'Public/Get-CIEMRequiredPermission.ps1',
        'Public/Get-PSUInstalledEnvironment.ps1',
        'Public/New-CIEMAzureManagedIdentity.ps1',
        'Public/New-PSUAzureServicePrincipal.ps1',
        'Public/Get-ProwlerCheck.ps1',
        'Public/Invoke-CIEMScan.ps1',
        'Public/Sync-ProwlerCheck.ps1',
        'Public/Test-CIEMAuthenticated.ps1'
    )

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
## 0.2.20 - Dashboard Function Scope Fix
- Fixed: Get-CIEMConfigPath not found at dashboard runtime
- Moved Get-CIEMConfigPath from nested function to Private module function
- Function is now dot-sourced at module load, available to PSU dashboard pages

## 0.2.19 - Code Quality Improvements
- Renamed Get-CIEMRequiredPermissions to Get-CIEMRequiredPermission (singular noun)
- Fixed PSScriptAnalyzer warnings for return statements
- Fixed helper function naming to avoid ShouldProcess requirements
- Improved code structure in Get-PSUInstalledEnvironment and Get-CIEMRequiredPermission
- Added proper begin/process block structure to Set-CIEMConfig
- Added suppression attributes for PSU dashboard callback return statements

## 0.2.14 - Multi-Provider Authentication Support
- Renamed "Azure Authentication" to "Cloud Provider Authentication"
- Added Provider dropdown (Azure enabled, AWS coming soon)
- Added comprehensive Azure authentication methods:
  - Current Context (existing Az PowerShell session)
  - Service Principal with Client Secret
  - Service Principal with Certificate (thumbprint or file path)
  - Managed Identity (system-assigned or user-assigned)
  - Device Code (for MFA/restricted environments)
  - Interactive Browser
- Dynamic input fields based on selected authentication method
- Updated config.json schema for multi-provider support
- Prepared AWS configuration structure for future release

## 0.2.12 - PSU Environment Auto-Detection
- Added Get-PSUInstalledEnvironment function to detect Azure Web App vs on-premises deployment
- Configuration page now displays deployment environment with visual indicator
- Managed Identity auth option shows warning when running on-premises
- Prevents saving Managed Identity configuration in unsupported environments

## 0.2.7 - PSResourceGet Publishing Fix
- Switched from Publish-Module to Publish-PSResource for publishing
- Root cause: PowerShellGet v2's Publish-Module uses Get-ChildItem WITHOUT -Force
- This excludes hidden directories (.universal) on Unix systems (macOS/Linux)
- PSResourceGet uses .NET Directory.GetFiles/GetDirectories which includes all files
- See: https://github.com/PowerShell/PowerShellGetv2/blob/master/src/PowerShellGet/public/psgetfunctions/Publish-Module.ps1

## 0.2.6 - FileList Fix for .universal Directory (Failed)
- Added explicit FileList to manifest to include .universal/dashboards.ps1
- Publish-Module was excluding dot-prefixed directories without FileList

## 0.2.5 - PSU App Auto-Registration (Republish)
- Republish to verify .universal directory is included in package

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
