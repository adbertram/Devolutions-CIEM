function Stop-CIEMAzureDiscovery {
    <#
    .SYNOPSIS
        Cancels any running Azure discovery runs.
    .DESCRIPTION
        Queries the database for discovery runs with status 'Running' and updates them
        to 'Cancelled' with a CompletedAt timestamp. This is called from the Environment
        page's cancel button to stop an in-progress discovery.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $ErrorActionPreference = 'Stop'

    $runningRuns = @(Get-CIEMAzureDiscoveryRun -Status 'Running')
    if ($runningRuns.Count -eq 0) {
        Write-CIEMLog 'Stop-CIEMAzureDiscovery: No running discovery runs to cancel' -Severity INFO -Component 'Discovery'
        return
    }

    foreach ($run in $runningRuns) {
        if ($PSCmdlet.ShouldProcess("Discovery run #$($run.Id)", 'Cancel')) {
            Update-CIEMAzureDiscoveryRun -Id $run.Id `
                -Status 'Cancelled' `
                -CompletedAt (Get-Date).ToString('o') `
                -ErrorMessage 'Cancelled by user' | Out-Null
            Write-CIEMLog "Stop-CIEMAzureDiscovery: Cancelled discovery run #$($run.Id)" -Severity INFO -Component 'Discovery'
        }
    }
}
