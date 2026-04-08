function Initialize-DiscoveryTestDatabase {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    foreach ($schemaPath in @(
        (Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'),
        (Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql')
    )) {
        foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            $trimmed = $statement.Trim()
            try {
                Invoke-CIEMQuery -Query $trimmed -AsNonQuery | Out-Null
            }
            catch {
                if ($trimmed -match 'ALTER\s+TABLE' -and $_.Exception.Message -match 'duplicate column') {
                    continue
                }
                throw
            }
        }
    }
}
