function SetCIEMAzureAuthProfileCache {
    <#
    .SYNOPSIS
        Persists the Azure auth profiles list to PSU Cache.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Profiles
    )

    $ErrorActionPreference = 'Stop'

    $json = ConvertTo-Json -InputObject @($Profiles) -Depth 10 -Compress
    Set-PSUCache -Key $script:AzureAuthProfilesCacheKey -Value $json -Persist -Integrated
}
