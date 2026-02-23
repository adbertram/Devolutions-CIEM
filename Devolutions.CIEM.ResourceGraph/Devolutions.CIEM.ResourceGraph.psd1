@{
    RootModule           = 'Devolutions.CIEM.ResourceGraph.psm1'
    ModuleVersion        = '0.1.0'
    CompatiblePSEditions = 'Core'
    GUID                 = 'a3f7e2c1-9d84-4b6e-8f12-3c5a7d9e0b41'
    Author               = 'Adam Bertram'
    CompanyName          = 'Devolutions Inc.'
    Copyright            = '(c) 2026 Devolutions Inc. All rights reserved.'
    Description          = 'Schema-driven Azure resource dependency graph builder (PoC)'
    PowerShellVersion    = '7.4'
    FunctionsToExport    = @('*')
    CmdletsToExport      = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags = 'Azure','CIEM','Security','ResourceGraph','ARM','Dependencies'
            ProjectUri = 'https://github.com/Devolutions/Devolutions-CIEM'
        }
    }
}
