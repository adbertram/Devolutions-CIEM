function Set-CIEMAzureAuthenticationProfileActive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProfile')]
        $Profile,
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$Id
    )

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $Profile = @(Get-CIEMAzureAuthenticationProfile -Id $Id) | Select-Object -First 1
        if (-not $Profile) { throw "Azure authentication profile '$Id' not found." }
    }

    # Load all profiles, set target active, deactivate all others
    $profiles = Get-CIEMAzureAuthProfileCache

    $now = (Get-Date).ToString('o')
    foreach ($p in $profiles) {
        if ($p.Id -eq $Profile.Id) {
            $p.IsActive = $true
            $p.UpdatedAt = $now
        } elseif ([bool]$p.IsActive) {
            $p.IsActive = $false
            $p.UpdatedAt = $now
        }
    }

    Set-CIEMAzureAuthProfileCache -Profiles $profiles
}
