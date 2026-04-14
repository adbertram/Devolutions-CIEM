function Update-CIEMAzureDiscoveryRun {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureDiscoveryRun[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [int]$Id,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$PsuJobId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Scope,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Status,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$StartedAt,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CompletedAt,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$ArmTypeCount,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$ArmRowCount,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$EntraTypeCount,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$EntraRowCount,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$WarningCount,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ErrorMessage,

        [Parameter(ParameterSetName = 'ByProperties')]
        [switch]$PassThru,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $parameters = @{
                    id               = $obj.Id
                    psu_job_id       = $obj.PsuJobId
                    scope            = $obj.Scope
                    status           = $obj.Status
                    started_at       = $obj.StartedAt
                    completed_at     = $obj.CompletedAt
                    arm_type_count   = $obj.ArmTypeCount
                    arm_row_count    = $obj.ArmRowCount
                    entra_type_count = $obj.EntraTypeCount
                    entra_row_count  = $obj.EntraRowCount
                    warning_count    = $obj.WarningCount
                    error_message    = $obj.ErrorMessage
                }

                Invoke-CIEMQuery -Query @"
UPDATE azure_discovery_runs
SET psu_job_id = @psu_job_id, scope = @scope, status = @status, started_at = @started_at,
    completed_at = @completed_at, arm_type_count = @arm_type_count, arm_row_count = @arm_row_count,
    entra_type_count = @entra_type_count, entra_row_count = @entra_row_count,
    warning_count = @warning_count, error_message = @error_message
WHERE id = @id
"@ -Parameters $parameters -AsNonQuery | Out-Null
            }
            return
        }

        $columnMap = @{
            PsuJobId       = 'psu_job_id'
            Scope          = 'scope'
            Status         = 'status'
            StartedAt      = 'started_at'
            CompletedAt    = 'completed_at'
            ArmTypeCount   = 'arm_type_count'
            ArmRowCount    = 'arm_row_count'
            EntraTypeCount = 'entra_type_count'
            EntraRowCount  = 'entra_row_count'
            WarningCount   = 'warning_count'
            ErrorMessage   = 'error_message'
        }

        $setClauses = @()
        $parameters = @{ id = $Id }

        foreach ($paramName in $columnMap.Keys) {
            if ($PSBoundParameters.ContainsKey($paramName)) {
                $col = $columnMap[$paramName]
                $setClauses += "$col = @$col"
                $parameters[$col] = $PSBoundParameters[$paramName]
            }
        }

        if ($setClauses.Count -eq 0) {
            if ($PassThru) { Get-CIEMAzureDiscoveryRun -Id $Id }
            return
        }

        $sql = "UPDATE azure_discovery_runs SET " + ($setClauses -join ', ') + " WHERE id = @id"
        Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null

        if ($PassThru) {
            Get-CIEMAzureDiscoveryRun -Id $Id
        }
    }
}