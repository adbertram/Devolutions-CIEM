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
}

class CIEMScanRun {
    [string]$Id
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

    # Calculate counts from ScanResults (provider-agnostic — counts all statuses uniformly)
    [void] UpdateCounts() {
        if ($this.ScanResults) {
            $this.FailedResults  = @($this.ScanResults | Where-Object { $_.Status -eq 'FAIL'    }).Count
            $this.PassedResults  = @($this.ScanResults | Where-Object { $_.Status -eq 'PASS'    }).Count
            $this.SkippedResults = @($this.ScanResults | Where-Object { $_.Status -eq 'SKIPPED' }).Count
            $this.ManualResults  = @($this.ScanResults | Where-Object { $_.Status -eq 'MANUAL'  }).Count
            $this.TotalResults   = $this.FailedResults + $this.PassedResults + $this.SkippedResults + $this.ManualResults
        }
    }

    # Calculate per-provider sub-summaries (called after UpdateCounts)
    [void] UpdateProviderSummaries() {
        $this.ProviderSummaries = @(
            foreach ($providerName in $this.Providers) {
                $pr = @($this.ScanResults | Where-Object { $_.Check.Provider -eq $providerName })
                [PSCustomObject]@{
                    Provider       = $providerName
                    TotalResults   = $pr.Count
                    FailedResults  = @($pr | Where-Object { $_.Status -eq 'FAIL'    }).Count
                    PassedResults  = @($pr | Where-Object { $_.Status -eq 'PASS'    }).Count
                    SkippedResults = @($pr | Where-Object { $_.Status -eq 'SKIPPED' }).Count
                    ManualResults  = @($pr | Where-Object { $_.Status -eq 'MANUAL'  }).Count
                }
            }
        )
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
