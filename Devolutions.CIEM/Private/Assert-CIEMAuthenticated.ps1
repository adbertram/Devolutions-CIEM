function Assert-CIEMAuthenticated {
    <#
    .SYNOPSIS
        Asserts that CIEM is authenticated to the specified provider.

    .DESCRIPTION
        Internal function used by scan functions to verify authentication before
        proceeding. Throws an error with instructions to run Connect-CIEM if not
        authenticated.

    .PARAMETER Provider
        The cloud provider to check. Defaults to the provider in CIEM config.

    .EXAMPLE
        Assert-CIEMAuthenticated
        # Throws if not authenticated to default provider

    .EXAMPLE
        Assert-CIEMAuthenticated -Provider Azure
        # Throws if not authenticated to Azure
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Azure', 'AWS')]
        [string]$Provider
    )

    if (-not $Provider) {
        $Provider = $script:Config.cloudProvider
    }

    if (-not (Test-CIEMAuthenticated -Provider $Provider)) {
        throw @"
Not authenticated to $Provider. Run Connect-CIEM first to establish authentication.

Example:
    Connect-CIEM

Or to connect to a specific provider:
    Connect-CIEM -Provider $Provider

Use Test-CIEMAuthenticated to check connection status.
"@
    }

    # Return the auth context for convenience
    $script:AuthContext[$Provider]
}
