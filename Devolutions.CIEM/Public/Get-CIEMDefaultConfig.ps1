function Get-CIEMDefaultConfig {
    <#
    .SYNOPSIS
        Returns the default CIEM configuration as a PSCustomObject.

    .DESCRIPTION
        Provides hardcoded default configuration values for CIEM.
        This is used to initialize the PSU cache on first run or when
        resetting to defaults.

    .OUTPUTS
        [PSCustomObject] Default configuration values.

    .EXAMPLE
        $defaults = Get-CIEMDefaultConfig
        $defaults.scan.throttleLimit  # Returns 10
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    [PSCustomObject]@{
        cloudProvider = 'Azure'
        azure = [PSCustomObject]@{
            enabled = $true
            authentication = [PSCustomObject]@{
                method = 'ServicePrincipalSecret'
                tenantId = $null
                servicePrincipal = [PSCustomObject]@{ clientId = $null; clientSecret = $null }
                certificate = [PSCustomObject]@{ clientId = $null; thumbprint = $null; path = $null; password = $null }
                managedIdentity = [PSCustomObject]@{ clientId = $null }
            }
            subscriptionFilter = @()
            endpoints = [PSCustomObject]@{
                graphApi = 'https://graph.microsoft.com/v1.0'
                armApi = 'https://management.azure.com'
            }
        }
        aws = [PSCustomObject]@{
            enabled = $false
            authentication = [PSCustomObject]@{
                method = 'CurrentProfile'
                profile = $null
                region = $null
            }
            accountFilter = @()
        }
        scan = [PSCustomObject]@{
            throttleLimit = 10
            timeoutSeconds = 300
            continueOnError = $true
        }
        output = [PSCustomObject]@{
            verboseLogging = $false
        }
        checksPath = 'Checks'
        pam = [PSCustomObject]@{
            remediationUrl = 'https://devolutions.net/pam'
        }
        prowler = [PSCustomObject]@{
            path = '../prowler/prowler/providers'
        }
    }
}
