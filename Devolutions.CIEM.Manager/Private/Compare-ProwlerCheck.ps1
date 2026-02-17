function Compare-ProwlerCheck {
    <#
    .SYNOPSIS
        Compares upstream Prowler checks against locally registered CIEM checks.

    .DESCRIPTION
        Calls Get-ProwlerCheck and Get-CIEMCheck, then uses Compare-Object to diff
        the check IDs. The reference (left) set is Prowler upstream; the difference
        (right) set is local CIEM checks.

        SideIndicator meanings:
          <=  Check exists only in Prowler (not yet imported)
          =>  Check exists only locally (no upstream match)
          ==  Check exists in both (shown when -IncludeEqual is specified)

    .PARAMETER Provider
        Filter to a specific provider (azure, aws, gcp).

    .PARAMETER Service
        Filter to a specific service (e.g., entra, iam, storage).

    .PARAMETER IncludeEqual
        When specified, includes checks that exist in both Prowler and CIEM (SideIndicator '==').

    .OUTPUTS
        PSCustomObject with InputObject (check ID) and SideIndicator, matching Compare-Object output.

    .EXAMPLE
        Compare-ProwlerCheck -Provider azure

    .EXAMPLE
        Compare-ProwlerCheck -Provider aws -IncludeEqual
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$Service,

        [Parameter()]
        [switch]$IncludeEqual
    )

    $ErrorActionPreference = 'Stop'

    $prowlerParams = @{}
    if ($Provider) { $prowlerParams['Provider'] = $Provider }
    if ($Service) { $prowlerParams['Service'] = $Service }

    Write-Verbose 'Fetching upstream Prowler checks...'
    $prowlerIds = @(Get-ProwlerCheck @prowlerParams | ForEach-Object { $_.Name })
    Write-Verbose "  Prowler checks: $($prowlerIds.Count)"

    $ciemParams = @{}
    if ($Provider) { $ciemParams['Provider'] = $Provider }
    if ($Service) { $ciemParams['Service'] = $Service }

    Write-Verbose 'Fetching local CIEM checks...'
    $ciemIds = @(Get-CIEMCheck @ciemParams | ForEach-Object { $_.Id })
    Write-Verbose "  CIEM checks: $($ciemIds.Count)"

    if ($prowlerIds.Count -eq 0 -and $ciemIds.Count -eq 0) {
        Write-Verbose 'Both sets are empty, nothing to compare.'
        return
    }

    $compareParams = @{
        ReferenceObject  = $prowlerIds
        DifferenceObject = $ciemIds
    }
    if ($IncludeEqual) {
        $compareParams['IncludeEqual'] = $true
    }

    Compare-Object @compareParams
}
