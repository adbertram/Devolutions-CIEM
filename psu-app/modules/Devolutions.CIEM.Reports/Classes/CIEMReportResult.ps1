class CIEMReportResult {
    [string]$ReportId
    [string]$Title
    [datetime]$GeneratedAt
    [string[]]$Columns
    [object[]]$Rows
    [string[]]$Visuals
    [hashtable]$Context

    CIEMReportResult() {}
}
