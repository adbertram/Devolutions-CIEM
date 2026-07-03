function NewCIEMIdentityExposureSnapshotItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Summary,

        [Parameter(Mandatory)]
        [int]$DiscoveryRunId,

        [Parameter(Mandatory)]
        [string]$ObservedAt
    )

    $ErrorActionPreference = 'Stop'

    $signals = Get-CIEMIdentityRiskSignals -PrincipalId ([string]$Summary.Id)
    $roleAssignments = @($signals.RoleAssignments)
    $targetAssignment = @($roleAssignments |
        Sort-Object `
            @{ Expression = { if ([bool]$_.IsPrivileged) { 0 } else { 1 } } }, `
            @{ Expression = { [string]$_.Scope } } |
        Select-Object -First 1)
    $targetName = if ($targetAssignment.Count -eq 1) { [string]$targetAssignment[0].Scope } else { '' }
    $severity = ConvertToCIEMExposureSeverityLabel -Severity ([string]$Summary.RiskLevel)
    $state = [PSCustomObject]@{
        RiskLevel        = $severity
        EntitlementCount = [int]$Summary.EntitlementCount
        PrivilegedCount  = [int]$Summary.PrivilegedCount
        InheritedCount   = [int]$Summary.InheritedCount
        RoleAssignments  = @($roleAssignments | Select-Object RoleName, Scope, IsPrivileged, IsInherited, InheritedFrom)
    }

    [PSCustomObject]@{
        DiscoveryRunId        = $DiscoveryRunId
        ExposureKey           = "identity:$($Summary.Id)"
        ExposureType          = 'IdentityRisk'
        Severity              = $severity
        SeverityRank          = ConvertCIEMExposureSeverityRank -Severity $severity
        ImpactedIdentityId    = [string]$Summary.Id
        ImpactedIdentityName  = [string]$Summary.DisplayName
        ImpactedIdentityType  = [string]$Summary.PrincipalType
        ImpactedResourceId    = $targetName
        ImpactedResourceName  = $targetName
        Title                 = [string]$Summary.DisplayName
        StateJson             = $state | ConvertTo-Json -Depth 6 -Compress
        Evidence              = "$($Summary.EntitlementCount) entitlement(s); $($Summary.PrivilegedCount) privileged; $($Summary.InheritedCount) inherited; target $targetName"
        ObservedAt            = $ObservedAt
        ProgressKey           = $null
    }
}

function NewCIEMAttackPathExposureSnapshotItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$AttackPath,

        [Parameter(Mandatory)]
        [int]$DiscoveryRunId,

        [Parameter(Mandatory)]
        [string]$ObservedAt
    )

    $ErrorActionPreference = 'Stop'

    $pathNodes = @($AttackPath.Path)
    if ($pathNodes.Count -eq 0) {
        throw "Attack path '$($AttackPath.Id)' has no path nodes."
    }

    $identityKinds = @('EntraUser', 'EntraServicePrincipal', 'EntraManagedIdentity', 'EntraGroup')
    $identityNode = @($pathNodes | Where-Object { $identityKinds -contains [string]$_.kind } | Select-Object -First 1)
    $targetNode = $pathNodes[$pathNodes.Count - 1]
    $identityId = if ($identityNode.Count -eq 1) { [string]$identityNode[0].id } else { '' }
    $identityName = if ($identityNode.Count -eq 1 -and $identityNode[0].display_name) { [string]$identityNode[0].display_name } else { $identityId }
    $identityType = if ($identityNode.Count -eq 1) {
        switch ([string]$identityNode[0].kind) {
            'EntraUser' { 'User'; break }
            'EntraServicePrincipal' { 'ServicePrincipal'; break }
            'EntraManagedIdentity' { 'ManagedIdentity'; break }
            'EntraGroup' { 'Group'; break }
            default { throw "Unsupported attack path identity kind '$($identityNode[0].kind)'." }
        }
    } else { '' }
    $targetId = [string]$targetNode.id
    $targetName = if ($targetNode.display_name) { [string]$targetNode.display_name } else { $targetId }
    $severity = ConvertToCIEMExposureSeverityLabel -Severity ([string]$AttackPath.Severity)
    $state = [PSCustomObject]@{
        PatternName = [string]$AttackPath.PatternName
        RuleId      = [string]$AttackPath.RuleId
        PathChain   = [string]$AttackPath.PathChain
    }

    [PSCustomObject]@{
        DiscoveryRunId        = $DiscoveryRunId
        ExposureKey           = "attack-path:$($AttackPath.Id)"
        ExposureType          = 'AttackPath'
        Severity              = $severity
        SeverityRank          = ConvertCIEMExposureSeverityRank -Severity $severity
        ImpactedIdentityId    = $identityId
        ImpactedIdentityName  = $identityName
        ImpactedIdentityType  = $identityType
        ImpactedResourceId    = $targetId
        ImpactedResourceName  = $targetName
        Title                 = [string]$AttackPath.PatternName
        StateJson             = $state | ConvertTo-Json -Compress
        Evidence              = [string]$AttackPath.PathChain
        ObservedAt            = $ObservedAt
        ProgressKey           = GetCIEMStableAttackPathProgressKey -AttackPath $AttackPath
    }
}

function NewCIEMExposureSnapshotItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$DiscoveryRunId,

        [Parameter(Mandatory)]
        [string]$ObservedAt
    )

    $ErrorActionPreference = 'Stop'

    $items = @()
    foreach ($summary in @(Get-CIEMIdentityRiskSummary)) {
        $items += NewCIEMIdentityExposureSnapshotItem -Summary $summary -DiscoveryRunId $DiscoveryRunId -ObservedAt $ObservedAt
    }
    foreach ($attackPath in @(Get-CIEMAttackPath)) {
        $items += NewCIEMAttackPathExposureSnapshotItem -AttackPath $attackPath -DiscoveryRunId $DiscoveryRunId -ObservedAt $ObservedAt
    }

    foreach ($attackPathItem in @($items | Where-Object { $_.ExposureType -eq 'AttackPath' })) {
        if ([string]::IsNullOrWhiteSpace([string]$attackPathItem.ProgressKey)) {
            throw "AttackPath snapshot item '$($attackPathItem.ExposureKey)' has a blank progress key."
        }
    }

    @($items)
}

function SaveCIEMExposureSnapshotCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Connection,

        [Parameter(Mandatory)]
        [int]$DiscoveryRunId,

        [Parameter(Mandatory)]
        [string]$ObservedAt,

        [Parameter()]
        [string]$AttackPathScopeHash,

        [Parameter()]
        [string]$DiscoveryScopeHash,

        [Parameter()]
        [ValidateSet('Completed', 'Partial', 'Failed')]
        [string]$TerminalStatus,

        [Parameter()]
        [int]$ArmTypeCount,

        [Parameter()]
        [int]$ArmRowCount,

        [Parameter()]
        [int]$EntraTypeCount,

        [Parameter()]
        [int]$EntraRowCount,

        [Parameter()]
        [int]$WarningCount,

        [Parameter()]
        [string]$ErrorMessage,

        [Parameter()]
        [object[]]$Items
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($ObservedAt)) {
        throw "ObservedAt is required when saving exposure snapshot for discovery run '$DiscoveryRunId'."
    }

    $snapshotItems = if ($PSBoundParameters.ContainsKey('Items')) {
        @($Items)
    }
    else {
        @(NewCIEMExposureSnapshotItems -DiscoveryRunId $DiscoveryRunId -ObservedAt $ObservedAt)
    }

    foreach ($attackPathItem in @($snapshotItems | Where-Object { $_.ExposureType -eq 'AttackPath' })) {
        if ([string]::IsNullOrWhiteSpace([string]$attackPathItem.ProgressKey)) {
            throw "AttackPath snapshot item '$($attackPathItem.ExposureKey)' has a blank progress key."
        }
    }

    Invoke-PSUSQLiteQuery -Connection $Connection -Query 'DELETE FROM ciem_exposure_snapshot_items WHERE discovery_run_id = @discovery_run_id' -Parameters @{
        discovery_run_id = $DiscoveryRunId
    } -AsNonQuery | Out-Null

    foreach ($item in $snapshotItems) {
        Invoke-PSUSQLiteQuery -Connection $Connection -Query @"
INSERT INTO ciem_exposure_snapshot_items (
    discovery_run_id, exposure_key, exposure_type, severity, severity_rank,
    impacted_identity_id, impacted_identity_name, impacted_identity_type,
    impacted_resource_id, impacted_resource_name, title, state_json, evidence,
    observed_at, progress_key
)
VALUES (
    @discovery_run_id, @exposure_key, @exposure_type, @severity, @severity_rank,
    @impacted_identity_id, @impacted_identity_name, @impacted_identity_type,
    @impacted_resource_id, @impacted_resource_name, @title, @state_json, @evidence,
    @observed_at, @progress_key
)
"@ -Parameters @{
            discovery_run_id       = $item.DiscoveryRunId
            exposure_key           = $item.ExposureKey
            exposure_type          = $item.ExposureType
            severity               = $item.Severity
            severity_rank          = $item.SeverityRank
            impacted_identity_id   = $item.ImpactedIdentityId
            impacted_identity_name = $item.ImpactedIdentityName
            impacted_identity_type = $item.ImpactedIdentityType
            impacted_resource_id   = $item.ImpactedResourceId
            impacted_resource_name = $item.ImpactedResourceName
            title                  = $item.Title
            state_json             = $item.StateJson
            evidence               = $item.Evidence
            observed_at            = $item.ObservedAt
            progress_key           = $item.ProgressKey
        } -AsNonQuery | Out-Null
    }

    if ($PSBoundParameters.ContainsKey('TerminalStatus')) {
        Invoke-PSUSQLiteQuery -Connection $Connection -Query @"
UPDATE azure_discovery_runs
SET status = @status,
    completed_at = @completed_at,
    arm_type_count = @arm_type_count,
    arm_row_count = @arm_row_count,
    entra_type_count = @entra_type_count,
    entra_row_count = @entra_row_count,
    warning_count = @warning_count,
    error_message = @error_message,
    attack_path_scope_hash = @attack_path_scope_hash,
    discovery_scope_hash = @discovery_scope_hash,
    exposure_snapshot_completed_at = @exposure_snapshot_completed_at
WHERE id = @id
"@ -Parameters @{
            id                             = $DiscoveryRunId
            status                         = $TerminalStatus
            completed_at                   = $ObservedAt
            arm_type_count                 = $ArmTypeCount
            arm_row_count                  = $ArmRowCount
            entra_type_count               = $EntraTypeCount
            entra_row_count                = $EntraRowCount
            warning_count                  = $WarningCount
            error_message                  = $ErrorMessage
            attack_path_scope_hash         = $AttackPathScopeHash
            discovery_scope_hash           = $DiscoveryScopeHash
            exposure_snapshot_completed_at = if ([string]::IsNullOrWhiteSpace($AttackPathScopeHash) -or [string]::IsNullOrWhiteSpace($DiscoveryScopeHash)) { $null } else { $ObservedAt }
        } -AsNonQuery | Out-Null
    }
    elseif ($PSBoundParameters.ContainsKey('AttackPathScopeHash') -or $PSBoundParameters.ContainsKey('DiscoveryScopeHash')) {
        Invoke-PSUSQLiteQuery -Connection $Connection -Query @"
UPDATE azure_discovery_runs
SET attack_path_scope_hash = @attack_path_scope_hash,
    discovery_scope_hash = @discovery_scope_hash,
    exposure_snapshot_completed_at = @exposure_snapshot_completed_at
WHERE id = @id
"@ -Parameters @{
            id                             = $DiscoveryRunId
            attack_path_scope_hash         = $AttackPathScopeHash
            discovery_scope_hash           = $DiscoveryScopeHash
            exposure_snapshot_completed_at = if ([string]::IsNullOrWhiteSpace($AttackPathScopeHash) -or [string]::IsNullOrWhiteSpace($DiscoveryScopeHash)) { $null } else { $ObservedAt }
        } -AsNonQuery | Out-Null
    }

    @($snapshotItems)
}

function Save-CIEMExposureSnapshot {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Materializes local exposure snapshot records for a discovery run')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [int]$DiscoveryRunId
    )

    $ErrorActionPreference = 'Stop'

    $run = @(Get-CIEMAzureDiscoveryRun -Id $DiscoveryRunId)
    if ($run.Count -ne 1) {
        throw "Expected one discovery run with Id '$DiscoveryRunId', found $($run.Count)."
    }
    if ([string]::IsNullOrWhiteSpace([string]$run[0].CompletedAt)) {
        throw "Discovery run '$DiscoveryRunId' must be completed before an exposure snapshot can be saved."
    }

    $observedAt = [string]$run[0].CompletedAt
    $items = @(NewCIEMExposureSnapshotItems -DiscoveryRunId $DiscoveryRunId -ObservedAt $observedAt)
    InvokeCIEMTransaction {
        param($conn)
        $script:SavedExposureSnapshotItems = @(SaveCIEMExposureSnapshotCore -Connection $conn -DiscoveryRunId $DiscoveryRunId -ObservedAt $observedAt -Items $items)
    }
    $savedItems = @($script:SavedExposureSnapshotItems)
    $script:SavedExposureSnapshotItems = $null
    @($savedItems)
}
