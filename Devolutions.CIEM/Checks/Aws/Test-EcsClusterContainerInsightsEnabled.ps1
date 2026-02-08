function Test-EcsClusterContainerInsightsEnabled {
    <#
    .SYNOPSIS
        ECS cluster has Container Insights enabled or enhanced

    .DESCRIPTION
        **ECS clusters** have CloudWatch **Container Insights** configured via the `containerInsights` setting, accepting `enabled` or `enhanced` values to emit cluster, service, task, and container telemetry.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: ecs_cluster_container_insights_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ecs_cluster_container_insights_enabled for reference.', 'N/A', 'ecs Resources')
}
