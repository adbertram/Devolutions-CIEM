function AssertCIEMConnectorSourceProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Source,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$SignalType
    )

    if ($null -eq $Source.PSObject.Properties[$Name]) {
        throw "$SignalType connector preview source is missing required property '$Name'."
    }
}

function GetCIEMConnectorAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SignalType,

        [Parameter(Mandatory)]
        [string]$SourceType
    )

    if ($SignalType -eq 'NeedsAttention') {
        switch ($SourceType) {
            'Identity' { return @{ Action = 'ReviewIdentity'; Route = '/ciem/identities' } }
            'AttackPath' { return @{ Action = 'ReviewAttackPath'; Route = '/ciem/attack-paths' } }
            default { throw "Unsupported NeedsAttention connector preview source type '$SourceType'." }
        }
    }

    if ($SignalType -eq 'ExposureChange') {
        switch ($SourceType) {
            'IdentityRisk' { return @{ Action = 'ReviewIdentity'; Route = '/ciem/identities' } }
            'AttackPath' { return @{ Action = 'ReviewAttackPath'; Route = '/ciem/attack-paths' } }
            default { throw "Unsupported ExposureChange connector preview source type '$SourceType'." }
        }
    }

    throw "Unsupported connector preview signal type '$SignalType'."
}

function NewCIEMConnectorPayloadPreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Alert', 'SIEM', 'Webhook', 'PSU')]
        [string]$ConnectorType,

        [Parameter(Mandatory)]
        [ValidateSet('NeedsAttention', 'ExposureChange')]
        [string]$SignalType,

        [Parameter(Mandatory)]
        [object]$Signal
    )

    foreach ($propertyName in @('SourceId', 'SourceType', 'Severity', 'SeverityRank', 'Title', 'IdentityId', 'Identity', 'IdentityType', 'TargetId', 'Target', 'Reason', 'Evidence')) {
        AssertCIEMConnectorSourceProperty -Source $Signal -Name $propertyName -SignalType $SignalType
    }

    $action = GetCIEMConnectorAction -SignalType $SignalType -SourceType ([string]$Signal.SourceType)
    $eventName = switch ($SignalType) {
        'NeedsAttention' { 'ciem.risk.needs_attention' }
        'ExposureChange' { 'ciem.exposure.changed' }
    }

    $summary = "$($Signal.Severity) $SignalType signal for $($Signal.Identity): $($Signal.Reason)"
    $payload = [ordered]@{
        schemaVersion   = 'devolutions.ciem.signal.preview.v1'
        previewOnly     = $true
        deliveryEnabled = $false
        connectorType   = $ConnectorType
        eventName       = $eventName
        signalType      = $SignalType
        sourceId        = [string]$Signal.SourceId
        sourceType      = [string]$Signal.SourceType
        severity        = [string]$Signal.Severity
        severityRank    = [int]$Signal.SeverityRank
        title           = [string]$Signal.Title
        summary         = $summary
        identity        = [ordered]@{
            id   = [string]$Signal.IdentityId
            name = [string]$Signal.Identity
            type = [string]$Signal.IdentityType
        }
        target          = [ordered]@{
            id   = [string]$Signal.TargetId
            name = [string]$Signal.Target
        }
        reason          = [string]$Signal.Reason
        evidence        = [string]$Signal.Evidence
        review          = [ordered]@{
            action = [string]$action.Action
            route  = [string]$action.Route
        }
    }

    switch ($ConnectorType) {
        'Alert' {
            $payload.connectorPreview = [ordered]@{
                title = "$($Signal.Severity): $($Signal.Title)"
                body  = $summary
            }
        }
        'SIEM' {
            $payload.connectorPreview = [ordered]@{
                eventCategory = 'cloud.entitlement'
                eventAction   = $eventName
                eventSeverity = [int]$Signal.SeverityRank
                message       = $summary
            }
        }
        'Webhook' {
            $payload.connectorPreview = [ordered]@{
                method = 'POST'
                body   = 'json'
            }
        }
        'PSU' {
            $payload.connectorPreview = [ordered]@{
                app    = 'Devolutions CIEM'
                action = [string]$action.Action
                route  = [string]$action.Route
            }
        }
    }

    [PSCustomObject]@{
        Id            = "$ConnectorType`:$SignalType`:$($Signal.SourceId)"
        ConnectorType = $ConnectorType
        SignalType    = $SignalType
        EventName     = $eventName
        Severity      = [string]$Signal.Severity
        SeverityRank  = [int]$Signal.SeverityRank
        Title         = [string]$Signal.Title
        Summary       = $summary
        ReviewAction  = [string]$action.Action
        ReviewRoute   = [string]$action.Route
        PayloadJson   = ($payload | ConvertTo-Json -Depth 10 -Compress)
    }
}

function ConvertCIEMNeedsAttentionToConnectorSignal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item
    )

    [PSCustomObject]@{
        SourceId     = [string]$Item.Id
        SourceType   = [string]$Item.SourceType
        Severity     = [string]$Item.Severity
        SeverityRank = [int]$Item.SeverityRank
        Title        = [string]$Item.Title
        IdentityId   = [string]$Item.IdentityId
        Identity     = [string]$Item.Identity
        IdentityType = [string]$Item.IdentityType
        TargetId     = [string]$Item.Target
        Target       = [string]$Item.Target
        Reason       = [string]$Item.Reason
        Evidence     = [string]$Item.Evidence
    }
}

function ConvertCIEMExposureChangeToConnectorSignal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Change
    )

    $reason = switch ([string]$Change.ChangeType) {
        'NewRisk' { "New $($Change.CurrentSeverity) exposure detected" }
        'RiskIncrease' { "Exposure increased from $($Change.PreviousSeverity) to $($Change.CurrentSeverity)" }
        'RemovedRisk' { "Previously observed $($Change.PreviousSeverity) exposure was removed" }
        default { throw "Unsupported exposure change type '$($Change.ChangeType)'." }
    }

    [PSCustomObject]@{
        SourceId     = [string]$Change.Id
        SourceType   = [string]$Change.ExposureType
        Severity     = [string]$Change.Severity
        SeverityRank = [int]$Change.SeverityRank
        Title        = "$($Change.ChangeType): $($Change.ImpactedIdentityName)"
        IdentityId   = [string]$Change.ImpactedIdentityId
        Identity     = [string]$Change.ImpactedIdentityName
        IdentityType = [string]$Change.ImpactedIdentityType
        TargetId     = [string]$Change.ImpactedResourceId
        Target       = [string]$Change.ImpactedResourceName
        Reason       = $reason
        Evidence     = [string]$Change.Evidence
    }
}

function Get-CIEMConnectorPayloadPreview {
    <#
    .SYNOPSIS
        Returns local preview payloads for outbound CIEM signal connectors.
    .DESCRIPTION
        Formats current Needs Attention and exposure-change signals into preview-only
        payload envelopes for Alert, SIEM, Webhook, and PSU connector shapes. This
        command does not send data and does not read connector target settings.
    .PARAMETER ConnectorType
        Connector preview family to render.
    .PARAMETER SignalType
        Signal source to format. All includes Needs Attention and Exposure Change signals.
    .PARAMETER Limit
        Maximum number of source signals to read from each selected source.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateSet('Alert', 'SIEM', 'Webhook', 'PSU')]
        [string[]]$ConnectorType = @('Alert', 'SIEM', 'Webhook', 'PSU'),

        [Parameter()]
        [ValidateSet('All', 'NeedsAttention', 'ExposureChange')]
        [string]$SignalType = 'All',

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Limit = 10
    )

    $ErrorActionPreference = 'Stop'

    $signals = @()
    if ($SignalType -in @('All', 'NeedsAttention')) {
        foreach ($item in @(Get-CIEMDashboardNeedsAttention -Limit $Limit)) {
            $signals += [PSCustomObject]@{
                SignalType = 'NeedsAttention'
                Signal     = ConvertCIEMNeedsAttentionToConnectorSignal -Item $item
            }
        }
    }
    if ($SignalType -in @('All', 'ExposureChange')) {
        foreach ($change in @(Get-CIEMExposureChange -Last $Limit)) {
            $signals += [PSCustomObject]@{
                SignalType = 'ExposureChange'
                Signal     = ConvertCIEMExposureChangeToConnectorSignal -Change $change
            }
        }
    }

    @(
        foreach ($signal in $signals) {
            foreach ($type in $ConnectorType) {
                NewCIEMConnectorPayloadPreview -ConnectorType $type -SignalType ([string]$signal.SignalType) -Signal $signal.Signal
            }
        }
    )
}
