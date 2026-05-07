function ConvertToCIEMScanEfficiencyRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Row
    )

    $durationSeconds = [double]$Row.duration_seconds
    $totalResults = [int]$Row.total_results
    $resultsPerSecond = if ($durationSeconds -gt 0) {
        [math]::Round($totalResults / $durationSeconds, 2)
    }
    else {
        $null
    }

    [PSCustomObject]@{
        Id               = [string]$Row.id
        Status           = [string]$Row.status
        Providers        = @(([string]$Row.resource_providers -split ',') | Where-Object { $_ })
        StartedAt        = [string]$Row.started_at
        CompletedAt      = [string]$Row.completed_at
        DurationSeconds  = [math]::Round($durationSeconds, 2)
        TotalResults     = $totalResults
        FailedResults    = [int]$Row.failed_results
        PassedResults    = [int]$Row.passed_results
        SkippedResults   = [int]$Row.skipped_results
        ManualResults    = [int]$Row.manual_results
        ResultsPerSecond = $resultsPerSecond
    }
}

function Get-CIEMScanEfficiencySummary {
    <#
    .SYNOPSIS
        Returns scan duration and result-throughput instrumentation.
    .DESCRIPTION
        Computes scan-efficiency signals from persisted scan run timings and result
        counts. This command is read-only and does not modify scan execution.
    .PARAMETER Last
        Number of most recent terminal scan runs to include.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Last = 10
    )

    $ErrorActionPreference = 'Stop'

    $rows = @(Invoke-CIEMQuery -Query @"
SELECT id, status, resource_providers, started_at, completed_at, duration_seconds,
       total_results, failed_results, passed_results, skipped_results, manual_results
FROM scan_runs
WHERE completed_at IS NOT NULL
  AND duration_seconds IS NOT NULL
ORDER BY started_at DESC
LIMIT @last
"@ -Parameters @{ last = $Last })

    if ($rows.Count -eq 0) {
        return [PSCustomObject]@{
            Status                  = 'NoScanData'
            RunCount                = 0
            LatestRunId             = $null
            LatestDurationSeconds   = $null
            AverageDurationSeconds  = $null
            SlowestRunId            = $null
            SlowestDurationSeconds  = $null
            LatestResultsPerSecond  = $null
            AverageResultsPerSecond = $null
            TotalResults            = 0
            FailedResults           = 0
            PassedResults           = 0
            SkippedResults          = 0
            ManualResults           = 0
            Runs                    = @()
        }
    }

    $runs = @(foreach ($row in $rows) {
        ConvertToCIEMScanEfficiencyRun -Row $row
    })

    $durationValues = @($runs | ForEach-Object { [double]$_.DurationSeconds })
    $throughputValues = @($runs | Where-Object { $null -ne $_.ResultsPerSecond } | ForEach-Object { [double]$_.ResultsPerSecond })
    $slowestRun = @($runs | Sort-Object -Property DurationSeconds -Descending | Select-Object -First 1)[0]
    $latestRun = $runs[0]

    [PSCustomObject]@{
        Status                  = 'Tracked'
        RunCount                = $runs.Count
        LatestRunId             = [string]$latestRun.Id
        LatestDurationSeconds   = [double]$latestRun.DurationSeconds
        AverageDurationSeconds  = [math]::Round(($durationValues | Measure-Object -Average).Average, 2)
        SlowestRunId            = [string]$slowestRun.Id
        SlowestDurationSeconds  = [double]$slowestRun.DurationSeconds
        LatestResultsPerSecond  = $latestRun.ResultsPerSecond
        AverageResultsPerSecond = if ($throughputValues.Count -gt 0) {
            [math]::Round(($throughputValues | Measure-Object -Average).Average, 2)
        }
        else {
            $null
        }
        TotalResults            = [int](($runs | Measure-Object -Property TotalResults -Sum).Sum)
        FailedResults           = [int](($runs | Measure-Object -Property FailedResults -Sum).Sum)
        PassedResults           = [int](($runs | Measure-Object -Property PassedResults -Sum).Sum)
        SkippedResults          = [int](($runs | Measure-Object -Property SkippedResults -Sum).Sum)
        ManualResults           = [int](($runs | Measure-Object -Property ManualResults -Sum).Sum)
        Runs                    = $runs
    }
}
