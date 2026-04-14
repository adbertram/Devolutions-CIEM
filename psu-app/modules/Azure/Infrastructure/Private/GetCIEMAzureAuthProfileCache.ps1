function GetCIEMAzureAuthProfileCache {
    <#
    .SYNOPSIS
        Loads Azure auth profiles from PSU Cache as a mutable list.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[object]])]
    param()

    $ErrorActionPreference = 'Stop'

    if ($null -eq (Get-Command -Name 'Get-PSUCache' -ErrorAction SilentlyContinue)) {
        throw "Not running in PSU context. Cannot access PSU Cache."
    }

    $profiles = [System.Collections.Generic.List[object]]::new()
    $json = Get-PSUCache -Key $script:AzureAuthProfilesCacheKey -Integrated -ErrorAction Stop
    if ($json -and $json -is [string] -and $json.Length -gt 0) {
        foreach ($p in @(ConvertFrom-Json $json -ErrorAction Stop)) {
            $profiles.Add($p)
        }
    }
    , $profiles
}
