function Get-PSUInstalledEnvironment {
    <#
    .SYNOPSIS
        Detects the PowerShell Universal deployment environment.
    .DESCRIPTION
        Determines whether PSU is running in an Azure Web App or on-premises
        by checking for Azure App Service-specific environment variables.
    .OUTPUTS
        [PSCustomObject] with properties:
        - Environment: 'AzureWebApp' or 'OnPremises'
        - SupportsManagedIdentity: $true/$false
        - Description: Human-readable description
        - WebsiteName: Azure site name (if Azure)
    .EXAMPLE
        Get-PSUInstalledEnvironment
        # Returns environment detection result
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Return cached value if available
    if ($script:PSUEnvironment) {
        return $script:PSUEnvironment
    }

    # Azure App Service environment variables
    $websiteSiteName = [System.Environment]::GetEnvironmentVariable('WEBSITE_SITE_NAME')
    $websiteInstanceId = [System.Environment]::GetEnvironmentVariable('WEBSITE_INSTANCE_ID')

    $isAzureWebApp = $null -ne $websiteSiteName -or $null -ne $websiteInstanceId

    if ($isAzureWebApp) {
        $script:PSUEnvironment = [PSCustomObject]@{
            Environment             = 'AzureWebApp'
            SupportsManagedIdentity = $true
            Description             = 'Running in Azure App Service. Managed Identity authentication is available.'
            WebsiteName             = $websiteSiteName
        }
    }
    else {
        $script:PSUEnvironment = [PSCustomObject]@{
            Environment             = 'OnPremises'
            SupportsManagedIdentity = $false
            Description             = 'Running on-premises. Use Service Principal or Interactive authentication for Azure access.'
            WebsiteName             = $null
        }
    }

    return $script:PSUEnvironment
}
