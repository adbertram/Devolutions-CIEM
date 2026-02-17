function Test-EcsTaskDefinitionsContainersReadonlyAccess {
    <#
    .SYNOPSIS
        ECS task definition has all containers with read-only root filesystems

    .DESCRIPTION
        Amazon ECS task definitions specify whether container root filesystems are **read-only** via `readonlyRootFilesystem`. Containers where this setting is absent or set to `false` effectively have write access to the root filesystem.

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

    # TODO: Implement check logic based on Prowler check: ecs_task_definitions_containers_readonly_access

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ecs_task_definitions_containers_readonly_access for reference.', 'N/A', 'ecs Resources')
}
