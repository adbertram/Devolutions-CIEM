@{
    RootModule           = 'Devolutions.CIEM.Base.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'b4a1c2d3-5e6f-7890-abcd-ef1234567890'
    Author               = 'Adam Bertram'
    CompanyName          = 'Devolutions Inc.'
    Copyright            = '(c) Devolutions Inc. All rights reserved.'
    Description          = 'CIEM Base module — authentication, configuration, API queries, service data collection, and database management.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')
    RequiredModules      = @(
        @{ ModuleName = 'PSUSQLite'; ModuleVersion = '0.1.0' }
    )
    FunctionsToExport    = @(
        # Auth
        'Connect-CIEM'
        'Get-CIEMAuthenticationContext'
        'Save-CIEMAuthenticationContext'
        'Test-CIEMAuthenticationContext'
        # Config
        'Get-CIEMConfig'
        'Set-CIEMConfig'
        'Reset-CIEMConfig'
        'Get-CIEMDefaultConfig'
        'Get-CIEMSecret'
        # Providers
        'Get-CIEMProvider'
        'New-CIEMProvider'
        'Update-CIEMProvider'
        'Remove-CIEMProvider'
        # Database
        'New-CIEMDatabase'
        # Logging
        'Write-CIEMLog'
    )
    CmdletsToExport      = @()
    VariablesToExport     = @()
    AliasesToExport       = @()
    PrivateData          = @{
        PSData = @{
            Tags       = @('CIEM', 'Cloud', 'Identity', 'Security', 'Azure', 'AWS')
            ProjectUri = 'https://github.com/Devolutions/CIEM'
        }
    }
}
