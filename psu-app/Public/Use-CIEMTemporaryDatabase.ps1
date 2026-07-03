function Use-CIEMTemporaryDatabase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Temporary database path cannot be blank.'
    }

    $originalPath = Get-CIEMDatabasePath
    try {
        $script:DatabasePath = $Path
        & $ScriptBlock
    }
    finally {
        $script:DatabasePath = $originalPath
    }
}
