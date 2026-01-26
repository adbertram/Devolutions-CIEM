@{
    # Module identification
    RootModule        = 'DevolutionsCIEM.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author information
    Author            = 'Devolutions'
    CompanyName       = 'Devolutions'
    Copyright         = '(c) 2026 Devolutions. All rights reserved.'

    # Module description
    Description       = 'Cloud Infrastructure Entitlement Management (CIEM) tool that scans Azure and AWS permissions and produces JSON reports for LLM analysis.'

    # Minimum PowerShell version
    PowerShellVersion = '5.1'

    # Required modules
    RequiredModules   = @(
        # Azure modules loaded on-demand based on provider
        # @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' }
        # @{ ModuleName = 'Az.Resources'; ModuleVersion = '6.0.0' }
        # AWS modules loaded on-demand based on provider
        # @{ ModuleName = 'AWS.Tools.Common'; ModuleVersion = '4.0.0' }
        # @{ ModuleName = 'AWS.Tools.IdentityManagement'; ModuleVersion = '4.0.0' }
    )

    # Functions to export
    FunctionsToExport = @(
        # Orchestration
        'Start-CIEMScan'

        # Discovery phase
        'Invoke-CIEMDiscovery'

        # Analysis phase
        'Invoke-CIEMAnalysis'

        # Reporting phase
        'Invoke-CIEMReport'
        'Get-CIEMFinding'
    )

    # Cmdlets, variables, and aliases to export
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Private data
    PrivateData       = @{
        PSData = @{
            Tags         = @('CIEM', 'Azure', 'AWS', 'Security', 'Permissions', 'RBAC', 'IAM')
            LicenseUri   = 'https://github.com/Devolutions/Devolutions-CIEM/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/Devolutions/Devolutions-CIEM'
            ReleaseNotes = 'Initial release - MVP with Azure and AWS scanning support.'
        }
    }
}
