function Get-CIEMAzureAuthProfileCache {
    <#
    .SYNOPSIS
        Loads Azure auth profiles from PSU Cache as a mutable list.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[object]])]
    param()

    $profiles = [System.Collections.Generic.List[object]]::new()
    foreach ($p in @(Get-PSUCache -Key $script:AzureAuthProfilesCacheKey -Integrated -ErrorAction SilentlyContinue)) {
        $profiles.Add($p)
    }
    , $profiles
}
