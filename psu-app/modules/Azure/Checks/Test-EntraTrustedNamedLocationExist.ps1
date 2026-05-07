function Test-EntraTrustedNamedLocationExist {
    <#
    .SYNOPSIS
        Tests if trusted named locations with IP ranges are defined.

    .DESCRIPTION
        This check verifies that at least one named location is configured with IP ranges
        and marked as trusted in Microsoft Entra ID Conditional Access. Trusted named
        locations with IP ranges can be used in Conditional Access policies to enforce
        different access requirements based on the user's location.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraTrustedNamedLocationsExists -Check $metadata
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [object[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'Entra' }).CacheData

    # Check if Named Locations data is available
    if (-not $svc.NamedLocations) {
        [CIEMScanResult]::Create(
            $Check,
            'FAIL',
            'There is no trusted location with IP ranges defined.',
            'Named Locations',
            'Named Locations'
        )
    }
    else {
        # Look for trusted named locations with IP ranges
        $trustedIpLocation = $null
        foreach ($location in $svc.NamedLocations) {
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
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                "Exits trusted location with trusted IP ranges, this IPs ranges are: $ipRangeList",
                $trustedIpLocation.id,
                $trustedIpLocation.displayName
            )
        }
        else {
            [CIEMScanResult]::Create(
                $Check,
                'FAIL',
                'There is no trusted location with IP ranges defined.',
                'Named Locations',
                'Named Locations'
            )
        }
    }
}
