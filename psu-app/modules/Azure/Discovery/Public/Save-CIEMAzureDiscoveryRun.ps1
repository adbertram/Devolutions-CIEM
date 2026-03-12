function Save-CIEMAzureDiscoveryRun {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation for bulk data')]
    [OutputType('CIEMAzureDiscoveryRun[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Scope,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Status,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$StartedAt,

        [Parameter(ParameterSetName = 'ByProperties')]
        [int]$PsuJobId,

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

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [Parameter()]
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                if ($obj.Id -gt 0) {
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

                    $sql = @"
UPDATE azure_discovery_runs
SET psu_job_id = @psu_job_id, scope = @scope, status = @status, started_at = @started_at,
    completed_at = @completed_at, arm_type_count = @arm_type_count, arm_row_count = @arm_row_count,
    entra_type_count = @entra_type_count, entra_row_count = @entra_row_count,
    warning_count = @warning_count, error_message = @error_message
WHERE id = @id
"@
                } else {
                    $parameters = @{
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

                    $sql = @"
INSERT INTO azure_discovery_runs (psu_job_id, scope, status, started_at, completed_at, arm_type_count, arm_row_count, entra_type_count, entra_row_count, warning_count, error_message)
VALUES (@psu_job_id, @scope, @status, @started_at, @completed_at, @arm_type_count, @arm_row_count, @entra_type_count, @entra_row_count, @warning_count, @error_message)
"@
                }

                if ($Connection) {
                    Invoke-PSUSQLiteQuery -Connection $Connection -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
                } else {
                    Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
                }
            }
            return
        }

        $parameters = @{
            psu_job_id       = $PsuJobId
            scope            = $Scope
            status           = $Status
            started_at       = $StartedAt
            completed_at     = $CompletedAt
            arm_type_count   = $ArmTypeCount
            arm_row_count    = $ArmRowCount
            entra_type_count = $EntraTypeCount
            entra_row_count  = $EntraRowCount
            warning_count    = $WarningCount
            error_message    = $ErrorMessage
        }

        $sql = @"
INSERT INTO azure_discovery_runs (psu_job_id, scope, status, started_at, completed_at, arm_type_count, arm_row_count, entra_type_count, entra_row_count, warning_count, error_message)
VALUES (@psu_job_id, @scope, @status, @started_at, @completed_at, @arm_type_count, @arm_row_count, @entra_type_count, @entra_row_count, @warning_count, @error_message)
"@

        if ($Connection) {
            Invoke-PSUSQLiteQuery -Connection $Connection -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
        } else {
            Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
        }
    }
}
