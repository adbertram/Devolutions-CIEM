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
    [string]$CheckId
    [CIEMScanStatus]$Status
    [string]$StatusExtended
    [string]$ResourceId
    [string]$ResourceName
    [string]$Location
    [string]$Severity

    CIEMScanResult() {}

    CIEMScanResult(
        [string]$CheckId,
        [CIEMScanStatus]$Status,
        [string]$StatusExtended,
        [string]$ResourceId,
        [string]$ResourceName,
        [string]$Location,
        [string]$Severity
    ) {
        $this.CheckId = $CheckId
        $this.Status = $Status
        $this.StatusExtended = $StatusExtended
        $this.ResourceId = $ResourceId
        $this.ResourceName = $ResourceName
        $this.Location = $Location
        $this.Severity = $Severity
    }

    static [CIEMScanResult] Create([hashtable]$CheckMetadata, [string]$Status, [string]$StatusExtended, [string]$ResourceId, [string]$ResourceName, [string]$Location) {
        return [CIEMScanResult]::new(
            $CheckMetadata.id,
            [CIEMScanStatus]$Status,
            $StatusExtended,
            $ResourceId,
            $ResourceName,
            $Location,
            $CheckMetadata.severity
        )
    }

    static [CIEMScanResult] Create([hashtable]$CheckMetadata, [string]$Status, [string]$StatusExtended, [string]$ResourceId, [string]$ResourceName) {
        return [CIEMScanResult]::Create($CheckMetadata, $Status, $StatusExtended, $ResourceId, $ResourceName, 'Global')
    }
}

class CIEMScanRun {
    [string]$Id
    [CIEMScanRunStatus]$Status
    [string]$Provider
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
    [CIEMScanResult[]]$ScanResults
    [string]$ErrorMessage

    # Default constructor - generates Id and sets StartTime
    CIEMScanRun() {
        $this.Id = [guid]::NewGuid().ToString()
        $this.StartTime = Get-Date
        $this.Status = [CIEMScanRunStatus]::Running
        $this.ScanResults = @()
    }

    # Constructor with parameters
    CIEMScanRun([string]$Provider, [string[]]$Services, [bool]$IncludePassed) {
        $this.Id = [guid]::NewGuid().ToString()
        $this.StartTime = Get-Date
        $this.Status = [CIEMScanRunStatus]::Running
        $this.Provider = $Provider
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

    # Calculate counts from ScanResults
    [void] UpdateCounts() {
        if ($this.ScanResults) {
            $this.TotalResults = $this.ScanResults.Count
            $this.FailedResults = @($this.ScanResults | Where-Object { $_.Status -eq 'FAIL' }).Count
            $this.PassedResults = @($this.ScanResults | Where-Object { $_.Status -eq 'PASS' }).Count
            $this.SkippedResults = @($this.ScanResults | Where-Object { $_.Status -eq 'SKIPPED' }).Count
            $this.ManualResults = @($this.ScanResults | Where-Object { $_.Status -eq 'MANUAL' }).Count
        }
    }

    # Mark scan as completed
    [void] Complete() {
        $this.EndTime = Get-Date
        $this.Duration = $this.GetDuration()
        $this.Status = [CIEMScanRunStatus]::Completed
        $this.UpdateCounts()
    }

    # Mark scan as failed
    [void] Fail([string]$ErrorMessage) {
        $this.EndTime = Get-Date
        $this.Duration = $this.GetDuration()
        $this.Status = [CIEMScanRunStatus]::Failed
        $this.ErrorMessage = $ErrorMessage
        $this.UpdateCounts()
    }

    # Convert to hashtable for cache storage (excludes ScanResults)
    [hashtable] ToHashtable() {
        return @{
            Id            = $this.Id
            Status        = $this.Status.ToString()
            Provider      = $this.Provider
            Services      = $this.Services
            StartTime     = $this.StartTime.ToString('o')
            EndTime       = if ($this.EndTime) { $this.EndTime.ToString('o') } else { $null }
            Duration      = $this.Duration
            IncludePassed = $this.IncludePassed
            TotalResults  = $this.TotalResults
            FailedResults = $this.FailedResults
            PassedResults = $this.PassedResults
            SkippedResults = $this.SkippedResults
            ManualResults = $this.ManualResults
            ErrorMessage  = $this.ErrorMessage
        }
    }

    # Create from hashtable (cache retrieval)
    static [CIEMScanRun] FromHashtable([hashtable]$Data) {
        $run = [CIEMScanRun]::new()
        $run.Id = $Data.Id
        $run.Status = [CIEMScanRunStatus]$Data.Status
        $run.Provider = $Data.Provider
        $run.Services = $Data.Services
        $run.StartTime = [datetime]$Data.StartTime
        $run.EndTime = if ($Data.EndTime) { [datetime]$Data.EndTime } else { $null }
        $run.Duration = $Data.Duration
        $run.IncludePassed = $Data.IncludePassed
        $run.TotalResults = $Data.TotalResults
        $run.FailedResults = $Data.FailedResults
        $run.PassedResults = $Data.PassedResults
        $run.SkippedResults = $Data.SkippedResults
        $run.ManualResults = $Data.ManualResults
        $run.ErrorMessage = $Data.ErrorMessage
        return $run
    }
}
