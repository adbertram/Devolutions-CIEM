function Get-CIEMResourceType {
    <#
    .SYNOPSIS
        Lists resource types from the canonical resource_types.json vocabulary.

    .DESCRIPTION
        Reads Data/resource_types.json and returns typed objects per provider.
        Azure entries return as PSCustomObjects with CIEMAzureResourceType properties;
        AWS entries return with CIEMAWSResourceType properties.

        Returns PSCustomObjects (not class instances) to ensure compatibility with
        PSU runspaces, matching the pattern used by Get-CIEMProviderService.

    .PARAMETER Provider
        Filter by cloud provider (Azure, AWS).

    .PARAMETER Name
        Filter by resource type name (e.g., "KeyVault", "S3Bucket").

    .OUTPUTS
        [PSCustomObject[]] Array of resource type objects.

    .EXAMPLE
        Get-CIEMResourceType
        # Returns all resource types across all providers

    .EXAMPLE
        Get-CIEMResourceType -Provider Azure
        # Returns Azure resource types only

    .EXAMPLE
        Get-CIEMResourceType -Provider Azure -Name KeyVault
        # Returns the KeyVault resource type
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    $dataPath = Join-Path $script:ModuleRoot 'Data/resource_types.json'
    if (-not (Test-Path $dataPath)) {
        Write-Warning "Resource types file not found: $dataPath"
        return @()
    }

    $allData = Get-Content $dataPath -Raw | ConvertFrom-Json
    $results = [System.Collections.ArrayList]::new()

    $providerMap = @{ 'azure' = 'Azure'; 'aws' = 'AWS' }

    foreach ($providerKey in $allData.PSObject.Properties.Name) {
        $providerDisplay = $providerMap[$providerKey]
        if (-not $providerDisplay) {
            Write-Warning "Unknown provider '$providerKey' in resource_types.json, skipping."
            continue
        }

        if ($PSBoundParameters.ContainsKey('Provider') -and $providerDisplay -ne $Provider) {
            continue
        }

        foreach ($entry in @($allData.$providerKey)) {
            if ($null -eq $entry) { continue }

            if ($PSBoundParameters.ContainsKey('Name') -and $entry.name -ne $Name) {
                continue
            }

            $obj = switch ($providerKey) {
                'azure' {
                    [PSCustomObject]@{
                        Name              = $entry.name
                        DisplayName       = $entry.displayName
                        Provider          = $providerDisplay
                        ServiceName       = $entry.serviceName
                        ArmProviderPrefix = $entry.armProviderPrefix
                    }
                }
                'aws' {
                    [PSCustomObject]@{
                        Name             = $entry.name
                        DisplayName      = $entry.displayName
                        Provider         = $providerDisplay
                        ServiceName      = $entry.serviceName
                        ArnServicePrefix = $entry.arnServicePrefix
                    }
                }
            }

            $null = $results.Add($obj)
        }
    }

    @($results)
}
