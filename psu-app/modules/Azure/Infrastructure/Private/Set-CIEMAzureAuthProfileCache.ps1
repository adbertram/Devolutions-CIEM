function Set-CIEMAzureAuthProfileCache {
    <#
    .SYNOPSIS
        Persists the Azure auth profiles list to PSU Cache.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Profiles
    )

    Set-PSUCache -Key $script:AzureAuthProfilesCacheKey -Value @($Profiles) -Persist -Integrated
}
