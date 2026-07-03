function ConvertToCIEMCanonicalProviderList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Providers,

        [Parameter()]
        [object]$Connection
    )

    $ErrorActionPreference = 'Stop'

    $providerMap = GetCIEMCanonicalProviderMap -Connection $Connection
    $canonical = @()
    foreach ($provider in $Providers) {
        $providerText = [string]$provider
        if ([string]::IsNullOrWhiteSpace($providerText)) {
            throw "Provider names cannot be blank."
        }

        $key = $providerText.Trim().ToLowerInvariant()
        if (-not $providerMap.ByToken.ContainsKey($key)) {
            throw "Unknown provider '$providerText'."
        }

        $providerName = [string]$providerMap.ByToken[$key]
        if ($canonical -notcontains $providerName) {
            $canonical += $providerName
        }
    }

    if ($canonical.Count -eq 0) {
        throw "At least one provider is required."
    }

    @($canonical | Sort-Object)
}
