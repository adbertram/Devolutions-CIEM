function GetCIEMEnvironmentalProgressReportData {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByPairId')]
        [string]$EvidencePairId
    )

    $ErrorActionPreference = 'Stop'

    function New-ProgressContext {
        param(
            [Parameter(Mandatory)]
            [object]$Pair
        )

        $ErrorActionPreference = 'Stop'

        $contract = GetCIEMEnvironmentalProgressStatusContract -Status $Pair.Status
        @{
            Status                 = $Pair.Status
            StatusMessage          = $contract.StatusMessage
            ContextChipKeys        = [string[]]$contract.ContextChipKeys
            MetricKeys             = [string[]]$contract.MetricKeys
            BaselineDiscoveryRunId = $Pair.BaselineDiscoveryRunId
            BaselineCompletedAt    = $Pair.BaselineCompletedAt
            BaselineScanRunId      = $Pair.BaselineScanRunId
            CurrentDiscoveryRunId  = $Pair.CurrentDiscoveryRunId
            CurrentCompletedAt     = $Pair.CurrentCompletedAt
            CurrentScanRunId       = $Pair.CurrentScanRunId
            ProgressScopeHash      = $Pair.ProgressScopeHash
            BaselineIssueCount     = 0
            CurrentIssueCount      = 0
            FixedIssueCount        = 0
            FixedAttackPathCount   = 0
            FixedCheckCount        = 0
            RemainingIssueCount    = 0
            NewIssueCount          = 0
            BurnDownPercent        = $null
        }
    }

    function Get-AttackPathSignals {
        param(
            [Parameter(Mandatory)]
            [int]$DiscoveryRunId
        )

        $ErrorActionPreference = 'Stop'

        $rows = @(Invoke-CIEMQuery -Query @"
SELECT
    progress_key,
    severity,
    title,
    impacted_identity_name,
    impacted_resource_name,
    evidence
FROM ciem_exposure_snapshot_items
WHERE discovery_run_id = @discovery_run_id
AND exposure_type = 'AttackPath'
"@ -Parameters @{ discovery_run_id = $DiscoveryRunId })

        foreach ($row in $rows) {
            $progressKey = [string]$row.progress_key
            if ([string]::IsNullOrWhiteSpace($progressKey)) {
                throw "AttackPath snapshot row for discovery run $DiscoveryRunId has a blank progress_key."
            }

            [pscustomobject]@{
                SignalKey = "attack-path|$progressKey"
                SignalType = 'AttackPath'
                Severity = [string]$row.severity
                Title = [string]$row.title
                Identity = [string]$row.impacted_identity_name
                Resource = [string]$row.impacted_resource_name
                Evidence = [string]$row.evidence
            }
        }
    }

    function Get-FailedCheckSignals {
        param(
            [Parameter(Mandatory)]
            [string]$ScanRunId
        )

        $ErrorActionPreference = 'Stop'

        $rows = @(Invoke-CIEMQuery -Query @"
SELECT
    r.check_id,
    r.resource_id,
    r.resource_name,
    r.status_extended,
    s.snapshot_json
FROM scan_results r
LEFT JOIN scan_run_check_snapshots s
    ON s.scan_run_id = r.scan_run_id
   AND s.check_id = r.check_id
WHERE r.scan_run_id = @scan_run_id
AND r.status = 'FAIL'
"@ -Parameters @{ scan_run_id = $ScanRunId })

        $seenKeys = @{}
        foreach ($row in $rows) {
            $checkId = [string]$row.check_id
            $resourceId = [string]$row.resource_id
            $signalKey = "check|$checkId|$resourceId"
            if ($seenKeys.ContainsKey($signalKey)) {
                throw "Scan run '$ScanRunId' contains duplicate failed-check key '$signalKey'."
            }
            $seenKeys[$signalKey] = $true

            if ([string]::IsNullOrWhiteSpace([string]$row.snapshot_json)) {
                throw "Progress scan '$ScanRunId' failed-check row '$signalKey' has no check snapshot."
            }
            $check = ConvertFromCIEMCheckSnapshotJson -SnapshotJson ([string]$row.snapshot_json) -Context "progress scan '$ScanRunId' check '$checkId'"

            [pscustomobject]@{
                SignalKey  = $signalKey
                SignalType = 'Check'
                Severity   = [string]$check.Severity
                Title      = [string]$check.Title
                Identity   = $null
                Resource   = [string]$row.resource_name
                Evidence   = [string]$row.status_extended
            }
        }
    }

    function Convert-ComparisonToReportRow {
        param(
            [Parameter(Mandatory)]
            [object]$Comparison,

            [Parameter(Mandatory)]
            [object]$Pair
        )

        $ErrorActionPreference = 'Stop'

        $source = if ($Comparison.CurrentItem) { $Comparison.CurrentItem } else { $Comparison.BaselineItem }
        [pscustomobject]@{
            Status                 = [string]$Comparison.Status
            SignalType             = [string]$source.SignalType
            SignalKey              = [string]$source.SignalKey
            Severity               = [string]$source.Severity
            Title                  = [string]$source.Title
            Identity               = $source.Identity
            Resource               = $source.Resource
            BaselineDiscoveryRunId = $Pair.BaselineDiscoveryRunId
            CurrentDiscoveryRunId  = $Pair.CurrentDiscoveryRunId
            BaselineScanRunId      = $Pair.BaselineScanRunId
            CurrentScanRunId       = $Pair.CurrentScanRunId
            Evidence               = [string]$source.Evidence
        }
    }

    $pair = if ($PSCmdlet.ParameterSetName -eq 'ByPairId') {
        GetCIEMEnvironmentalProgressEvidencePair -EvidencePairId $EvidencePairId
    }
    else {
        GetCIEMEnvironmentalProgressEvidencePair
    }

    $context = New-ProgressContext -Pair $pair
    if ($pair.Status -ne 'ProgressTracked') {
        return [pscustomobject]@{
            Rows = @()
            Context = $context
        }
    }

    $baselineSignals = @(
        Get-AttackPathSignals -DiscoveryRunId $pair.BaselineDiscoveryRunId
        Get-FailedCheckSignals -ScanRunId $pair.BaselineScanRunId
    )
    $currentSignals = @(
        Get-AttackPathSignals -DiscoveryRunId $pair.CurrentDiscoveryRunId
        Get-FailedCheckSignals -ScanRunId $pair.CurrentScanRunId
    )

    $transitionMap = @{
        BaselineOnly = 'Fixed'
        Both = 'Remaining'
        CurrentOnly = 'New'
    }
    $comparisons = @(CompareCIEMKeyedSet -BaselineItems $baselineSignals -CurrentItems $currentSignals -KeyProperty SignalKey -TransitionMap $transitionMap)
    $rows = @($comparisons | ForEach-Object { Convert-ComparisonToReportRow -Comparison $_ -Pair $pair })

    $context.BaselineIssueCount = $baselineSignals.Count
    $context.CurrentIssueCount = $currentSignals.Count
    $context.FixedIssueCount = @($rows | Where-Object { $_.Status -eq 'Fixed' }).Count
    $context.FixedAttackPathCount = @($rows | Where-Object { $_.Status -eq 'Fixed' -and $_.SignalType -eq 'AttackPath' }).Count
    $context.FixedCheckCount = @($rows | Where-Object { $_.Status -eq 'Fixed' -and $_.SignalType -eq 'Check' }).Count
    $context.RemainingIssueCount = @($rows | Where-Object { $_.Status -eq 'Remaining' }).Count
    $context.NewIssueCount = @($rows | Where-Object { $_.Status -eq 'New' }).Count
    if ($context.BaselineIssueCount -gt 0) {
        $context.BurnDownPercent = [math]::Round(($context.FixedIssueCount / $context.BaselineIssueCount) * 100, 1)
    }

    [pscustomobject]@{
        Rows = $rows
        Context = $context
    }
}
