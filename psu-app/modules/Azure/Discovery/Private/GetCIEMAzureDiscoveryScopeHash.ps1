function GetCIEMAzureDiscoveryScopeHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SubscriptionIds
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        throw 'Azure discovery scope hash requires a non-empty tenant id.'
    }

    $payload = [ordered]@{
        tenantId        = $TenantId
        subscriptionIds = @($SubscriptionIds | Sort-Object)
    } | ConvertTo-Json -Depth 10 -Compress

    GetCIEMSHA256Hash -InputText $payload
}
