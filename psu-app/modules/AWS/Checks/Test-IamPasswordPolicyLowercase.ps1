function Test-IamPasswordPolicyLowercase {
    <#
    .SYNOPSIS
        IAM password policy requires at least one lowercase letter

    .DESCRIPTION
        IAM password policy requires at least one lowercase character in user passwords via the Require lowercase setting

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .PARAMETER ServiceCache
        Array of CIEMServiceCache objects containing pre-loaded IAM data.

    .NOTES
        Data source: $svc.PasswordPolicy.RequireLowercaseCharacters
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'IAM' }).CacheData

    $accountId = $script:AuthContext['AWS'].AccountId
    $resourceId = "arn:aws:iam::${accountId}:password-policy"

    if (-not $svc.PasswordPolicy) {
        [CIEMScanResult]::Create(
            $Check,
            'FAIL',
            'No custom password policy is set. The AWS default policy does not enforce lowercase character requirements.',
            $resourceId,
            'Password Policy'
        )
        return
    }

    if ($svc.PasswordPolicy.RequireLowercaseCharacters -eq $true) {
        [CIEMScanResult]::Create(
            $Check,
            'PASS',
            'IAM password policy requires at least one lowercase letter.',
            $resourceId,
            'Password Policy'
        )
    } else {
        [CIEMScanResult]::Create(
            $Check,
            'FAIL',
            'IAM password policy does not require lowercase letters. Update the password policy to require at least one lowercase character.',
            $resourceId,
            'Password Policy'
        )
    }
}
