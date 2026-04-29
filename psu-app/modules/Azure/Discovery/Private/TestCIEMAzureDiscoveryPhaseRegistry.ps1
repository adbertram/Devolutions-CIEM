function TestCIEMAzureDiscoveryPhaseRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $ErrorActionPreference = 'Stop'

    if ($Config.Count -eq 0) {
        throw 'TestCIEMAzureDiscoveryPhaseRegistry: registry cannot be empty.'
    }

    $allowedFields = @('Order', 'Name', 'Scope', 'Executor', 'Query', 'FailureMode', 'DependsOn')
    $requiredFields = @('Order', 'Name', 'Scope', 'Executor', 'FailureMode', 'DependsOn')
    $allowedScopes = @('All', 'ARM', 'Entra')
    $allowedFailureModes = @('FailRun', 'RecordUnsupported')

    foreach ($phaseId in ($Config.Keys | Sort-Object)) {
        $phase = $Config[$phaseId]
        if ($phase -isnot [hashtable]) {
            throw "TestCIEMAzureDiscoveryPhaseRegistry: phase '$phaseId' must be a hashtable."
        }

        foreach ($fieldName in ($phase.Keys | Sort-Object)) {
            if ($fieldName -notin $allowedFields) {
                throw "TestCIEMAzureDiscoveryPhaseRegistry: phase '$phaseId' has unknown field '$fieldName'."
            }
        }

        foreach ($fieldName in $requiredFields) {
            if (-not $phase.ContainsKey($fieldName)) {
                throw "TestCIEMAzureDiscoveryPhaseRegistry: phase '$phaseId' is missing required field '$fieldName'."
            }
        }

        if ($phase.Order -isnot [int]) {
            throw "TestCIEMAzureDiscoveryPhaseRegistry: phase '$phaseId' Order must be an integer."
        }

        foreach ($scopeName in @($phase.Scope)) {
            if ($scopeName -notin $allowedScopes) {
                throw "TestCIEMAzureDiscoveryPhaseRegistry: phase '$phaseId' has invalid scope '$scopeName'."
            }
        }

        if ($phase.FailureMode -notin $allowedFailureModes) {
            throw "TestCIEMAzureDiscoveryPhaseRegistry: phase '$phaseId' has invalid failure mode '$($phase.FailureMode)'."
        }

        foreach ($dependencyName in @($phase.DependsOn)) {
            if (-not $Config.ContainsKey($dependencyName)) {
                throw "TestCIEMAzureDiscoveryPhaseRegistry: phase '$phaseId' has missing dependency '$dependencyName'."
            }
        }
    }

    $true
}
