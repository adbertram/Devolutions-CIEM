function Test-AppFunctionApplicationInsightsEnabled {
    <#
    .SYNOPSIS
        Function App has Application Insights configured

    .DESCRIPTION
        **Azure Function apps** are configured to send telemetry to **Application Insights** when application settings include `APPLICATIONINSIGHTS_CONNECTION_STRING` or `APPINSIGHTS_INSTRUMENTATIONKEY`.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: app_function_application_insights_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check app_function_application_insights_enabled for reference.', 'N/A', 'app Resources')
}
