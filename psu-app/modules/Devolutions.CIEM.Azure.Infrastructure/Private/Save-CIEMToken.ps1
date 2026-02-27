function Save-CIEMToken {
    <#
    .SYNOPSIS
        Saves ARM, Graph, and/or KeyVault tokens to script scope and PSU secrets.

    .DESCRIPTION
        Single source of truth for token storage. Stores tokens in script-scoped
        variables and persists to PSU secrets when running in PSU context.

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
        $script:ARMAccessToken = $ARMToken
        Write-Verbose "ARM token stored in script scope"
        Set-CIEMSecret 'CIEM_Azure_ARMToken' $ARMToken
        Write-Verbose "ARM token stored in PSU secret"
    }

    if ($GraphToken) {
        $script:GraphAccessToken = $GraphToken
        Write-Verbose "Graph token stored in script scope"
        Set-CIEMSecret 'CIEM_Azure_GraphToken' $GraphToken
        Write-Verbose "Graph token stored in PSU secret"
    }

    if ($KeyVaultToken) {
        $script:KeyVaultAccessToken = $KeyVaultToken
        Write-Verbose "KeyVault token stored in script scope"
        Set-CIEMSecret 'CIEM_Azure_KeyVaultToken' $KeyVaultToken
        Write-Verbose "KeyVault token stored in PSU secret"
    }
}
