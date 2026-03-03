function Get-CIEMToken {
    <#
    .SYNOPSIS
        Returns ARM, Graph, and KeyVault tokens from auth context or PSU secrets.

    .DESCRIPTION
        Token retrieval with fast path: when the module-scoped AzureAuthContext is
        connected and has tokens, returns directly from it (avoids PSU vault round-trip
        in same runspace). Falls back to PSU secrets for cross-runspace access.

    .OUTPUTS
        [PSCustomObject] with ARMToken, GraphToken, and KeyVaultToken properties.
        Any property may be $null if the token is not available.

    .EXAMPLE
        $tokens = Get-CIEMToken
        if ($tokens.KeyVaultToken) {
            $headers = @{ Authorization = "Bearer $($tokens.KeyVaultToken)" }
        }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Fast path: return from in-memory auth context if available
    if ($script:AzureAuthContext -and $script:AzureAuthContext.IsConnected -and $script:AzureAuthContext.ARMToken) {
        return [PSCustomObject]@{
            ARMToken      = $script:AzureAuthContext.ARMToken
            GraphToken    = $script:AzureAuthContext.GraphToken
            KeyVaultToken = $script:AzureAuthContext.KeyVaultToken
        }
    }

    # Fallback: read from PSU secrets (cross-runspace access)
    $armToken = Get-CIEMSecret 'CIEM_Azure_ARMToken'
    $graphToken = Get-CIEMSecret 'CIEM_Azure_GraphToken'
    $keyVaultToken = Get-CIEMSecret 'CIEM_Azure_KeyVaultToken'

    # Update auth context with fresh values if it exists
    if ($script:AzureAuthContext) {
        if ($armToken) { $script:AzureAuthContext.ARMToken = $armToken }
        if ($graphToken) { $script:AzureAuthContext.GraphToken = $graphToken }
        if ($keyVaultToken) { $script:AzureAuthContext.KeyVaultToken = $keyVaultToken }
    }

    [PSCustomObject]@{
        ARMToken      = $armToken
        GraphToken    = $graphToken
        KeyVaultToken = $keyVaultToken
    }
}
