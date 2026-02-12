function Get-CIEMProvider {
    <#
    .SYNOPSIS
        Lists available CIEM cloud providers.

    .DESCRIPTION
        Returns provider objects from the CIEM:Providers PSU cache. Each provider
        includes Name, Enabled, IsDefault, Authentication, Endpoints, ResourceFilter,
        and a computed CheckCount property.

        On first run (empty cache), returns built-in Azure and AWS defaults.

    .PARAMETER Name
        Optional. Return a single provider by name (case-insensitive).

    .OUTPUTS
        [PSCustomObject[]] Array of provider objects.

    .EXAMPLE
        Get-CIEMProvider
        # Returns all providers

    .EXAMPLE
        Get-CIEMProvider -Name Azure
        # Returns the Azure provider

    .EXAMPLE
        Get-CIEMProvider | Where-Object Enabled
        # Returns only enabled providers
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    # Try to read from PSU cache
    $providers = $null
    try {
        $providers = @(Get-PSUCache -Key 'CIEM:Providers' -ErrorAction SilentlyContinue)
    }
    catch {
        # Not in PSU context or cache unavailable
    }

    # Fall back to built-in defaults if cache is empty
    if (-not $providers -or $providers.Count -eq 0 -or ($providers.Count -eq 1 -and $null -eq $providers[0])) {
        $providers = @(
            [PSCustomObject]@{
                Name           = 'Azure'
                Enabled        = $true
                IsDefault      = $true
                Authentication = [PSCustomObject]@{
                    Provider = 'Azure'
                    Enabled  = $true
                    Method   = 'ServicePrincipalSecret'
                    TenantId = $null
                    ClientId = $null
                    ManagedIdentityClientId = $null
                }
                Endpoints      = [PSCustomObject]@{
                    graphApi = 'https://graph.microsoft.com/v1.0'
                    armApi   = 'https://management.azure.com'
                }
                ResourceFilter = @()
            }
            [PSCustomObject]@{
                Name           = 'AWS'
                Enabled        = $false
                IsDefault      = $false
                Authentication = [PSCustomObject]@{
                    Provider = 'AWS'
                    Enabled  = $false
                    Method   = 'CurrentProfile'
                    Profile  = $null
                    Region   = $null
                }
                Endpoints      = [PSCustomObject]@{}
                ResourceFilter = @()
            }
        )
    }

    # Add computed CheckCount to each provider
    foreach ($p in $providers) {
        $checksPath = Join-Path -Path $script:ModuleRoot -ChildPath "Checks/$($p.Name)"
        $checkCount = if (Test-Path $checksPath) { @(Get-ChildItem -Path "$checksPath/*.ps1").Count } else { 0 }
        $p | Add-Member -NotePropertyName 'CheckCount' -NotePropertyValue $checkCount -Force
    }

    # Filter by name if specified
    if ($Name) {
        $providers = @($providers | Where-Object { $_.Name -eq $Name })
    }

    $providers
}
