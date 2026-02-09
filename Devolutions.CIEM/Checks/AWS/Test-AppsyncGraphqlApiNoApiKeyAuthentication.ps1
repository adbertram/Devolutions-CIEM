function Test-AppsyncGraphqlApiNoApiKeyAuthentication {
    <#
    .SYNOPSIS
        AWS AppSync GraphQL API does not use API key authentication

    .DESCRIPTION
        **AWS AppSync GraphQL APIs** are examined for the default authorization type. The finding indicates an API configured with `API_KEY` instead of IAM, Cognito, OIDC, or Lambda authorizers.

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

    # TODO: Implement check logic based on Prowler check: appsync_graphql_api_no_api_key_authentication

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check appsync_graphql_api_no_api_key_authentication for reference.', 'N/A', 'appsync Resources')
}
