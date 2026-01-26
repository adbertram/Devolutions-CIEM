function Test-EntraTrustedNamedLocationsExists {
    <#
    .SYNOPSIS
        Tests if trusted named locations with IP ranges are defined.

    .DESCRIPTION
        This check verifies that at least one named location is configured with IP ranges
        and marked as trusted in Microsoft Entra ID Conditional Access. Trusted named
        locations with IP ranges can be used in Conditional Access policies to enforce
        different access requirements based on the user's location.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraTrustedNamedLocationsExists -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    # Check if Named Locations data is available
    if (-not $script:EntraService.NamedLocations) {
        [PSCustomObject]@{
            CheckId        = $CheckMetadata.id
            Status         = 'FAIL'
            StatusExtended = 'There is no trusted location with IP ranges defined.'
            ResourceId     = 'Named Locations'
            ResourceName   = 'Named Locations'
            Location       = 'Global'
            Severity       = $CheckMetadata.severity
        }
        return
    }

    # Look for trusted named locations with IP ranges
    $trustedIpLocation = $null
    foreach ($location in $script:EntraService.NamedLocations) {
        # Check for isTrusted and ipRanges (IP-based locations)
        $isTrusted = if ($location.PSObject.Properties['isTrusted']) {
            $location.isTrusted -eq $true
        }
        else {
            $false
        }

        $ipRanges = if ($location.PSObject.Properties['ipRanges']) {
            $location.ipRanges
        }
        else {
            $null
        }

        $hasIpRanges = $ipRanges -and @($ipRanges).Count -gt 0

        if ($hasIpRanges -and $isTrusted) {
            $trustedIpLocation = $location
            break
        }
    }

    if ($trustedIpLocation) {
        # Extract IP range addresses
        $ipRangeAddresses = @()
        foreach ($range in $trustedIpLocation.ipRanges) {
            $cidrAddress = if ($range.PSObject.Properties['cidrAddress']) {
                $range.cidrAddress
            }
            else {
                $null
            }
            if ($cidrAddress) {
                $ipRangeAddresses += $cidrAddress
            }
        }

        $ipRangeList = $ipRangeAddresses -join ', '
        [PSCustomObject]@{
            CheckId        = $CheckMetadata.id
            Status         = 'PASS'
            StatusExtended = "Exits trusted location with trusted IP ranges, this IPs ranges are: $ipRangeList"
            ResourceId     = $trustedIpLocation.id
            ResourceName   = $trustedIpLocation.displayName
            Location       = 'Global'
            Severity       = $CheckMetadata.severity
        }
    }
    else {
        [PSCustomObject]@{
            CheckId        = $CheckMetadata.id
            Status         = 'FAIL'
            StatusExtended = 'There is no trusted location with IP ranges defined.'
            ResourceId     = 'Named Locations'
            ResourceName   = 'Named Locations'
            Location       = 'Global'
            Severity       = $CheckMetadata.severity
        }
    }
}
