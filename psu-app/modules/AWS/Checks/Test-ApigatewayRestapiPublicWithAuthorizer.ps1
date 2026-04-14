function Test-ApigatewayRestapiPublicWithAuthorizer {
    <#
    .SYNOPSIS
        API Gateway REST API with a public endpoint has an authorizer configured

    .DESCRIPTION
        **API Gateway REST APIs** exposed to the Internet are evaluated for an attached **authorizer** that enforces caller identity (Lambda authorizer or Cognito user pool) on method invocations.
        
        Focus is on whether public endpoints require authenticated requests rather than accepting anonymous calls.

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

    # TODO: Implement check logic based on Prowler check: apigateway_restapi_public_with_authorizer

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check apigateway_restapi_public_with_authorizer for reference.', 'N/A', 'apigateway Resources')
}
