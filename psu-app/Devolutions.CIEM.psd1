@{
    RootModule           = 'Devolutions.CIEM.psm1'
    ModuleVersion = '0.3.225'
    GUID                 = 'b8952107-9d81-4324-8605-4d5a1c216ec0'
    Author               = 'Adam Bertram'
    CompanyName          = 'Devolutions Inc.'
    Copyright            = '(c) Devolutions Inc. All rights reserved.'
    Description          = 'Cloud Infrastructure Entitlement Management (CIEM) for PowerShell Universal. Detects dormant permissions, right-sizes roles, maps identity-to-resource relationships, and surfaces attack paths across Azure and AWS.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @('*')
    CmdletsToExport      = @()
    VariablesToExport     = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags       = @('CIEM', 'Cloud', 'Identity', 'Security', 'Azure', 'AWS', 'PowerShellUniversal', 'IAM', 'RBAC')
            ProjectUri = 'https://github.com/Devolutions/CIEM'
        }
    }
}
