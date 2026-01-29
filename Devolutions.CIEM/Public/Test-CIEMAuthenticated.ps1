function Test-CIEMAuthenticated {
    <#
    .SYNOPSIS
        Tests if CIEM is authenticated to a specific cloud provider.

    .DESCRIPTION
        Checks if Connect-CIEM has been called and authentication is established
        for the specified provider. Returns $true if authenticated, $false otherwise.

    .PARAMETER Provider
        The cloud provider to check. Defaults to the provider in config.json.

    .OUTPUTS
        [bool] True if authenticated, false otherwise.

    .EXAMPLE
        Test-CIEMAuthenticated
        # Returns $true if connected to default provider

    .EXAMPLE
        Test-CIEMAuthenticated -Provider Azure
        # Returns $true if connected to Azure

    .EXAMPLE
        if (-not (Test-CIEMAuthenticated)) { Connect-CIEM }
        # Connect if not already authenticated
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [ValidateSet('Azure', 'AWS')]
        [string]$Provider
    )

    if (-not $Provider) {
        $Provider = $script:Config.cloudProvider
    }

    if (-not $script:AuthContext) {
        return $false
    }

    $authContext = $script:AuthContext[$Provider]
    if (-not $authContext) {
        return $false
    }

    # For Azure, also verify the context is still valid
    if ($Provider -eq 'Azure') {
        try {
            $context = Get-AzContext -ErrorAction SilentlyContinue
            if (-not $context -or $context.Account.Id -ne $authContext.AccountId) {
                # Context was cleared or changed
                $script:AuthContext[$Provider] = $null
                return $false
            }
        }
        catch {
            $script:AuthContext[$Provider] = $null
            return $false
        }
    }

    return $true
}
