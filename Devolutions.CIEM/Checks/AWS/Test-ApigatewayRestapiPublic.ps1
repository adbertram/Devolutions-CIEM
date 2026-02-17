function Test-ApigatewayRestapiPublic {
    <#
    .SYNOPSIS
        API Gateway REST API endpoint is private

    .DESCRIPTION
        **Amazon API Gateway REST APIs** are evaluated for endpoint exposure: **internet-accessible** endpoints versus **private VPC-only** access via interface VPC endpoints (`AWS PrivateLink`).

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

    # TODO: Implement check logic based on Prowler check: apigateway_restapi_public

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check apigateway_restapi_public for reference.', 'N/A', 'apigateway Resources')
}
