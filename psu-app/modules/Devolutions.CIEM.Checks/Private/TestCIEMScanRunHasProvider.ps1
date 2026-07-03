function TestCIEMScanRunHasProvider {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScanRunId,

        [Parameter(Mandatory)]
        [string]$Provider
    )

    $ErrorActionPreference = 'Stop'

    $canonicalProvider = @(ConvertToCIEMCanonicalProviderList -Providers @($Provider))[0]
    $row = Invoke-CIEMQuery -Query @'
SELECT 1 AS found
FROM scan_run_providers
WHERE scan_run_id = @scan_run_id
AND provider = @provider
LIMIT 1
'@ -Parameters @{
        scan_run_id = $ScanRunId
        provider    = $canonicalProvider
    }

    $null -ne $row
}
