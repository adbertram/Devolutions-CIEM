function GetCIEMEnvironmentalProgressStatusContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('NoProgressData', 'BaselineReady', 'NoComparableProgressData', 'ProgressTracked')]
        [string]$Status
    )

    $ErrorActionPreference = 'Stop'

    $metricKeys = @('FixedAttackPathCount', 'FixedCheckCount', 'RemainingIssueCount', 'NewIssueCount', 'BurnDownPercent')
    $contracts = @{
        NoProgressData = @{
            StatusMessage  = 'No Azure progress evidence exists yet.'
            MetricKeys     = $metricKeys
            ContextChipKeys = @('Status')
        }
        BaselineReady = @{
            StatusMessage  = 'One Azure progress evidence point exists. Run another comparable Azure scan after the next full discovery to measure change.'
            MetricKeys     = $metricKeys
            ContextChipKeys = @('Status', 'CurrentDiscoveryRunId', 'CurrentScanRunId')
        }
        NoComparableProgressData = @{
            StatusMessage  = 'Azure progress evidence exists, but no two evidence points share the same progress scope.'
            MetricKeys     = $metricKeys
            ContextChipKeys = @('Status', 'CurrentDiscoveryRunId', 'CurrentScanRunId')
        }
        ProgressTracked = @{
            StatusMessage  = 'Azure environmental progress is tracked for the selected evidence pair.'
            MetricKeys     = $metricKeys
            ContextChipKeys = @('Status', 'BaselineDiscoveryRunId', 'BaselineScanRunId', 'CurrentDiscoveryRunId', 'CurrentScanRunId', 'BurnDownPercent')
        }
    }

    [pscustomobject]@{
        Status          = $Status
        StatusMessage   = [string]$contracts[$Status].StatusMessage
        MetricKeys      = [string[]]$contracts[$Status].MetricKeys
        ContextChipKeys = [string[]]$contracts[$Status].ContextChipKeys
    }
}
