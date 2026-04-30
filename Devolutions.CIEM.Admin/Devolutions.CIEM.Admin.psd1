@{
    RootModule        = 'Devolutions.CIEM.Admin.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'a3b7c9d1-4e5f-6a7b-8c9d-0e1f2a3b4c5d'
    Author            = 'Devolutions'
    CompanyName       = 'Devolutions'
    Description       = 'Admin and developer tools for Devolutions CIEM (Prowler sync, check management, Azure provisioning)'
    RequiredModules   = @()
    FunctionsToExport = @(
        'Connect-PSU'
        'Get-ProwlerCheck'
        'Get-PSUModule'
        'Install-PSUModule'
        'Invoke-CIEMCommand'
        'Invoke-CIEMTest'
        'Invoke-TestCommand'
        'Publish-PSUModule'
        'Remove-PSUModule'
        'Sync-ProwlerCheck'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
}
