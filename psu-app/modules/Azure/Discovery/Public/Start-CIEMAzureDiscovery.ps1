function Start-CIEMAzureDiscovery {
    [CmdletBinding()]
    [OutputType('CIEMAzureDiscoveryRun')]
    param(
        [Parameter()]
        [ValidateSet('All', 'ARM', 'Entra')]
        [string]$Scope = 'All'
    )
    throw 'Start-CIEMAzureDiscovery: Not implemented — Phase 2'
}
