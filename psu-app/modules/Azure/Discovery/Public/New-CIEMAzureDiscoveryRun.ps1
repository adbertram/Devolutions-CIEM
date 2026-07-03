function NewCIEMAzureDiscoveryRunCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Connection,

        [Parameter(Mandatory)]
        [string]$Scope,

        [Parameter(Mandatory)]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$StartedAt,

        [Parameter()]
        [int]$PsuJobId,

        [Parameter()]
        [string]$CompletedAt,

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
        [string]$ErrorMessage
    )

    $ErrorActionPreference = 'Stop'

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

    Invoke-PSUSQLiteQuery -Connection $Connection -Query @"
INSERT INTO azure_discovery_runs (psu_job_id, scope, status, started_at, completed_at, arm_type_count, arm_row_count, entra_type_count, entra_row_count, warning_count, error_message)
VALUES (@psu_job_id, @scope, @status, @started_at, @completed_at, @arm_type_count, @arm_row_count, @entra_type_count, @entra_row_count, @warning_count, @error_message)
"@ -Parameters $parameters -AsNonQuery | Out-Null

    $idRow = Invoke-PSUSQLiteQuery -Connection $Connection -Query 'SELECT last_insert_rowid() as id'
    $run = [CIEMAzureDiscoveryRun]::new()
    $run.Id = [int]$idRow.id
    $run.PsuJobId = $PsuJobId
    $run.Scope = $Scope
    $run.Status = $Status
    $run.StartedAt = $StartedAt
    $run.CompletedAt = $CompletedAt
    $run.ArmTypeCount = $ArmTypeCount
    $run.ArmRowCount = $ArmRowCount
    $run.EntraTypeCount = $EntraTypeCount
    $run.EntraRowCount = $EntraRowCount
    $run.WarningCount = $WarningCount
    $run.ErrorMessage = $ErrorMessage
    $run
}

function New-CIEMAzureDiscoveryRun {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a data record in database')]
    [OutputType('CIEMAzureDiscoveryRun')]
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
        [PSObject[]]$InputObject
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                New-CIEMAzureDiscoveryRun `
                    -Scope $obj.Scope `
                    -Status $obj.Status `
                    -StartedAt $obj.StartedAt `
                    -PsuJobId $obj.PsuJobId `
                    -CompletedAt $obj.CompletedAt `
                    -ArmTypeCount $obj.ArmTypeCount `
                    -ArmRowCount $obj.ArmRowCount `
                    -EntraTypeCount $obj.EntraTypeCount `
                    -EntraRowCount $obj.EntraRowCount `
                    -WarningCount $obj.WarningCount `
                    -ErrorMessage $obj.ErrorMessage
            }
            return
        }

        # INSERT and last_insert_rowid() MUST share the same connection —
        # last_insert_rowid() is per-connection in SQLite and returns 0 on a new connection.
        $conn = Open-PSUSQLiteConnection -Database (Get-CIEMDatabasePath)
        try {
            Invoke-PSUSQLiteQuery -Connection $conn -Query 'PRAGMA foreign_keys=ON' -AsNonQuery | Out-Null
            $run = NewCIEMAzureDiscoveryRunCore `
                -Connection $conn `
                -Scope $Scope `
                -Status $Status `
                -StartedAt $StartedAt `
                -PsuJobId $PsuJobId `
                -CompletedAt $CompletedAt `
                -ArmTypeCount $ArmTypeCount `
                -ArmRowCount $ArmRowCount `
                -EntraTypeCount $EntraTypeCount `
                -EntraRowCount $EntraRowCount `
                -WarningCount $WarningCount `
                -ErrorMessage $ErrorMessage
        }
        finally {
            $conn.Dispose()
        }
        Get-CIEMAzureDiscoveryRun -Id $run.Id
    }
}
