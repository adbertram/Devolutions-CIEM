function Test-ApigatewayRestapiAuthorizersEnabled {
    <#
    .SYNOPSIS
        API Gateway REST API has an authorizer at API level or all methods are authorized

    .DESCRIPTION
        **API Gateway REST APIs** are evaluated for **access control**: an **API-level authorizer** is present, or all resource methods use an authorization mechanism. Methods marked `NONE` indicate unauthenticated access.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: apigateway_restapi_authorizers_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check apigateway_restapi_authorizers_enabled for reference.', 'N/A', 'apigateway Resources')
}
