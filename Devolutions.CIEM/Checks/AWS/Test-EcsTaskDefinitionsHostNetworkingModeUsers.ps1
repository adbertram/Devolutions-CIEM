function Test-EcsTaskDefinitionsHostNetworkingModeUsers {
    <#
    .SYNOPSIS
        Amazon ECS task definition does not use host network mode, or non-privileged containers specify a non-root user

    .DESCRIPTION
        **Amazon ECS task definitions** in `host` network mode are assessed for containers where `privileged=false` and the container `user` is `root` or unset.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: ecs_task_definitions_host_networking_mode_users

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ecs_task_definitions_host_networking_mode_users for reference.', 'N/A', 'ecs Resources')
}
