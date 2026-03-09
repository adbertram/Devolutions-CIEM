function Update-CIEMIdentityGraph {
    <#
    .SYNOPSIS
        Builds the CIEM identity graph from existing collected data in SQLite.
    .DESCRIPTION
        Reads previously collected Entra ID and IAM data from SQLite (populated by
        New-CIEMIdentityScanRun or New-CIEMScanRun) and builds the identity
        relationship graph in-memory. Does NOT collect data from Azure APIs.

        Use New-CIEMIdentityScanRun to collect fresh identity data before calling
        this function.
    .PARAMETER Provider
        Cloud provider to build the graph for. Defaults to 'Azure'.
    .OUTPUTS
        [PSCustomObject] Exported graph (serialized CIEMGraph) suitable for PSU cache
        storage or passing to graph query functions.
    .EXAMPLE
        $graph = Update-CIEMIdentityGraph
        # Builds graph from existing SQLite data

    .EXAMPLE
        New-CIEMIdentityScanRun -Provider 'Azure'
        $graph = Update-CIEMIdentityGraph
        # Collect fresh data, then build graph
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$Provider = 'Azure'
    )

    $ErrorActionPreference = 'Stop'

    $progressActivity = "Building Identity Graph ($Provider)"

    Write-CIEMLog -Message "Update-CIEMIdentityGraph called: Provider=$Provider" -Severity INFO -Component 'IdentityGraph'

    # Read from SQLite (populated by New-CIEMIdentityScanRun or New-CIEMScanRun)
    Write-Progress -Activity $progressActivity -Status 'Reading collected data from database...' -PercentComplete 0
    $collected = Get-CIEMCollectedData -ProviderName $Provider
    if (-not $collected) {
        Write-Progress -Activity $progressActivity -Completed
        throw "No collected identity data for provider '$Provider'. Run New-CIEMIdentityScanRun first."
    }

    # Build graph in-memory
    Write-Progress -Activity $progressActivity -Status 'Building identity relationship graph...' -CurrentOperation 'Resolving nodes and edges' -PercentComplete 20
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $graph = New-CIEMGraph -EntraData $collected.EntraData -IAMData $collected.IAMData -TenantId $collected.TenantId
    $sw.Stop()
    Write-CIEMLog -Message "Graph built in $([math]::Round($sw.Elapsed.TotalSeconds, 2))s: $($graph.Nodes.Count) nodes, $($graph.Edges.Count) edges" -Severity INFO -Component 'IdentityGraph'

    # Persist identity-to-resource access mappings
    Write-Progress -Activity $progressActivity -Status 'Computing resource access mappings...' -CurrentOperation "$($graph.Nodes.Count) nodes, $($graph.Edges.Count) edges" -PercentComplete 60
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Save-ComputedResourceAccess -Graph $graph -ProviderId $Provider.ToLower()
    $sw.Stop()
    Write-CIEMLog -Message "Identity-resource access persisted in $([math]::Round($sw.Elapsed.TotalSeconds, 2))s" -Severity INFO -Component 'IdentityGraph'

    Write-Progress -Activity $progressActivity -Completed
    Export-CIEMGraph -Graph $graph
}
