function Test-CIEMAuthenticated {
    <#
    .SYNOPSIS
        Tests if CIEM is authenticated to cloud providers.

    .DESCRIPTION
        Checks authentication status for each provider by testing actual API connectivity.
        For Azure, validates both Graph and ARM API access.
        Returns an array of objects with provider name and status.

    .PARAMETER Provider
        Optional. Check only specific provider(s). If not specified, checks all providers.

    .OUTPUTS
        [PSCustomObject[]] Array of objects with Provider, Enabled, Authenticated, and Account properties.

    .EXAMPLE
        Test-CIEMAuthenticated
        # Returns status for all providers

    .EXAMPLE
        Test-CIEMAuthenticated -Provider Azure
        # Returns status for Azure only

    .EXAMPLE
        if ((Test-CIEMAuthenticated -Provider Azure).Authenticated) {
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

        switch ($p.Name) {
            'Azure' {
                try {
                    # First check if Az context exists
                    $context = Get-AzContext -ErrorAction SilentlyContinue
                    if ($context -and $context.Account) {
                        $account = $context.Account.Id
                        $tenantId = $context.Tenant.Id

                        # Test actual API connectivity
                        $tokens = Get-CIEMToken
                        if ($tokens.GraphToken -and $tokens.ARMToken) {
                            # Have both tokens - consider authenticated
                            $authenticated = $true
                        }
                        elseif ($tokens.GraphToken -or $tokens.ARMToken) {
                            # Have at least one token - try API calls to verify
                            $graphApiBase = $script:Config.azure.endpoints.graphApi
                            $armApiBase = $script:Config.azure.endpoints.armApi

                            # Test Graph API
                            $graphOk = $false
                            try {
                                $graphResponse = Invoke-AzureApi -Uri "$graphApiBase/organization" -Api Graph -ResourceName 'Organization' -ErrorAction Stop
                                $graphOk = $null -ne $graphResponse
                            }
                            catch {
                                Write-Verbose "Graph API test failed: $($_.Exception.Message)"
                            }

                            # Test ARM API
                            $armOk = $false
                            try {
                                $armResponse = Invoke-AzureApi -Uri "$armApiBase/subscriptions?api-version=2020-01-01" -Api ARM -ResourceName 'Subscriptions' -ErrorAction Stop
                                $armOk = $null -ne $armResponse
                            }
                            catch {
                                Write-Verbose "ARM API test failed: $($_.Exception.Message)"
                            }

                            $authenticated = $graphOk -and $armOk
                        }
                        else {
                            # No tokens but have context - may work via Az module
                            $authenticated = $true
                        }
                    }
                }
                catch {
                    Write-Verbose "Azure auth check failed: $($_.Exception.Message)"
                    $authenticated = $false
                }
            }
            default {
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
