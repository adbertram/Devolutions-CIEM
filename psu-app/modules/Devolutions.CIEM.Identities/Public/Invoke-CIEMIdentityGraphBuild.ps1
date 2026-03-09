function Invoke-CIEMIdentityGraphBuild {
    <#
    .SYNOPSIS
        Collects identity data and builds the identity graph in a single operation.

    .DESCRIPTION
        Combines New-CIEMIdentityScanRun and Update-CIEMIdentityGraph into a single
        entry point suitable for PSU Job execution. Reports progress via Write-Progress
        so PSU can surface status through Get-PSUJob.

    .PARAMETER Provider
        Cloud provider to collect and graph. Defaults to 'Azure'.

    .OUTPUTS
        [PSCustomObject] Exported identity graph.

    .EXAMPLE
        Invoke-CIEMIdentityGraphBuild -Provider 'Azure'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$Provider = 'Azure'
    )

    $ErrorActionPreference = 'Stop'

    Write-Progress -Activity 'Identity Graph Build' -Status 'Collecting identity data...' -PercentComplete 5

    New-CIEMIdentityScanRun -Provider $Provider

    Write-Progress -Activity 'Identity Graph Build' -Status 'Building identity graph...' -PercentComplete 50

    $graph = Update-CIEMIdentityGraph -Provider $Provider

    Write-Progress -Activity 'Identity Graph Build' -Status 'Complete' -PercentComplete 100
    Write-Progress -Activity 'Identity Graph Build' -Completed

    $graph
}
