function Get-CIEMDatabasePath {
    <#
    .SYNOPSIS
        Returns the resolved path to the CIEM SQLite database.
    .DESCRIPTION
        Exposes the module-scoped database path. This function only resolves
        the expected path; it does not create the database.
    .OUTPUTS
        [string] Absolute path to the ciem.db file.
    .EXAMPLE
        $conn = Open-PSUSQLiteConnection -Database (Get-CIEMDatabasePath)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $ErrorActionPreference = 'Stop'

    if (-not $script:DatabasePath) {
        if (-not $script:DataRoot) {
            throw 'Get-CIEMDatabasePath: $script:DataRoot is not set. Module not loaded correctly.'
        }
        $script:DatabasePath = Join-Path $script:DataRoot 'ciem.db'
    }
    $script:DatabasePath
}
