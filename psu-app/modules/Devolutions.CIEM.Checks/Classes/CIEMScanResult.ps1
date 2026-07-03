enum CIEMScanStatus {
    PASS
    FAIL
    MANUAL
    SKIPPED
}

enum CIEMScanRunStatus {
    Running
    Completed
    Failed
}

class CIEMScanResult {
    [object]$Check  # PSCustomObject from Get-CIEMCheck (not [CIEMCheck] - PSU runspace compat)
    [CIEMScanStatus]$Status
    [string]$StatusExtended
    [string]$ResourceId
    [string]$ResourceName
    [string]$Location

    CIEMScanResult() {}

    static [CIEMScanResult] Create([object]$Check, [string]$Status, [string]$StatusExtended, [string]$ResourceId, [string]$ResourceName, [string]$Location) {
        [CIEMScanResult]::AssertScanResultKey($Status, $Check.Id, $ResourceId, '')
        $result = [CIEMScanResult]::new()
        $result.Check = $Check
        $result.Status = [CIEMScanStatus]$Status
        $result.StatusExtended = $StatusExtended
        $result.ResourceId = $ResourceId
        $result.ResourceName = $ResourceName
        $result.Location = $Location
        return $result
    }

    static [CIEMScanResult] Create([object]$Check, [string]$Status, [string]$StatusExtended, [string]$ResourceId, [string]$ResourceName) {
        return [CIEMScanResult]::Create($Check, $Status, $StatusExtended, $ResourceId, $ResourceName, 'Global')
    }

    hidden static [void] AssertScanResultKey([string]$Status, [string]$CheckId, [string]$ResourceId, [string]$Context) {
        if ($Status -ne 'FAIL') {
            return
        }

        $prefix = if ([string]::IsNullOrWhiteSpace($Context)) { 'Failed scan result' } else { "Failed scan result in $Context" }
        if ([string]::IsNullOrWhiteSpace($CheckId)) {
            throw "${prefix}: CheckId is required for failed scan results."
        }
        if ([string]::IsNullOrWhiteSpace($ResourceId)) {
            throw "${prefix}: ResourceId is required for failed scan results."
        }
    }
}

class CIEMScanRun {
    [string]$Id
    [string]$Type = 'checks'
    [CIEMScanRunStatus]$Status
    [string[]]$Providers
    [PSCustomObject[]]$ProviderSummaries
    [string[]]$Services
    [datetime]$StartTime
    [nullable[datetime]]$EndTime
    [string]$Duration
    [bool]$IncludePassed
    [int]$TotalResults
    [int]$FailedResults
    [int]$PassedResults
    [int]$SkippedResults
    [int]$ManualResults
    [object[]]$ScanResults
    [string]$ErrorMessage
    [nullable[int]]$DiscoveryRunId
    [bool]$ProviderExplicit
    [bool]$ProgressEligible
    [string]$ProgressScopeHash

    # Default constructor - generates Id and sets StartTime
    CIEMScanRun() {
        $this.Id = [guid]::NewGuid().ToString()
        $this.StartTime = Get-Date
        $this.Status = [CIEMScanRunStatus]::Running
        $this.ScanResults = @()
    }

    # Constructor with parameters
    CIEMScanRun([string[]]$Providers, [string[]]$Services, [bool]$IncludePassed) {
        $this.Id = [guid]::NewGuid().ToString()
        $this.StartTime = Get-Date
        $this.Status = [CIEMScanRunStatus]::Running
        $this.Providers = $Providers
        $this.Services = $Services
        $this.IncludePassed = $IncludePassed
        $this.ScanResults = @()
    }

    # Calculate duration string from StartTime to EndTime
    [string] GetDuration() {
        $end = if ($this.EndTime) { $this.EndTime } else { Get-Date }
        $span = $end - $this.StartTime
        if ($span.TotalMinutes -ge 1) {
            return "{0:N0}m {1:N0}s" -f [Math]::Floor($span.TotalMinutes), $span.Seconds
        }
        return "{0:N0}s" -f $span.TotalSeconds
    }

    # Calculate counts from ScanResults and per-provider summaries in a single pass
    [void] UpdateCounts() {
        $this.FailedResults  = 0
        $this.PassedResults  = 0
        $this.SkippedResults = 0
        $this.ManualResults  = 0

        # Per-provider counters keyed by provider name
        $providerCounters = @{}
        foreach ($p in $this.Providers) {
            $providerCounters[$p] = @{ Total = 0; FAIL = 0; PASS = 0; SKIPPED = 0; MANUAL = 0 }
        }

        if ($this.ScanResults) {
            foreach ($r in $this.ScanResults) {
                $s = [string]$r.Status
                switch ($s) {
                    'FAIL'    { $this.FailedResults++ }
                    'PASS'    { $this.PassedResults++ }
                    'SKIPPED' { $this.SkippedResults++ }
                    'MANUAL'  { $this.ManualResults++ }
                }

                $prov = $r.Check.Provider
                if ($prov -and $providerCounters.ContainsKey($prov)) {
                    $pc = $providerCounters[$prov]
                    $pc.Total++
                    $pc[$s]++
                }
            }
        }

        $this.TotalResults = $this.FailedResults + $this.PassedResults + $this.SkippedResults + $this.ManualResults

        $this.ProviderSummaries = @(
            foreach ($providerName in $this.Providers) {
                $pc = $providerCounters[$providerName]
                [PSCustomObject]@{
                    Provider       = $providerName
                    TotalResults   = $pc.Total
                    FailedResults  = $pc['FAIL']
                    PassedResults  = $pc['PASS']
                    SkippedResults = $pc['SKIPPED']
                    ManualResults  = $pc['MANUAL']
                }
            }
        )
    }

    # UpdateProviderSummaries is now integrated into UpdateCounts (single-pass)
    [void] UpdateProviderSummaries() {
        # No-op — kept for backwards compat; UpdateCounts builds summaries in one pass
    }

    # Mark scan as completed
    [void] Complete() {
        $this.EndTime  = Get-Date
        $this.Duration = $this.GetDuration()
        $this.Status   = [CIEMScanRunStatus]::Completed
        $this.UpdateCounts()
        $this.UpdateProviderSummaries()
    }

    # Mark scan as failed
    [void] Fail([string]$ErrorMessage) {
        $this.EndTime     = Get-Date
        $this.Duration    = $this.GetDuration()
        $this.Status      = [CIEMScanRunStatus]::Failed
        $this.ErrorMessage = $ErrorMessage
        $this.UpdateCounts()
        $this.UpdateProviderSummaries()
    }

}
