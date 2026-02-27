function Test-CIEMAuthenticationContext {
    <#
    .SYNOPSIS
        Tests if CIEM is authenticated to cloud providers.

    .DESCRIPTION
        Checks authentication status for each provider by dispatching to the
        registered provider type's TestAuth callback. Returns an array of
        objects with provider name and status.

    .PARAMETER Provider
        Optional. Check only specific provider(s). If not specified, checks all providers.

    .OUTPUTS
        [PSCustomObject[]] Array of objects with Provider, Enabled, Authenticated, Account, and TenantId properties.

    .EXAMPLE
        Test-CIEMAuthenticationContext
        # Returns status for all providers

    .EXAMPLE
        Test-CIEMAuthenticationContext -Provider Azure
        # Returns status for a specific provider

    .EXAMPLE
        if ((Test-CIEMAuthenticationContext -Provider Azure).Authenticated) {
            # Proceed with scan
        }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string[]]$Provider
    )

    $providers = Get-CIEMProvider
    if ($Provider) {
        $providers = $providers | Where-Object { $Provider -contains $_.Name }
    }

    foreach ($p in $providers) {
        $authenticated = $false
        $account = $null
        $tenantId = $null

        $reg = $script:ProviderTypes[$p.Name]
        if ($reg -and $reg.TestAuth) {
            try {
                $result = & $reg.TestAuth $p
                $authenticated = [bool]$result.Authenticated
                $account = $result.Account
                $tenantId = $result.TenantId
            }
            catch {
                Write-Verbose "$($p.Name) auth check failed: $($_.Exception.Message)"
                $authenticated = $false
            }
        }

        [PSCustomObject]@{
            Provider      = $p.Name
            Enabled       = $p.Enabled
            Authenticated = $authenticated
            Account       = $account
            TenantId      = $tenantId
        }
    }
}
