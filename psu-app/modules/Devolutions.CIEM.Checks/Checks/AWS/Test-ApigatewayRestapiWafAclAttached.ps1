function Test-ApigatewayRestapiWafAclAttached {
    <#
    .SYNOPSIS
        API Gateway stage has a WAF Web ACL attached

    .DESCRIPTION
        **Amazon API Gateway (REST API)** stages are assessed for an associated **AWS WAF web ACL**. The finding reflects whether a `web ACL` is linked at the stage level.

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

    # TODO: Implement check logic based on Prowler check: apigateway_restapi_waf_acl_attached

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check apigateway_restapi_waf_acl_attached for reference.', 'N/A', 'apigateway Resources')
}
