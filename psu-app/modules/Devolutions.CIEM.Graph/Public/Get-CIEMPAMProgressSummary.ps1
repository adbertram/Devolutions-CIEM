function ConvertCIEMPAMCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item
    )

    $ErrorActionPreference = 'Stop'

    switch ([string]$Item.SourceType) {
        'Identity' {
            $capability = 'JIT elevation and approval workflow'
            $nextStep = 'Review standing privileged access and decide whether it should move to PAM-backed JIT or approval.'
        }
        'AttackPath' {
            $capability = 'Access brokering and session governance'
            $nextStep = 'Review the exposed path and decide whether privileged sessions should be brokered and governed through PAM.'
        }
        default {
            throw "Unsupported PAM progress source type '$($Item.SourceType)'."
        }
    }

    [PSCustomObject]@{
        Id                  = [string]$Item.Id
        SourceType          = [string]$Item.SourceType
        Severity            = [string]$Item.Severity
        Title               = [string]$Item.Title
        Identity            = [string]$Item.Identity
        Target              = [string]$Item.Target
        Reason              = [string]$Item.Reason
        Evidence            = [string]$Item.Evidence
        PAMCapability       = $capability
        RecommendedNextStep = $nextStep
        Status              = 'Candidate'
    }
}

function NewCIEMPAMProgressStage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('Complete', 'Pending', 'NotScoped')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Evidence
    )

    $ErrorActionPreference = 'Stop'

    [PSCustomObject]@{
        Name     = $Name
        Status   = $Status
        Evidence = $Evidence
    }
}

function Get-CIEMPAMProgressSummary {
    <#
    .SYNOPSIS
        Returns read-only CIEM-to-PAM implementation progress signals.
    .DESCRIPTION
        Computes progress and readiness from discovered CIEM data, exposure snapshots,
        exposure changes, and current risk candidates. This command does not create
        PAM records, open approvals, update cloud access, or send connector payloads.
    .PARAMETER Limit
        Maximum number of PAM candidate items to include.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Limit = 10
    )

    $ErrorActionPreference = 'Stop'

    $graphRows = @(Invoke-CIEMQuery -Query 'SELECT COUNT(*) AS c FROM graph_nodes')
    if ($graphRows.Count -ne 1) {
        throw "Expected one graph node count row, got $($graphRows.Count)."
    }
    $graphNodeCount = [int]$graphRows[0].c

    $snapshotRows = @(Invoke-CIEMQuery -Query @"
SELECT discovery_run_id,
       COUNT(*) AS exposure_count,
       SUM(CASE WHEN severity_rank <= 2 THEN 1 ELSE 0 END) AS critical_high_count
FROM ciem_exposure_snapshot_items
GROUP BY discovery_run_id
ORDER BY discovery_run_id ASC
"@)

    $baselineRunId = $null
    $currentRunId = $null
    $baselineExposureCount = 0
    $currentExposureCount = 0
    $currentCriticalHighCount = 0

    if ($snapshotRows.Count -gt 0) {
        $baseline = $snapshotRows[0]
        $current = $snapshotRows[$snapshotRows.Count - 1]
        $baselineRunId = [int]$baseline.discovery_run_id
        $currentRunId = [int]$current.discovery_run_id
        $baselineExposureCount = [int]$baseline.exposure_count
        $currentExposureCount = [int]$current.exposure_count
        $currentCriticalHighCount = [int]$current.critical_high_count
    }

    $changeRows = @(Invoke-CIEMQuery -Query @"
SELECT COUNT(*) AS total_count,
       SUM(CASE WHEN change_type = 'NewRisk' THEN 1 ELSE 0 END) AS new_risk_count,
       SUM(CASE WHEN change_type = 'RiskIncrease' THEN 1 ELSE 0 END) AS risk_increase_count,
       SUM(CASE WHEN change_type = 'RemovedRisk' THEN 1 ELSE 0 END) AS removed_risk_count
FROM ciem_exposure_changes
"@)
    if ($changeRows.Count -ne 1) {
        throw "Expected one exposure change count row, got $($changeRows.Count)."
    }

    $candidateItems = @(
        foreach ($item in @(Get-CIEMDashboardNeedsAttention -Limit $Limit)) {
            ConvertCIEMPAMCandidate -Item $item
        }
    )

    $jitCandidateCount = @($candidateItems | Where-Object { $_.PAMCapability -eq 'JIT elevation and approval workflow' }).Count
    $brokeredAccessCandidateCount = @($candidateItems | Where-Object { $_.PAMCapability -eq 'Access brokering and session governance' }).Count
    $changeCount = [int]$changeRows[0].total_count
    $snapshotCount = $snapshotRows.Count
    $exposureDelta = $currentExposureCount - $baselineExposureCount
    $riskBurndownPercent = if ($baselineExposureCount -gt 0) {
        [math]::Round((($baselineExposureCount - $currentExposureCount) / $baselineExposureCount) * 100, 1)
    }
    else {
        $null
    }

    $stages = @(
        NewCIEMPAMProgressStage `
            -Name 'Discovery graph' `
            -Status $(if ($graphNodeCount -gt 0) { 'Complete' } else { 'Pending' }) `
            -Evidence "$graphNodeCount graph node(s)"
        NewCIEMPAMProgressStage `
            -Name 'Exposure baseline' `
            -Status $(if ($snapshotCount -gt 0) { 'Complete' } else { 'Pending' }) `
            -Evidence "$snapshotCount exposure snapshot run(s)"
        NewCIEMPAMProgressStage `
            -Name 'Exposure change tracking' `
            -Status $(if ($snapshotCount -ge 2 -or $changeCount -gt 0) { 'Complete' } else { 'Pending' }) `
            -Evidence "$changeCount exposure change(s)"
        NewCIEMPAMProgressStage `
            -Name 'PAM candidate mapping' `
            -Status $(if ($candidateItems.Count -gt 0) { 'Complete' } else { 'Pending' }) `
            -Evidence "$($candidateItems.Count) PAM candidate(s)"
        NewCIEMPAMProgressStage `
            -Name 'Outbound PAM actions' `
            -Status 'NotScoped' `
            -Evidence 'Read-only CIEM scope; no PAM records, approvals, or access changes are created.'
    )

    $completeTrackableStages = @($stages | Where-Object { $_.Status -eq 'Complete' }).Count
    $readinessPercent = [math]::Round(($completeTrackableStages / 4) * 100, 0)
    $status = if ($graphNodeCount -eq 0) {
        'DiscoveryRequired'
    }
    elseif ($candidateItems.Count -eq 0) {
        'NoPAMCandidates'
    }
    elseif ($snapshotCount -ge 2 -or $changeCount -gt 0) {
        'ProgressTracked'
    }
    else {
        'BaselineReady'
    }

    [PSCustomObject]@{
        Status                       = $status
        ReadinessPercent             = [int]$readinessPercent
        BaselineDiscoveryRunId       = $baselineRunId
        CurrentDiscoveryRunId        = $currentRunId
        BaselineExposureCount        = $baselineExposureCount
        CurrentExposureCount         = $currentExposureCount
        CurrentCriticalHighCount     = $currentCriticalHighCount
        ExposureDelta                = $exposureDelta
        RiskBurndownPercent          = $riskBurndownPercent
        ExposureChangeCount          = $changeCount
        NewRiskCount                 = [int]$changeRows[0].new_risk_count
        RiskIncreaseCount            = [int]$changeRows[0].risk_increase_count
        RemovedRiskCount             = [int]$changeRows[0].removed_risk_count
        PAMCandidateCount            = $candidateItems.Count
        JITCandidateCount            = $jitCandidateCount
        BrokeredAccessCandidateCount = $brokeredAccessCandidateCount
        PAMActionStatus              = 'NotScopedReadOnly'
        Stages                       = $stages
        Candidates                   = $candidateItems
    }
}
