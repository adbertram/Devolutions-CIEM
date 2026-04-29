function Invoke-CIEMReport {
    [CmdletBinding(DefaultParameterSetName = 'ById')]
    [OutputType('CIEMReportResult')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$Id,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByInputObject')]
        [object]$InputObject,

        [Parameter()]
        [hashtable]$Parameter = @{}
    )

    process {
        $ErrorActionPreference = 'Stop'

        if ($PSCmdlet.ParameterSetName -eq 'ById') {
            $report = Get-CIEMReport -Id $Id
        }
        else {
            $report = $InputObject
        }

        foreach ($requiredReportProperty in @('Id', 'Title', 'ExecutorName', 'Columns', 'Visuals')) {
            if (-not $report.PSObject.Properties[$requiredReportProperty]) {
                throw "InputObject is missing required CIEM report property '$requiredReportProperty'."
            }
        }

        Get-Command -Name $report.ExecutorName -CommandType Function -ErrorAction Stop | Out-Null

        $execution = & $report.ExecutorName @Parameter
        foreach ($requiredProperty in @('Rows', 'Context')) {
            if (-not $execution.PSObject.Properties[$requiredProperty]) {
                throw "CIEM report '$($report.Id)' executor '$($report.ExecutorName)' did not return required property '$requiredProperty'."
            }
        }

        if ($null -eq $execution.Context -or $execution.Context -isnot [hashtable]) {
            throw "CIEM report '$($report.Id)' executor '$($report.ExecutorName)' returned an invalid Context payload."
        }

        foreach ($row in @($execution.Rows)) {
            foreach ($column in @($report.Columns)) {
                if (-not $row.PSObject.Properties[$column]) {
                    throw "CIEM report '$($report.Id)' row is missing configured column '$column'."
                }
            }
        }

        $result = [CIEMReportResult]::new()
        $result.ReportId = $report.Id
        $result.Title = $report.Title
        $result.GeneratedAt = [datetime]::UtcNow
        $result.Columns = $report.Columns
        $result.Rows = [object[]]@($execution.Rows)
        $result.Visuals = $report.Visuals
        $result.Context = $execution.Context
        $result
    }
}
