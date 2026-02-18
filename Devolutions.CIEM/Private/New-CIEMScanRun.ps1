function New-CIEMScanRun {
    <#
    .SYNOPSIS
        Creates a new CIEMScanRun object to track scan execution.
    .DESCRIPTION
        Creates a new CIEMScanRun instance with a unique ID, start time,
        and Running status. Used internally by Invoke-CIEMScan.
    .PARAMETER Providers
        One or more cloud providers being scanned (e.g. 'Azure', 'AWS').
    .PARAMETER Services
        Array of services to be scanned.
    .PARAMETER IncludePassed
        Whether passed checks will be included in results.
    .OUTPUTS
        CIEMScanRun
        A new ScanRun object ready for tracking.
    .EXAMPLE
        $scanRun = New-CIEMScanRun -Providers @('Azure', 'AWS') -Services @('Entra', 'IAM')

        Creates a new scan run for Azure and AWS targeting the Entra and IAM services.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanRun])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Providers,

        [Parameter(Mandatory)]
        [string[]]$Services,

        [Parameter()]
        [bool]$IncludePassed = $false
    )

    $scanRun = [CIEMScanRun]::new($Providers, $Services, $IncludePassed)
    $scanRun.Status = [CIEMScanRunStatus]::Running
    Write-Verbose "Created ScanRun: $($scanRun.Id)"
    return $scanRun
}
