function Test-ApigatewayRestapiClientCertificateEnabled {
    <#
    .SYNOPSIS
        API Gateway REST API stage has client certificate enabled

    .DESCRIPTION
        **API Gateway stage** has a **client certificate** configured so HTTP/S integrations can perform **mutual TLS** and authenticate API Gateway to the backend

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

    # TODO: Implement check logic based on Prowler check: apigateway_restapi_client_certificate_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check apigateway_restapi_client_certificate_enabled for reference.', 'N/A', 'apigateway Resources')
}
