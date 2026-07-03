class CIEMReport {
    [string]$Id
    [string]$Provider
    [string]$Category
    [string]$Title
    [string]$Description
    [string]$ExecutorName
    [string[]]$Columns
    [string[]]$Visuals
    [object[]]$Parameters
    [object[]]$StatusSummary
    [string]$EmptyState

    CIEMReport() {}
}
