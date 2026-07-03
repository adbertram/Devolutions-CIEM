function Get-CIEMReport {
    [CmdletBinding()]
    [OutputType('CIEMReport[]')]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$Category
    )

    $ErrorActionPreference = 'Stop'

    $entries = @(GetCIEMReportRegistry)

    $reports = @(
        foreach ($entry in $entries) {
            $report = [CIEMReport]::new()
            $report.Id = $entry.id
            $report.Provider = $entry.provider
            $report.Category = $entry.category
            $report.Title = $entry.title
            $report.Description = $entry.description
            $report.ExecutorName = $entry.executorName
            $report.Columns = [string[]]@($entry.columns)
            $report.Visuals = [string[]]@($entry.visuals)
            $report.Parameters = [object[]]@($entry.parameters)
            $report.StatusSummary = [object[]]@($entry.statusSummary)
            $report.EmptyState = [string]$entry.emptyState
            $report
        }
    )

    if ($PSBoundParameters.ContainsKey('Id')) {
        $reports = @($reports | Where-Object { $_.Id -eq $Id })
        if ($reports.Count -eq 0) {
            throw "CIEM report '$Id' was not found."
        }
    }

    if ($PSBoundParameters.ContainsKey('Provider')) {
        $reports = @($reports | Where-Object { $_.Provider -eq $Provider })
    }

    if ($PSBoundParameters.ContainsKey('Category')) {
        $reports = @($reports | Where-Object { $_.Category -eq $Category })
    }

    $reports
}
