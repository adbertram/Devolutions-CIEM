function Get-CIEMAzureDiscoveryRun {
    [CmdletBinding()]
    [OutputType('CIEMAzureDiscoveryRun[]')]
    param(
        [Parameter()]
        [int]$Id,

        [Parameter()]
        [string]$Status,

        [Parameter()]
        [int]$Last
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @()
    $parameters = @{}

    if ($PSBoundParameters.ContainsKey('Id')) {
        $conditions += "id = @id"
        $parameters.id = $Id
    }
    if ($PSBoundParameters.ContainsKey('Status')) {
        $conditions += "status = @status"
        $parameters.status = $Status
    }

    $query = "SELECT * FROM azure_discovery_runs"
    if ($conditions.Count -gt 0) {
        $query += "`nWHERE " + ($conditions -join ' AND ')
    }
    if ($PSBoundParameters.ContainsKey('Last')) {
        $query += "`nORDER BY julianday(started_at) DESC, id DESC LIMIT @last"
        $parameters.last = $Last
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)

    @(foreach ($row in $rows) {
        $obj = [CIEMAzureDiscoveryRun]::new()
        $obj.Id = $row.id
        $obj.PsuJobId = $row.psu_job_id
        $obj.Scope = $row.scope
        $obj.Status = $row.status
        $obj.StartedAt = $row.started_at
        $obj.CompletedAt = $row.completed_at
        $obj.ArmTypeCount = $row.arm_type_count
        $obj.ArmRowCount = $row.arm_row_count
        $obj.EntraTypeCount = $row.entra_type_count
        $obj.EntraRowCount = $row.entra_row_count
        $obj.WarningCount = $row.warning_count
        $obj.ErrorMessage = $row.error_message
        $obj
    })
}
