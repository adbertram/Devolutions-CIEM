function Get-CIEMDefaultConfig {
    <#
    .SYNOPSIS
        Returns the default CIEM configuration as a PSCustomObject.

    .DESCRIPTION
        Provides hardcoded default configuration values for CIEM.
        This is used to initialize the PSU cache on first run or when
        resetting to defaults.

        Provider-specific settings (authentication, endpoints, resource filters)
        are stored separately via Get-CIEMProvider / Update-CIEMProvider.

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
