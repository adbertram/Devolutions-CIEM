@{
    RootModule        = 'PSUSQLite.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a3f7b2c1-9d4e-4f8a-b5c6-1e2d3f4a5b6c'
    Author            = 'Devolutions'
    CompanyName       = 'Devolutions'
    Description       = 'Lightweight SQLite module for PowerShell Universal. Uses Microsoft.Data.Sqlite from the PSU installation.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Invoke-PSUSQLiteQuery'
        'Open-PSUSQLiteConnection'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('SQLite', 'Database', 'PSU', 'PowerShellUniversal')
            ProjectUri = 'https://github.com/Devolutions/CIEM'
        }
    }
}
