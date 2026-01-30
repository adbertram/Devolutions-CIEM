function Test-CIEMAuthenticated {
    <#
    .SYNOPSIS
        Tests if CIEM is authenticated to cloud providers.

    .DESCRIPTION
        Checks authentication status for each provider.
        For Azure, checks Get-AzContext directly (persists across sessions).
        Returns an array of objects with provider name and status.

    .PARAMETER Provider
        Optional. Check only specific provider(s). If not specified, checks all providers.

    .OUTPUTS
        [PSCustomObject[]] Array of objects with Provider, Enabled, and Authenticated properties.

    .EXAMPLE
        Test-CIEMAuthenticated
        # Returns status for all providers

    .EXAMPLE
        Test-CIEMAuthenticated -Provider Azure
        # Returns status for Azure only
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

    $results = @()

    foreach ($p in $providers) {
        $authenticated = switch ($p.Name) {
            'Azure' {
                try {
                    $context = Get-AzContext -ErrorAction SilentlyContinue
                    $null -ne $context -and $null -ne $context.Account
                }
                catch {
                    $false
                }
            }
            default {
                $false
            }
        }

        $results += [PSCustomObject]@{
            Provider      = $p.Name
            Enabled       = $p.Enabled
            Authenticated = $authenticated
        }
    }

    $results
}
