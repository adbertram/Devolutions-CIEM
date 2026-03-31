function Remove-CIEMGraphNode {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ByKind')]
        [string]$Kind,

        [Parameter(Mandatory, ParameterSetName = 'ByProvider')]
        [string]$Provider,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [Parameter()]
        [object]$Connection
    )

    process {
        $ErrorActionPreference = 'Stop'

        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                if ($PSCmdlet.ShouldProcess($Id, 'Remove graph node')) {
                    Write-CIEMLog -Message "DELETE graph_nodes WHERE id='$Id' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphNode'
                    $q = "DELETE FROM graph_nodes WHERE id = @id"
                    $p = @{ id = $Id }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
            'ByKind' {
                if ($PSCmdlet.ShouldProcess("Kind=$Kind", 'Remove graph nodes')) {
                    Write-CIEMLog -Message "DELETE graph_nodes WHERE kind='$Kind' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphNode'
                    $q = "DELETE FROM graph_nodes WHERE kind = @kind"
                    $p = @{ kind = $Kind }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
            'ByProvider' {
                if ($PSCmdlet.ShouldProcess("Provider=$Provider", 'Remove graph nodes')) {
                    Write-CIEMLog -Message "DELETE graph_nodes WHERE provider='$Provider' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphNode'
                    $q = "DELETE FROM graph_nodes WHERE provider = @provider"
                    $p = @{ provider = $Provider }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all records', 'Remove graph nodes')) {
                    Write-CIEMLog -Message "DELETE graph_nodes ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphNode'
                    $q = "DELETE FROM graph_nodes"
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -AsNonQuery | Out-Null }
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess($obj.Id, 'Remove graph node')) {
                        Write-CIEMLog -Message "DELETE graph_nodes WHERE id='$($obj.Id)' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphNode'
                        $q = "DELETE FROM graph_nodes WHERE id = @id"
                        $p = @{ id = $obj.Id }
                        if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                        else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    }
                }
            }
        }
    }
}
