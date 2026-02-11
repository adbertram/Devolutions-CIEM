function Get-CIEMCheckService {
    <#
    .SYNOPSIS
        Lists unique services from the pre-packed CIEM checks catalog.

    .DESCRIPTION
        Reads ciem_checks.json and extracts unique service names per provider.
        This provides the full list of available services even before checks
        have been synced from Prowler.

        Returns PSCustomObjects to ensure compatibility with PSU runspaces.

    .PARAMETER CloudProvider
        Filter services by cloud provider (Azure, AWS).

    .OUTPUTS
        [PSCustomObject[]] Array of objects with Name and CloudProvider properties.

    .EXAMPLE
        Get-CIEMCheckService
        # Returns all services across all providers

    .EXAMPLE
        Get-CIEMCheckService -CloudProvider Azure
        # Returns Azure services only
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [CIEMCloudProvider]$CloudProvider
    )

    $ErrorActionPreference = 'Stop'

    $checksPath = Join-Path $script:ModuleRoot 'ciem_checks.json'
    if (-not (Test-Path $checksPath)) {
        Write-Warning "Checks file not found: $checksPath"
        return @()
    }

    $allData = Get-Content $checksPath -Raw | ConvertFrom-Json
    $services = [System.Collections.ArrayList]::new()
    $seen = @{}

    $providerMap = @{ 'azure' = 'Azure'; 'aws' = 'AWS' }

    foreach ($providerName in $allData.PSObject.Properties.Name) {
        $providerDisplay = $providerMap[$providerName]
        if (-not $providerDisplay) {
            Write-Warning "Unknown provider '$providerName' in ciem_checks.json, skipping."
            continue
        }

        if ($PSBoundParameters.ContainsKey('CloudProvider') -and $providerDisplay -ne $CloudProvider.ToString()) {
            continue
        }

        foreach ($jsonObj in @($allData.$providerName)) {
            if ($null -eq $jsonObj -or -not $jsonObj.service) { continue }
            $key = "${providerName}:$($jsonObj.service)"
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $null = $services.Add([PSCustomObject]@{
                    Name          = $jsonObj.service
                    CloudProvider = $providerDisplay
                })
            }
        }
    }

    @($services | Sort-Object -Property CloudProvider, Name)
}
