function SetCIEMScanRunProviders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Connection,

        [Parameter(Mandatory)]
        [string]$ScanRunId,

        [Parameter(Mandatory)]
        [object[]]$Providers
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($ScanRunId)) {
        throw "Scan run id cannot be blank."
    }

    $canonicalProviders = @(ConvertToCIEMCanonicalProviderList -Providers $Providers -Connection $Connection)

    Invoke-PSUSQLiteQuery -Connection $Connection -Query 'DELETE FROM scan_run_providers WHERE scan_run_id = @scan_run_id' -Parameters @{
        scan_run_id = $ScanRunId
    } -AsNonQuery | Out-Null

    foreach ($provider in $canonicalProviders) {
        Invoke-PSUSQLiteQuery -Connection $Connection -Query @'
INSERT INTO scan_run_providers (scan_run_id, provider)
VALUES (@scan_run_id, @provider)
'@ -Parameters @{
            scan_run_id = $ScanRunId
            provider    = [string]$provider
        } -AsNonQuery | Out-Null
    }
}
