function Test-MonitorDiagnosticSettingWithAppropriateCategories {
    <#
    .SYNOPSIS
        Subscription has a diagnostic setting capturing Administrative, Security, Alert, and Policy categories

    .DESCRIPTION
        **Azure Monitor Diagnostic Settings** capture **control-plane events** at the subscription level. This evaluates whether at least one setting collects the categories: `Administrative`, `Security`, `Policy`, and `Alert`.

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

    # TODO: Implement check logic based on Prowler check: monitor_diagnostic_setting_with_appropriate_categories

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check monitor_diagnostic_setting_with_appropriate_categories for reference.', 'N/A', 'monitor Resources')
}
