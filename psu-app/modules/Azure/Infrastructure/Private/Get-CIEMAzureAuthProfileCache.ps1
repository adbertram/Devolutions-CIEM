function Get-CIEMAzureAuthProfileCache {
    <#
    .SYNOPSIS
        Loads Azure auth profiles from PSU Cache as a mutable list.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[object]])]
    param()

    $profiles = [System.Collections.Generic.List[object]]::new()
    $json = Get-PSUCache -Key $script:AzureAuthProfilesCacheKey -Integrated -ErrorAction SilentlyContinue
    if ($json -and $json -is [string] -and $json.Length -gt 0) {
        foreach ($p in @(ConvertFrom-Json $json)) {
            $profiles.Add($p)
        }
    }
    , $profiles
}
