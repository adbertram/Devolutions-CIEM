class CIEMServiceCache {
    [string]$ServiceName
    [bool]$Success
    [timespan]$Duration
    [string[]]$Errors
    [string[]]$Warnings
    [string[]]$Output
    [hashtable]$CacheData
}
