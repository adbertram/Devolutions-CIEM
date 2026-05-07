function Get-CIEMExposureChange {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [int]$CurrentDiscoveryRunId,

        [Parameter()]
        [ValidateSet('NewRisk', 'RemovedRisk', 'RiskIncrease')]
        [string]$ChangeType,

        [Parameter()]
        [int]$Last
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @()
    $parameters = @{}

    if ($PSBoundParameters.ContainsKey('CurrentDiscoveryRunId')) {
        $conditions += 'current_discovery_run_id = @current_discovery_run_id'
        $parameters.current_discovery_run_id = $CurrentDiscoveryRunId
    }
    if ($PSBoundParameters.ContainsKey('ChangeType')) {
        $conditions += 'change_type = @change_type'
        $parameters.change_type = $ChangeType
    }

    $query = @"
SELECT id, previous_discovery_run_id, current_discovery_run_id, exposure_key,
       change_type, exposure_type, severity, severity_rank, previous_severity,
       current_severity, impacted_identity_id, impacted_identity_name,
       impacted_identity_type, impacted_resource_id, impacted_resource_name,
       first_seen_at, previous_state_json, current_state_json, evidence, created_at
FROM ciem_exposure_changes
"@

    if ($conditions.Count -gt 0) {
        $query += "`nWHERE " + ($conditions -join ' AND ')
    }

    $query += "`nORDER BY current_discovery_run_id DESC, severity_rank ASC, change_type ASC, exposure_key ASC"
    if ($PSBoundParameters.ContainsKey('Last')) {
        $query += "`nLIMIT @last"
        $parameters.last = $Last
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)

    @(foreach ($row in $rows) {
        [PSCustomObject]@{
            Id                     = [string]$row.id
            PreviousDiscoveryRunId = if ($null -eq $row.previous_discovery_run_id) { $null } else { [int]$row.previous_discovery_run_id }
            CurrentDiscoveryRunId  = [int]$row.current_discovery_run_id
            ExposureKey            = [string]$row.exposure_key
            ChangeType             = [string]$row.change_type
            ExposureType           = [string]$row.exposure_type
            Severity               = [string]$row.severity
            SeverityRank           = [int]$row.severity_rank
            PreviousSeverity       = [string]$row.previous_severity
            CurrentSeverity        = [string]$row.current_severity
            ImpactedIdentityId     = [string]$row.impacted_identity_id
            ImpactedIdentityName   = [string]$row.impacted_identity_name
            ImpactedIdentityType   = [string]$row.impacted_identity_type
            ImpactedResourceId     = [string]$row.impacted_resource_id
            ImpactedResourceName   = [string]$row.impacted_resource_name
            FirstSeenAt            = [string]$row.first_seen_at
            PreviousStateJson      = [string]$row.previous_state_json
            CurrentStateJson       = [string]$row.current_state_json
            Evidence               = [string]$row.evidence
            CreatedAt              = [string]$row.created_at
        }
    })
}
