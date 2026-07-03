function New-CIEMScanRun {
    <#
    .SYNOPSIS
        Creates and executes a CIEM security scan, returning the completed ScanRun.

    .DESCRIPTION
        Single public entry point for running CIEM scans. Creates a ScanRun record,
        delegates check execution to the internal InvokeCIEMScan, and returns the
        completed [CIEMScanRun] object with all results attached.

        When -Provider is omitted, all enabled providers are scanned. If one
        provider fails to connect, its checks are marked SKIPPED and scanning
        continues with remaining providers.

    .PARAMETER Provider
        One or more cloud providers to scan ('Azure', 'AWS').
        Omit to scan all enabled providers.

    .PARAMETER CheckId
        Optional array of check IDs to run. If not specified, runs all checks.

    .PARAMETER Service
        Optional service filter. Only runs checks for specified service(s).
        Applied globally — providers that do not have the service are skipped silently.

    .PARAMETER IncludePassed
        Whether to include passed checks in results. Default is false.

    .OUTPUTS
        [CIEMScanRun] The completed scan run with all results attached.

    .EXAMPLE
        $scanRun = New-CIEMScanRun
        # Scans all enabled providers, returns completed ScanRun

    .EXAMPLE
        $scanRun = New-CIEMScanRun -Provider 'Azure'
        # Scans Azure only

    .EXAMPLE
        $scanRun = New-CIEMScanRun -Provider @('Azure', 'AWS') -Service 'Entra'
        # Scans the Entra service on Azure; AWS is skipped silently (no Entra service)
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanRun')]
    param(
        [Parameter()]
        [string[]]$Provider,

        [Parameter()]
        [string[]]$CheckId,

        [Parameter()]
        [string[]]$Service,

        [Parameter()]
        [switch]$IncludePassed
    )

    $ErrorActionPreference = 'Stop'
    $providerExplicit = $PSBoundParameters.ContainsKey('Provider') -and $Provider -and @($Provider).Count -gt 0

    # PSU doesn't pass -Parameters to module command scripts, so read from cache
    if (-not $Provider -and -not $CheckId -and -not $Service) {
        $scanConfig = ReadPSUCache -Key 'CIEM:ScanConfig'
        if ($scanConfig -and $scanConfig.Provider) {
            $providerExplicit = $true
            $Provider      = $scanConfig.Provider
            $CheckId       = $scanConfig.CheckId
            $Service       = $scanConfig.Service
            $IncludePassed = [switch]([bool]$scanConfig.IncludePassed)
            Set-PSUCache -Key 'CIEM:ScanConfig' -Value @{} -Integrated
            Write-CIEMLog -Message "Loaded scan config from cache: Provider=[$($Provider -join ',')], CheckId=[$($CheckId -join ',')], Service=[$($Service -join ',')]" -Severity INFO -Component 'ScanRun'
        }
    }

    Write-CIEMLog -Message "New-CIEMScanRun called: Provider=[$($Provider -join ',')], CheckId=[$($CheckId -join ',')], Service=[$($Service -join ',')], IncludePassed=$IncludePassed" -Severity INFO -Component 'ScanRun'

    # --- Resolve providers: default to all enabled when not specified ---
    if (-not $Provider -or $Provider.Count -eq 0) {
        $Provider = @(Get-CIEMProvider | Where-Object Enabled | Select-Object -ExpandProperty Name)
        if ($Provider.Count -eq 0) {
            throw "No enabled providers configured. Use New-CIEMProvider to add providers."
        }
        Write-Verbose "No -Provider specified; scanning all enabled providers: $($Provider -join ', ')"
    }
    $Provider = @(ConvertToCIEMCanonicalProviderList -Providers @($Provider))

    # --- Determine the union of all services across requested providers ---
    $allProviderServices = @(foreach ($p in $Provider) {
        Get-CIEMProviderService -Provider $p | Select-Object -ExpandProperty Name
    })

    # Validate -Service if specified: at least one provider must have each requested service
    if ($Service) {
        $invalidServices = $Service | Where-Object { $_ -notin $allProviderServices }
        if ($invalidServices) {
            throw "Requested service(s) not available in any specified provider: $($invalidServices -join ', '). Available: $($allProviderServices -join ', ')"
        }
    }

    # Services for the ScanRun record: the union of what will actually be scanned
    $scanServices = if ($Service) { $Service } else { $allProviderServices | Select-Object -Unique }

    # --- Create and persist ScanRun ---
    $scanRun = [CIEMScanRun]::new($Provider, $scanServices, $IncludePassed.IsPresent)
    $scanRun.Status = [CIEMScanRunStatus]::Running
    $scanRun.ProviderExplicit = [bool]$providerExplicit

    InvokeCIEMImmediateTransaction {
        param($conn)

        $latestProgressDiscovery = $null
        if ($Provider -contains 'Azure') {
            AssertCIEMAzureMutationAllowed -Connection $conn -Starting AzureScan
            $latestProgressDiscovery = GetCIEMLatestAzureProgressDiscoveryRun -Connection $conn
            if ($latestProgressDiscovery) {
                $scanRun.DiscoveryRunId = [int]$latestProgressDiscovery.id
            }
        }

        $hasCheckFilter = $CheckId -and @($CheckId).Count -gt 0
        $hasServiceFilter = $Service -and @($Service).Count -gt 0
        $scanStartsAfterDiscovery = $false
        if ($latestProgressDiscovery) {
            $scanStartsAfterDiscovery = ([datetime]$scanRun.StartTime) -ge ([datetime]$latestProgressDiscovery.completed_at)
        }

        $scanRun.ProgressEligible = (
            $Provider.Count -eq 1 -and
            $Provider[0] -eq 'Azure' -and
            $scanRun.ProviderExplicit -and
            -not $hasCheckFilter -and
            -not $hasServiceFilter -and
            $latestProgressDiscovery -and
            $scanStartsAfterDiscovery
        )

        if ($scanRun.ProgressEligible) {
            $scanRun.ProgressScopeHash = GetCIEMAzureProgressScopeHash `
                -AttackPathScopeHash ([string]$latestProgressDiscovery.attack_path_scope_hash) `
                -DiscoveryScopeHash ([string]$latestProgressDiscovery.discovery_scope_hash)
        }
        else {
            $scanRun.ProgressScopeHash = $null
        }

        SaveCIEMScanRunCore -Connection $conn -ScanRun $scanRun
    }

    Write-Verbose "Started ScanRun: $($scanRun.Id) for providers: $($Provider -join ', ')"

    # --- Execute scan and collect results ---
    try {
        $invokeParams = @{ Provider = $Provider }
        if ($CheckId)      { $invokeParams.CheckId = $CheckId }
        if ($Service)       { $invokeParams.Service = $Service }
        if ($IncludePassed) { $invokeParams.IncludePassed = $true }

        $allFindings = @(InvokeCIEMScan @invokeParams)

        $scanRun.ScanResults = $allFindings
        $scanRun.Complete()
        Save-CIEMScanRun -ScanRun $scanRun

        Write-Verbose "ScanRun completed: $($scanRun.Id) — $($scanRun.TotalResults) results"
    }
    catch {
        $scanRun.ScanResults = @()
        $scanRun.Fail($_.Exception.Message)
        Save-CIEMScanRun -ScanRun $scanRun

        Write-Verbose "ScanRun failed: $($scanRun.Id) — $($_.Exception.Message)"
        throw
    }

    return $scanRun
}
