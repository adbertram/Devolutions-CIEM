function GetCIEMAzureDiscoveryPhaseConfig {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('All', 'ARM', 'Entra')]
        [string]$Scope = 'All',

        [Parameter()]
        [hashtable]$Config
    )

    $ErrorActionPreference = 'Stop'

    if (-not $Config) {
        if (-not $script:CIEMAzureDiscoveryPhasesConfig) {
            throw 'GetCIEMAzureDiscoveryPhaseConfig: $script:CIEMAzureDiscoveryPhasesConfig is not loaded. Module init failed.'
        }
        $Config = $script:CIEMAzureDiscoveryPhasesConfig
    }

    TestCIEMAzureDiscoveryPhaseRegistry -Config $Config | Out-Null

    @(
        foreach ($phaseId in $Config.Keys) {
            $phase = $Config[$phaseId]
            if ($Scope -notin @($phase.Scope)) {
                continue
            }

            [pscustomobject]@{
                Id = $phaseId
                Order = $phase.Order
                Name = $phase.Name
                Scope = @($phase.Scope)
                Executor = $phase.Executor
                Query = if ($phase.ContainsKey('Query')) { $phase.Query } else { $null }
                FailureMode = $phase.FailureMode
                DependsOn = @($phase.DependsOn)
            }
        }
    ) | Sort-Object Order
}
