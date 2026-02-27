function Test-ApigatewayRestapiTracingEnabled {
    <#
    .SYNOPSIS
        API Gateway REST API stage has X-Ray tracing enabled

    .DESCRIPTION
        **API Gateway REST API stages** have **AWS X-Ray active tracing** enabled to sample incoming requests and produce distributed traces across connected services.

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

    # TODO: Implement check logic based on Prowler check: apigateway_restapi_tracing_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check apigateway_restapi_tracing_enabled for reference.', 'N/A', 'apigateway Resources')
}
