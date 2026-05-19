function GetCIEMAssignedAuthenticationProfile {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ProviderDiscovery', 'NotificationChannel')]
        [string]$UsageType,

        [Parameter(Mandatory)]
        [string]$UsageId
    )

    $ErrorActionPreference = 'Stop'

    $assignments = @(Get-CIEMAuthenticationProfileAssignment -UsageType $UsageType -UsageId $UsageId)
    if ($assignments.Count -ne 1) {
        throw "No authentication profile assignment found for $UsageType '$UsageId'. Configure one on the Configuration page."
    }

    $profiles = @(Get-CIEMAuthenticationProfile -Id $assignments[0].AuthenticationProfileId -ResolveSecrets)
    if ($profiles.Count -ne 1) {
        throw "Authentication profile '$($assignments[0].AuthenticationProfileId)' assigned to $UsageType '$UsageId' was not found."
    }

    $profiles[0]
}
