function Test-ApigatewayRestapiLoggingEnabled {
    <#
    .SYNOPSIS
        API Gateway REST API stage has logging enabled

    .DESCRIPTION
        **API Gateway REST API stages** with **stage logging** enabled to emit execution or access logs to CloudWatch

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

    # TODO: Implement check logic based on Prowler check: apigateway_restapi_logging_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check apigateway_restapi_logging_enabled for reference.', 'N/A', 'apigateway Resources')
}
