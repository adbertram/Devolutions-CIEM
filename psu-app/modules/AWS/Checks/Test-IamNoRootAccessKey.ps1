function Test-IamNoRootAccessKey {
    <#
    .SYNOPSIS
        Root account has no active access keys

    .DESCRIPTION
        AWS root user is evaluated for active access keys. It identifies whether the root identity has one or two programmatic credentials and notes when organization-level root credential management is present.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .PARAMETER ServiceCache
        Array of CIEMServiceCache objects containing pre-loaded IAM data.

    .NOTES
        Data source: $svc.CredentialReport (row where user is '<root_account>')
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

    if (-not $svc.CredentialReport) {
        [CIEMScanResult]::Create($Check, 'SKIPPED', 'Credential report not available', 'N/A', 'Root Account')
        return
    }

    $rootEntry = $svc.CredentialReport | Where-Object { $_.user -eq '<root_account>' }

    if (-not $rootEntry) {
        [CIEMScanResult]::Create($Check, 'SKIPPED', 'Root account entry not found in credential report', 'N/A', 'Root Account')
        return
    }

    $key1Active = $rootEntry.access_key_1_active -eq 'true'
    $key2Active = $rootEntry.access_key_2_active -eq 'true'
    $accountId = $rootEntry.arn.Split(':')[4]
    $resourceId = "arn:aws:iam::${accountId}:root"

    if (-not $key1Active -and -not $key2Active) {
        [CIEMScanResult]::Create(
            $Check,
            'PASS',
            'Root account has no active access keys.',
            $resourceId,
            'Root Account'
        )
    } else {
        $activeKeys = @()
        if ($key1Active) { $activeKeys += 'access_key_1' }
        if ($key2Active) { $activeKeys += 'access_key_2' }
        [CIEMScanResult]::Create(
            $Check,
            'FAIL',
            "Root account has active access key(s): $($activeKeys -join ', '). Remove root access keys and use IAM users or roles instead.",
            $resourceId,
            'Root Account'
        )
    }
}
