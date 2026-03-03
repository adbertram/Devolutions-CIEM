function Test-CognitoUserPoolSelfRegistrationDisabled {
    <#
    .SYNOPSIS
        Amazon Cognito user pool has self registration disabled

    .DESCRIPTION
        **Amazon Cognito user pools** are evaluated for **self-service sign-up**. The expected configuration is `AllowAdminCreateUserOnly=true` so only administrators create accounts.
        
        *When self sign-up is allowed*, the check also highlights any linked identity pools and the authenticated role(s) that new users could assume.

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

    # TODO: Implement check logic based on Prowler check: cognito_user_pool_self_registration_disabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check cognito_user_pool_self_registration_disabled for reference.', 'N/A', 'cognito Resources')
}
