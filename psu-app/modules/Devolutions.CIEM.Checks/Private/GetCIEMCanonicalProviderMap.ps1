function GetCIEMCanonicalProviderMap {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$Connection
    )

    $ErrorActionPreference = 'Stop'

    $providers = if ($Connection) {
        @(Invoke-PSUSQLiteQuery -Connection $Connection -Query 'SELECT id, name FROM providers')
    }
    else {
        @(Invoke-CIEMQuery -Query 'SELECT id, name FROM providers')
    }
    if ($providers.Count -eq 0) {
        throw "Provider catalog is empty."
    }

    $byToken = @{}
    $idByName = @{}
    foreach ($provider in $providers) {
        $id = [string]$provider.id
        $name = [string]$provider.name
        if ([string]::IsNullOrWhiteSpace($id)) {
            throw "Provider catalog contains a blank provider id."
        }
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw "Provider catalog contains a blank provider name."
        }

        $byToken[$id.ToLowerInvariant()] = $name
        $byToken[$name.ToLowerInvariant()] = $name
        $idByName[$name] = $id
    }

    [pscustomobject]@{
        ByToken  = $byToken
        IdByName = $idByName
    }
}
