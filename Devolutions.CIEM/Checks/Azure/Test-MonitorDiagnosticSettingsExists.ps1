function Test-MonitorDiagnosticSettingsExists {
    <#
    .SYNOPSIS
        Subscription has an Activity Log diagnostic setting

    .DESCRIPTION
        **Azure Monitor Diagnostic Settings** are configured to export the **Activity Log** to an external destination (Log Analytics, Storage, Event Hub, or partner).

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: monitor_diagnostic_settings_exists

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check monitor_diagnostic_settings_exists for reference.', 'N/A', 'monitor Resources')
}
