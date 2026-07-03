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

        $executorCommand = Get-Command -Name $report.ExecutorName -CommandType Function -ErrorAction Stop

        $declaredParameters = @{}
        foreach ($parameterDefinition in @($report.Parameters)) {
            if (-not $parameterDefinition.PSObject.Properties['name']) {
                throw "CIEM report '$($report.Id)' contains an invalid parameter definition."
            }
            $declaredParameters[[string]$parameterDefinition.name] = $true
        }

        $executionParameters = @{}
        foreach ($parameterName in @($Parameter.Keys)) {
            if (-not $declaredParameters.ContainsKey([string]$parameterName)) {
                throw "CIEM report '$($report.Id)' does not declare parameter '$parameterName'."
            }
            if (-not $executorCommand.Parameters.ContainsKey([string]$parameterName)) {
                throw "CIEM report '$($report.Id)' executor '$($report.ExecutorName)' does not accept parameter '$parameterName'."
            }
            $executionParameters[[string]$parameterName] = $Parameter[$parameterName]
        }

        $execution = & $report.ExecutorName @executionParameters
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
