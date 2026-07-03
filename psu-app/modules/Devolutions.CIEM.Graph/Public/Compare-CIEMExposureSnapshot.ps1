function NewCIEMExposureChange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('NewRisk', 'RemovedRisk', 'RiskIncrease')]
        [string]$ChangeType,

        [Parameter()]
        [object]$Previous,

        [Parameter()]
        [object]$Current,

        [Parameter(Mandatory)]
        [int]$PreviousDiscoveryRunId,

        [Parameter(Mandatory)]
        [int]$CurrentDiscoveryRunId,

        [Parameter(Mandatory)]
        [string]$CreatedAt
    )

    $ErrorActionPreference = 'Stop'

    $source = if ($Current) { $Current } else { $Previous }
    $severity = if ($ChangeType -eq 'RemovedRisk') { [string]$Previous.severity } else { [string]$Current.severity }
    $severityRank = if ($ChangeType -eq 'RemovedRisk') { [int]$Previous.severity_rank } else { [int]$Current.severity_rank }
    $previousSeverity = if ($Previous) { [string]$Previous.severity } else { $null }
    $currentSeverity = if ($Current) { [string]$Current.severity } else { $null }
    $firstSeenAt = if ($Current) { [string]$Current.observed_at } else { $CreatedAt }
    $title = [string]$source.title
    $evidence = switch ($ChangeType) {
        'NewRisk' { "New $severity $($source.exposure_type) exposure: $title" }
        'RemovedRisk' { "Removed $severity $($source.exposure_type) exposure: $title" }
        'RiskIncrease' { "$($source.exposure_type) exposure increased from $previousSeverity to ${currentSeverity}: $title" }
    }

    [PSCustomObject]@{
        Id                     = "${CurrentDiscoveryRunId}:${ChangeType}:$($source.exposure_key)"
        PreviousDiscoveryRunId = $PreviousDiscoveryRunId
        CurrentDiscoveryRunId  = $CurrentDiscoveryRunId
        ExposureKey            = [string]$source.exposure_key
        ChangeType             = $ChangeType
        ExposureType           = [string]$source.exposure_type
        Severity               = $severity
        SeverityRank           = $severityRank
        Title                  = $title
        PreviousSeverity       = $previousSeverity
        CurrentSeverity        = $currentSeverity
        ImpactedIdentityId     = [string]$source.impacted_identity_id
        ImpactedIdentityName   = [string]$source.impacted_identity_name
        ImpactedIdentityType   = [string]$source.impacted_identity_type
        ImpactedResourceId     = [string]$source.impacted_resource_id
        ImpactedResourceName   = [string]$source.impacted_resource_name
        FirstSeenAt            = $firstSeenAt
        PreviousStateJson      = if ($Previous) { [string]$Previous.state_json } else { $null }
        CurrentStateJson       = if ($Current) { [string]$Current.state_json } else { $null }
        Evidence               = $evidence
        CreatedAt              = $CreatedAt
    }
}

function GetCIEMExposureComparisonKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$SnapshotItem
    )

    $ErrorActionPreference = 'Stop'

    $progressKey = [string]$SnapshotItem.progress_key
    if (-not [string]::IsNullOrWhiteSpace($progressKey)) {
        return $progressKey
    }

    [string]$SnapshotItem.exposure_key
}

function Compare-CIEMExposureSnapshot {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Persists local exposure-change records generated from two snapshots')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [int]$PreviousDiscoveryRunId,

        [Parameter(Mandatory)]
        [int]$CurrentDiscoveryRunId
    )

    $ErrorActionPreference = 'Stop'

    if ($PreviousDiscoveryRunId -eq $CurrentDiscoveryRunId) {
        throw 'PreviousDiscoveryRunId and CurrentDiscoveryRunId must be different.'
    }

    $previousRows = @(Invoke-CIEMQuery -Query 'SELECT * FROM ciem_exposure_snapshot_items WHERE discovery_run_id = @discovery_run_id' -Parameters @{ discovery_run_id = $PreviousDiscoveryRunId })
    $currentRows = @(Invoke-CIEMQuery -Query 'SELECT * FROM ciem_exposure_snapshot_items WHERE discovery_run_id = @discovery_run_id' -Parameters @{ discovery_run_id = $CurrentDiscoveryRunId })

    $previousByKey = @{}
    foreach ($row in $previousRows) {
        $previousByKey[(GetCIEMExposureComparisonKey -SnapshotItem $row)] = $row
    }

    $currentByKey = @{}
    foreach ($row in $currentRows) {
        $currentByKey[(GetCIEMExposureComparisonKey -SnapshotItem $row)] = $row
    }

    $createdAt = (Get-Date).ToString('o')
    $changes = @()

    foreach ($current in $currentRows) {
        $key = GetCIEMExposureComparisonKey -SnapshotItem $current
        $previous = $previousByKey[$key]
        if ($null -eq $previous) {
            if (TestCIEMExposureSeverityIsRisk -Severity ([string]$current.severity)) {
                $changes += NewCIEMExposureChange -ChangeType 'NewRisk' -Previous $null -Current $current -PreviousDiscoveryRunId $PreviousDiscoveryRunId -CurrentDiscoveryRunId $CurrentDiscoveryRunId -CreatedAt $createdAt
            }
        }
        elseif ([int]$current.severity_rank -lt [int]$previous.severity_rank -and (TestCIEMExposureSeverityIsRisk -Severity ([string]$current.severity))) {
            $changes += NewCIEMExposureChange -ChangeType 'RiskIncrease' -Previous $previous -Current $current -PreviousDiscoveryRunId $PreviousDiscoveryRunId -CurrentDiscoveryRunId $CurrentDiscoveryRunId -CreatedAt $createdAt
        }
        elseif ((TestCIEMExposureSeverityIsRisk -Severity ([string]$previous.severity)) -and -not (TestCIEMExposureSeverityIsRisk -Severity ([string]$current.severity))) {
            $changes += NewCIEMExposureChange -ChangeType 'RemovedRisk' -Previous $previous -Current $current -PreviousDiscoveryRunId $PreviousDiscoveryRunId -CurrentDiscoveryRunId $CurrentDiscoveryRunId -CreatedAt $createdAt
        }
    }

    foreach ($previous in $previousRows) {
        $key = GetCIEMExposureComparisonKey -SnapshotItem $previous
        if (-not $currentByKey.ContainsKey($key) -and (TestCIEMExposureSeverityIsRisk -Severity ([string]$previous.severity))) {
            $changes += NewCIEMExposureChange -ChangeType 'RemovedRisk' -Previous $previous -Current $null -PreviousDiscoveryRunId $PreviousDiscoveryRunId -CurrentDiscoveryRunId $CurrentDiscoveryRunId -CreatedAt $createdAt
        }
    }

    Invoke-CIEMQuery -Query 'DELETE FROM ciem_exposure_changes WHERE current_discovery_run_id = @current_discovery_run_id' -Parameters @{ current_discovery_run_id = $CurrentDiscoveryRunId } -AsNonQuery | Out-Null

    foreach ($change in $changes) {
        Invoke-CIEMQuery -Query @"
INSERT INTO ciem_exposure_changes (
    id, previous_discovery_run_id, current_discovery_run_id, exposure_key,
    change_type, exposure_type, severity, severity_rank, title, previous_severity,
    current_severity, impacted_identity_id, impacted_identity_name,
    impacted_identity_type, impacted_resource_id, impacted_resource_name,
    first_seen_at, previous_state_json, current_state_json, evidence, created_at
)
VALUES (
    @id, @previous_discovery_run_id, @current_discovery_run_id, @exposure_key,
    @change_type, @exposure_type, @severity, @severity_rank, @title, @previous_severity,
    @current_severity, @impacted_identity_id, @impacted_identity_name,
    @impacted_identity_type, @impacted_resource_id, @impacted_resource_name,
    @first_seen_at, @previous_state_json, @current_state_json, @evidence, @created_at
)
"@ -Parameters @{
            id                        = $change.Id
            previous_discovery_run_id = $change.PreviousDiscoveryRunId
            current_discovery_run_id  = $change.CurrentDiscoveryRunId
            exposure_key              = $change.ExposureKey
            change_type               = $change.ChangeType
            exposure_type             = $change.ExposureType
            severity                  = $change.Severity
            severity_rank             = $change.SeverityRank
            title                     = $change.Title
            previous_severity         = $change.PreviousSeverity
            current_severity          = $change.CurrentSeverity
            impacted_identity_id      = $change.ImpactedIdentityId
            impacted_identity_name    = $change.ImpactedIdentityName
            impacted_identity_type    = $change.ImpactedIdentityType
            impacted_resource_id      = $change.ImpactedResourceId
            impacted_resource_name    = $change.ImpactedResourceName
            first_seen_at             = $change.FirstSeenAt
            previous_state_json       = $change.PreviousStateJson
            current_state_json        = $change.CurrentStateJson
            evidence                  = $change.Evidence
            created_at                = $change.CreatedAt
        } -AsNonQuery | Out-Null
    }

    @(Get-CIEMExposureChange -CurrentDiscoveryRunId $CurrentDiscoveryRunId)
}
