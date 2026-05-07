function Set-CIEMAWSAuthenticationProfile {
    <#
    .SYNOPSIS
        Persists AWS authentication metadata used by Connect-CIEMAWS.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Writes the selected AWS authentication metadata to PSU cache')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('CurrentProfile', 'AccessKey')]
        [string]$Method,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Profile,

        [Parameter()]
        [AllowEmptyString()]
        [string]$Region
    )

    $ErrorActionPreference = 'Stop'

    if ($Method -eq 'AccessKey' -and -not [string]::IsNullOrWhiteSpace($Profile)) {
        throw "Profile is only supported when AWS authentication method is CurrentProfile."
    }

    $profileValue = if ([string]::IsNullOrWhiteSpace($Profile)) { $null } else { $Profile.Trim() }
    $regionValue = if ([string]::IsNullOrWhiteSpace($Region)) { $null } else { $Region.Trim() }

    $authProfile = [PSCustomObject]@{
        Method  = $Method
        Profile = if ($Method -eq 'CurrentProfile') { $profileValue } else { $null }
        Region  = $regionValue
    }

    Set-PSUCache -Key $script:AWSAuthProfileCacheKey -Value $authProfile -Persist -Integrated -ErrorAction Stop

    $authProfile
}
