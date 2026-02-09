function Test-SqlserverVaScanReportsConfigured {
    <#
    .SYNOPSIS
        SQL server has Vulnerability Assessment enabled and scan report recipients configured

    .DESCRIPTION
        **Azure SQL Server** vulnerability assessment uses **recurring scans** and emails results to designated recipients. This evaluates that VA is enabled and that `Send scan reports to` (or subscription admin notifications) is configured so scan reports are delivered.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: sqlserver_va_scan_reports_configured

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check sqlserver_va_scan_reports_configured for reference.', 'N/A', 'sqlserver Resources')
}
