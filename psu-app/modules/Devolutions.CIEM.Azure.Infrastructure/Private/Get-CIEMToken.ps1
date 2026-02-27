function Get-CIEMToken {
    <#
    .SYNOPSIS
        Returns ARM, Graph, and KeyVault tokens from PSU secrets.

    .DESCRIPTION
        Single source of truth for token retrieval. Always reads from PSU secrets
        (the authoritative source) to ensure fresh tokens are used even when
        running in different PSU runspaces.

        Note: PSU runspaces are isolated, so script-scope variables from one
        runspace (e.g., where Connect-CIEM ran) are not visible to another
        (e.g., where the scan is executing). By always reading from PSU secrets,
        we ensure the scan uses the freshly-saved tokens from Connect-CIEM.

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

    # Always read from PSU secrets (authoritative source)
    # Don't rely on script-scope cache which may be stale in different runspaces
    $armToken = Get-CIEMSecret 'CIEM_Azure_ARMToken'
    $graphToken = Get-CIEMSecret 'CIEM_Azure_GraphToken'
    $keyVaultToken = Get-CIEMSecret 'CIEM_Azure_KeyVaultToken'

    # Update script scope with fresh values for subsequent calls within same runspace
    if ($armToken) {
        $script:ARMAccessToken = $armToken
        Write-Verbose "ARM token retrieved from PSU secret"
    }
    if ($graphToken) {
        $script:GraphAccessToken = $graphToken
        Write-Verbose "Graph token retrieved from PSU secret"
    }
    if ($keyVaultToken) {
        $script:KeyVaultAccessToken = $keyVaultToken
        Write-Verbose "KeyVault token retrieved from PSU secret"
    }

    [PSCustomObject]@{
        ARMToken      = $armToken
        GraphToken    = $graphToken
        KeyVaultToken = $keyVaultToken
    }
}
