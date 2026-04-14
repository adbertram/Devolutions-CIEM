function Resolve-PSUSQLiteAssembly {
    <#
    .SYNOPSIS
        Loads the Microsoft.Data.Sqlite assembly from PSU's installation directory.
    .DESCRIPTION
        Checks if the assembly is already loaded (running inside PSU integrated environment),
        then probes the current process directory and known PSU install locations.
    #>
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    # Check if already loaded (e.g. running inside PSU integrated environment)
    $loaded = [System.AppDomain]::CurrentDomain.GetAssemblies() |
        Where-Object { $_.GetName().Name -eq 'Microsoft.Data.Sqlite' }

    if ($loaded) {
        Write-Verbose "PSUSQLite: Microsoft.Data.Sqlite already loaded (v$($loaded.GetName().Version))"
        return
    }

    # Build candidate directories to search
    $candidates = @()

    # 1. Current process directory (running inside PSU host process)
    $processDir = [System.IO.Path]::GetDirectoryName(
        [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    )
    $candidates += $processDir

    # 2. Known PSU install locations
    $candidates += "$HOME/.local/share/powershell-universal"
    $candidates += "$env:ProgramData/PowerShellUniversal"
    $candidates += '/opt/powershell-universal'
    $candidates += "$env:ProgramFiles/PowerShell Universal"

    foreach ($dir in $candidates) {
        if (-not $dir -or -not (Test-Path $dir)) { continue }

        $sqliteDll = Join-Path $dir 'Microsoft.Data.Sqlite.dll'
        if (-not (Test-Path $sqliteDll)) { continue }

        # Load SQLitePCLRaw dependencies first (required for native interop)
        $rawAssemblies = @(
            'SQLitePCLRaw.core.dll'
            'SQLitePCLRaw.provider.e_sqlite3.dll'
            'SQLitePCLRaw.batteries_v2.dll'
        )

        foreach ($raw in $rawAssemblies) {
            $rawPath = Join-Path $dir $raw
            if (Test-Path $rawPath) {
                try {
                    Add-Type -Path $rawPath -ErrorAction Stop
                } catch [System.Reflection.ReflectionTypeLoadException] {
                    # Already loaded or type conflict — safe to continue
                } catch {
                    Write-Verbose "PSUSQLite: Could not load ${raw}: $_"
                }
            }
        }

        # Load Microsoft.Data.Sqlite
        try {
            Add-Type -Path $sqliteDll -ErrorAction Stop
        } catch [System.Reflection.ReflectionTypeLoadException] {
            # Already loaded
        }

        # Initialize the native SQLite provider
        try {
            [SQLitePCL.Batteries_V2]::Init()
        } catch {
            Write-Verbose "PSUSQLite: SQLitePCLRaw init skipped: $_"
        }

        Write-Verbose "PSUSQLite: Loaded Microsoft.Data.Sqlite from $dir"
        return
    }

    throw 'PSUSQLite: Cannot find Microsoft.Data.Sqlite.dll. Ensure PowerShell Universal is installed.'
}
