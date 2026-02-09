function Test-EcsTaskDefinitionsLoggingBlockMode {
    <#
    .SYNOPSIS
        ECS task definition has container logging in non-blocking mode

    .DESCRIPTION
        **ECS task definition containers** use **non-blocking logging mode** via the `logConfiguration.mode` option on the latest active revision

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

    # TODO: Implement check logic based on Prowler check: ecs_task_definitions_logging_block_mode

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ecs_task_definitions_logging_block_mode for reference.', 'N/A', 'ecs Resources')
}
