function Get-CIEMIdentity {
    <#
    .SYNOPSIS
        Lists identity types that can be assigned permissions to resources.

    .DESCRIPTION
        Reads Data/identity_types.json and returns the canonical list of identity
        types for a given cloud provider. Each entry describes an entity that can
        appear as a security principal in role assignments.

    .PARAMETER Provider
        Filter by cloud provider (Azure, AWS).

    .PARAMETER Name
        Filter by identity type name (e.g., "EntraUser", "EntraServicePrincipal").

    .PARAMETER Type
        Filter by identity category (Human, Collection, Workload).

    .OUTPUTS
        [CIEMIdentity[]] Array of identity type objects.

    .EXAMPLE
        Get-CIEMIdentity -Provider Azure
        # Returns all Azure identity types

    .EXAMPLE
        Get-CIEMIdentity -Provider Azure -Type Workload
        # Returns workload identities (service principals, managed identities, applications)

    .EXAMPLE
        Get-CIEMIdentity -Provider Azure -Name EntraUser
        # Returns the Entra user identity type
    #>
    [CmdletBinding()]
    [OutputType([CIEMIdentity[]])]
    param(
        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('Human', 'Collection', 'Workload')]
        [string]$Type
    )

    $ErrorActionPreference = 'Stop'

    $dataPath = Join-Path $script:ModuleRoot 'Data/identity_types.json'
    if (-not (Test-Path $dataPath)) {
        Write-Warning "Identity types file not found: $dataPath"
        return @()
    }

    $allData = Get-Content $dataPath -Raw | ConvertFrom-Json
    $results = [System.Collections.ArrayList]::new()

    $providerMap = @{ 'azure' = 'Azure'; 'aws' = 'AWS' }

    foreach ($providerKey in $allData.PSObject.Properties.Name) {
        $providerDisplay = $providerMap[$providerKey]
        if (-not $providerDisplay) {
            Write-Warning "Unknown provider '$providerKey' in identity_types.json, skipping."
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

            if ($PSBoundParameters.ContainsKey('Type') -and $entry.type -ne $Type) {
                continue
            }

            $obj = [CIEMIdentity]::new()
            $obj.Name          = $entry.name
            $obj.DisplayName   = $entry.displayName
            $obj.Type          = $entry.type
            $obj.Provider      = $providerDisplay
            $obj.PrincipalType = $entry.principalType
            $obj.GraphNodeType = $entry.graphNodeType
            $obj.Description   = $entry.description

            $null = $results.Add($obj)
        }
    }

    @($results)
}
