function InvokeCIEMAzureSleep {
    <#
    .SYNOPSIS
        Thin wrapper around Start-Sleep to provide a single mockable sleep seam for tests.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$Seconds
    )

    $ErrorActionPreference = 'Stop'

    Start-Sleep -Seconds $Seconds
}
