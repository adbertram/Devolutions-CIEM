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
    .PARAMETER InputObject
        One or more existing CIEMScanRun objects to pass through.
    .OUTPUTS
        CIEMScanRun
        A new ScanRun object ready for tracking.
    .EXAMPLE
        $scanRun = New-CIEMScanRun -Providers @('Azure', 'AWS') -Services @('Entra', 'IAM')

        Creates a new scan run for Azure and AWS targeting the Entra and IAM services.
    .EXAMPLE
        $scanRun | New-CIEMScanRun

        Passes through an existing CIEMScanRun object.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType([CIEMScanRun])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string[]]$Providers,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string[]]$Services,

        [Parameter(ParameterSetName = 'ByProperties')]
        [bool]$IncludePassed = $false,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMScanRun[]]$InputObject
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $item
            }
        } else {
            $scanRun = [CIEMScanRun]::new($Providers, $Services, $IncludePassed)
            $scanRun.Status = [CIEMScanRunStatus]::Running
            Write-Verbose "Created ScanRun: $($scanRun.Id)"
            return $scanRun
        }
    }
}
