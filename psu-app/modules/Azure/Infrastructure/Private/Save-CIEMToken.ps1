function Save-CIEMToken {
    <#
    .SYNOPSIS
        Saves ARM, Graph, and/or KeyVault tokens to auth context and PSU secrets.

    .DESCRIPTION
        Single source of truth for token storage. Stores tokens in the module-scoped
        AzureAuthContext object and persists to PSU secrets for cross-runspace access.

    .PARAMETER ARMToken
        The ARM access token to store (audience: https://management.azure.com).

    .PARAMETER GraphToken
        The Graph access token to store (audience: https://graph.microsoft.com).

    .PARAMETER KeyVaultToken
        The KeyVault access token to store (audience: https://vault.azure.net).

    .EXAMPLE
        Save-CIEMToken -ARMToken $arm.access_token -GraphToken $graph.access_token -KeyVaultToken $kv.access_token
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ARMToken,

        [Parameter()]
        [string]$GraphToken,

        [Parameter()]
        [string]$KeyVaultToken
    )

    if ($ARMToken) {
        if ($script:AzureAuthContext) { $script:AzureAuthContext.ARMToken = $ARMToken }
        Write-Verbose "ARM token stored in auth context"
        Set-CIEMSecret 'CIEM_Azure_ARMToken' $ARMToken
        Write-Verbose "ARM token stored in PSU secret"
    }

    if ($GraphToken) {
        if ($script:AzureAuthContext) { $script:AzureAuthContext.GraphToken = $GraphToken }
        Write-Verbose "Graph token stored in auth context"
        Set-CIEMSecret 'CIEM_Azure_GraphToken' $GraphToken
        Write-Verbose "Graph token stored in PSU secret"
    }

    if ($KeyVaultToken) {
        if ($script:AzureAuthContext) { $script:AzureAuthContext.KeyVaultToken = $KeyVaultToken }
        Write-Verbose "KeyVault token stored in auth context"
        Set-CIEMSecret 'CIEM_Azure_KeyVaultToken' $KeyVaultToken
        Write-Verbose "KeyVault token stored in PSU secret"
    }
}
