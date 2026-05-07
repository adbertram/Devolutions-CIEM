function GetCIEMDashboardSeverityRank {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Severity
    )

    $ErrorActionPreference = 'Stop'

    $normalized = $Severity.ToLowerInvariant()
    switch ($normalized) {
        'critical' { 1 }
        'high' { 2 }
        'medium' { 3 }
        'low' { 4 }
        default { throw "Unsupported dashboard severity '$Severity'." }
    }
}

function ConvertToCIEMDashboardSeverityLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Severity
    )

    $ErrorActionPreference = 'Stop'

    $normalized = $Severity.ToLowerInvariant()
    switch ($normalized) {
        'critical' { 'Critical' }
        'high' { 'High' }
        'medium' { 'Medium' }
        'low' { 'Low' }
        default { throw "Unsupported dashboard severity '$Severity'." }
    }
}

function GetCIEMDashboardSignalRank {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Signal
    )

    $ErrorActionPreference = 'Stop'

    switch ($Signal) {
        'managed-identity-public-exposure' { 1 }
        'dormant-privileged-permissions' { 2 }
        'disabled-with-permissions' { 3 }
        'group-inherited-privileged-role' { 4 }
        'privileged-standing-access' { 5 }
        'attack-path' { 6 }
        default { 7 }
    }
}

function GetCIEMDashboardPrimaryRiskSignal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$RiskSignals
    )

    $ErrorActionPreference = 'Stop'

    @($RiskSignals |
        Sort-Object `
            @{ Expression = { GetCIEMDashboardSeverityRank -Severity ([string]$_.Severity) } }, `
            @{ Expression = { GetCIEMDashboardSignalRank -Signal ([string]$_.Signal) } } |
        Select-Object -First 1)
}

function GetCIEMDashboardIdentityTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$RoleAssignments,

        [Parameter()]
        [object]$HostingResource
    )

    $ErrorActionPreference = 'Stop'

    if ($HostingResource -and [bool]$HostingResource.HasPublicIP) {
        return [string]$HostingResource.Name
    }

    $assignment = @($RoleAssignments |
        Sort-Object `
            @{ Expression = { if ([bool]$_.IsPrivileged) { 0 } else { 1 } } }, `
            @{ Expression = { [string]$_.Scope } } |
        Select-Object -First 1)

    if ($assignment.Count -eq 0) {
        return 'No active assignment target'
    }

    [string]$assignment[0].Scope
}

function GetCIEMDashboardIdentityReason {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Summary,

        [Parameter()]
        [object]$PrimarySignal
    )

    $ErrorActionPreference = 'Stop'

    if ($PrimarySignal) {
        return [string]$PrimarySignal.Description
    }

    if ([int]$Summary.PrivilegedCount -gt 0) {
        return "Holds $($Summary.PrivilegedCount) privileged role assignment(s)"
    }

    if ([int]$Summary.InheritedCount -gt 0) {
        return "Holds $($Summary.InheritedCount) inherited role assignment(s)"
    }

    "Holds $($Summary.EntitlementCount) active entitlement(s)"
}

function GetCIEMDashboardIdentityEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Summary,

        [Parameter(Mandatory)]
        [string]$Target
    )

    $ErrorActionPreference = 'Stop'

    $parts = @(
        "$($Summary.EntitlementCount) entitlement(s)"
        "$($Summary.PrivilegedCount) privileged"
        "$($Summary.InheritedCount) inherited"
    )

    if ($Summary.DaysSinceSignIn -ne $null) {
        $parts += "$($Summary.DaysSinceSignIn) day(s) since sign-in"
    }

    $parts += "target $Target"
    $parts -join '; '
}

function GetCIEMDashboardAttackPathIdentityMetadata {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$AttackPath
    )

    $ErrorActionPreference = 'Stop'

    $identityKinds = @('EntraUser', 'EntraServicePrincipal', 'EntraManagedIdentity', 'EntraGroup')
    $identityNode = @($AttackPath.Path | Where-Object { $identityKinds -contains [string]$_.kind } | Select-Object -First 1)
    if ($identityNode.Count -eq 0) {
        return [PSCustomObject]@{
            Id   = ''
            Name = ''
            Type = ''
        }
    }

    $identityType = switch ([string]$identityNode[0].kind) {
        'EntraUser' { 'User'; break }
        'EntraServicePrincipal' { 'ServicePrincipal'; break }
        'EntraManagedIdentity' { 'ManagedIdentity'; break }
        'EntraGroup' { 'Group'; break }
        default { throw "Unsupported attack path identity kind '$($identityNode[0].kind)'." }
    }

    $identityName = if ($identityNode[0].display_name) {
        [string]$identityNode[0].display_name
    }
    else {
        [string]$identityNode[0].id
    }

    [PSCustomObject]@{
        Id   = [string]$identityNode[0].id
        Name = $identityName
        Type = $identityType
    }
}

function GetCIEMDashboardAttackPathTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$AttackPath
    )

    $ErrorActionPreference = 'Stop'

    $pathNodes = @($AttackPath.Path)
    if ($pathNodes.Count -eq 0) {
        throw "Attack path '$($AttackPath.Id)' has no path nodes."
    }

    $targetNode = $pathNodes[$pathNodes.Count - 1]
    if ($targetNode.display_name) {
        return [string]$targetNode.display_name
    }

    [string]$targetNode.id
}

function Get-CIEMDashboardNeedsAttention {
    <#
    .SYNOPSIS
        Returns the highest-priority current risks for the dashboard Needs Attention queue.
    .DESCRIPTION
        Merges identity risk summaries and materialized attack paths into a small, sorted
        queue suitable for dashboard display and drill-in routing. This command is read-only.
    .PARAMETER Limit
        Maximum number of queue items to return.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Limit = 10
    )

    $ErrorActionPreference = 'Stop'

    $items = @()

    foreach ($summary in @(Get-CIEMIdentityRiskSummary | Where-Object { $_.RiskLevel -ne 'Low' })) {
        $signals = Get-CIEMIdentityRiskSignals -PrincipalId ([string]$summary.Id)
        $primarySignal = @(GetCIEMDashboardPrimaryRiskSignal -RiskSignals @($signals.RiskSignals))
        $selectedSignal = if ($primarySignal.Count -gt 0) { $primarySignal[0] } else { $null }
        $signalName = if ($selectedSignal) { [string]$selectedSignal.Signal } else { 'privileged-standing-access' }
        $target = GetCIEMDashboardIdentityTarget -RoleAssignments @($signals.RoleAssignments) -HostingResource $signals.HostingResource
        $reason = GetCIEMDashboardIdentityReason -Summary $summary -PrimarySignal $selectedSignal
        $evidence = GetCIEMDashboardIdentityEvidence -Summary $summary -Target $target

        $items += [PSCustomObject]@{
            Id           = "identity:$($summary.Id)"
            SourceType   = 'Identity'
            Severity     = [string]$summary.RiskLevel
            SeverityRank = GetCIEMDashboardSeverityRank -Severity ([string]$summary.RiskLevel)
            SignalRank   = GetCIEMDashboardSignalRank -Signal $signalName
            Title        = [string]$summary.DisplayName
            Identity     = [string]$summary.DisplayName
            IdentityId   = [string]$summary.Id
            IdentityType = [string]$summary.PrincipalType
            Target       = $target
            Reason       = $reason
            Evidence     = $evidence
            DrillInUrl   = '/ciem/identities'
        }
    }

    foreach ($attackPath in @(Get-CIEMAttackPath)) {
        $severity = ConvertToCIEMDashboardSeverityLabel -Severity ([string]$attackPath.Severity)
        $target = GetCIEMDashboardAttackPathTarget -AttackPath $attackPath
        $identity = GetCIEMDashboardAttackPathIdentityMetadata -AttackPath $attackPath

        $items += [PSCustomObject]@{
            Id           = "attack-path:$($attackPath.Id)"
            SourceType   = 'AttackPath'
            Severity     = $severity
            SeverityRank = GetCIEMDashboardSeverityRank -Severity $severity
            SignalRank   = GetCIEMDashboardSignalRank -Signal 'attack-path'
            Title        = [string]$attackPath.PatternName
            Identity     = [string]$identity.Name
            IdentityId   = [string]$identity.Id
            IdentityType = [string]$identity.Type
            Target       = $target
            Reason       = "Attack path exposes $target"
            Evidence     = [string]$attackPath.PathChain
            DrillInUrl   = '/ciem/attack-paths'
        }
    }

    @($items |
        Sort-Object `
            @{ Expression = { [int]$_.SeverityRank } }, `
            @{ Expression = { [int]$_.SignalRank } }, `
            @{ Expression = { [string]$_.Title } } |
        Select-Object -First $Limit)
}
