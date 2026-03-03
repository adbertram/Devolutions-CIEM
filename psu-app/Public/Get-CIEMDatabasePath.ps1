function Get-CIEMDatabasePath {
    <#
    .SYNOPSIS
        Returns the resolved path to the CIEM SQLite database.
    .DESCRIPTION
        Exposes the module-scoped database path, triggering lazy-init via
        New-CIEMDatabase if not yet resolved. Used by other modules that need
        direct database access for transactions.
    .OUTPUTS
        [string] Absolute path to the ciem.db file.
    .EXAMPLE
        $conn = Open-PSUSQLiteConnection -Database (Get-CIEMDatabasePath)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if (-not $script:DatabasePath) {
        $script:DatabasePath = New-CIEMDatabase -PassThru
    }
    $script:DatabasePath
}
