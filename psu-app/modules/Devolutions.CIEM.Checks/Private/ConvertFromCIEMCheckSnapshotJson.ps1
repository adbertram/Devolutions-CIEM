function ConvertFromCIEMCheckSnapshotJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SnapshotJson,

        [Parameter()]
        [string]$Context
    )

    $ErrorActionPreference = 'Stop'

    $snapshot = $SnapshotJson | ConvertFrom-Json -Depth 20
    foreach ($propertyName in @('id', 'provider', 'service', 'title', 'severity', 'description')) {
        if ([string]::IsNullOrWhiteSpace([string]$snapshot.$propertyName)) {
            throw "Invalid check snapshot for ${Context}: '$propertyName' is required."
        }
    }

    if ($null -eq $snapshot.remediation -or [string]::IsNullOrWhiteSpace([string]$snapshot.remediation.text)) {
        throw "Invalid check snapshot for ${Context}: 'remediation.text' is required."
    }

    [PSCustomObject]@{
        Id              = [string]$snapshot.id
        Provider        = [string]$snapshot.provider
        Service         = [string]$snapshot.service
        Title           = [string]$snapshot.title
        Description     = [string]$snapshot.description
        Risk            = [string]$snapshot.risk
        Severity        = [string]$snapshot.severity
        Remediation     = [PSCustomObject]@{
            Text = [string]$snapshot.remediation.text
            Url  = [string]$snapshot.remediation.url
        }
        RelatedUrl      = [string]$snapshot.relatedUrl
        CheckScript     = [string]$snapshot.checkScript
        ExecutionMode   = [string]$snapshot.executionMode
        ManualReason    = $snapshot.manualReason
        Evaluator       = $snapshot.evaluator
        EvaluatorConfig = $snapshot.evaluatorConfig
        DependsOn       = @($snapshot.dependsOn)
        DataNeeds       = if ($null -eq $snapshot.dataNeeds) { $null } else { @($snapshot.dataNeeds) }
        Disabled        = [bool]$snapshot.disabled
        Permissions     = $snapshot.permissions
    }
}
