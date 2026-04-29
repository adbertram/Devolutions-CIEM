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
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    process {
        $ErrorActionPreference = 'Stop'

        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                if ($PSCmdlet.ShouldProcess($Id, 'Remove graph node')) {
                    Write-CIEMLog -Message "DELETE graph_nodes WHERE id='$Id' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphNode'
                    RemoveCIEMGraphEntity -Entity Node -Filters @{ Id = $Id } -Connection $Connection
                }
            }
            'ByKind' {
                if ($PSCmdlet.ShouldProcess("Kind=$Kind", 'Remove graph nodes')) {
                    Write-CIEMLog -Message "DELETE graph_nodes WHERE kind='$Kind' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphNode'
                    RemoveCIEMGraphEntity -Entity Node -Filters @{ Kind = $Kind } -Connection $Connection
                }
            }
            'ByProvider' {
                if ($PSCmdlet.ShouldProcess("Provider=$Provider", 'Remove graph nodes')) {
                    Write-CIEMLog -Message "DELETE graph_nodes WHERE provider='$Provider' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphNode'
                    RemoveCIEMGraphEntity -Entity Node -Filters @{ Provider = $Provider } -Connection $Connection
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all records', 'Remove graph nodes')) {
                    Write-CIEMLog -Message "DELETE graph_nodes ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphNode'
                    RemoveCIEMGraphEntity -Entity Node -All -Connection $Connection
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess($obj.Id, 'Remove graph node')) {
                        Write-CIEMLog -Message "DELETE graph_nodes WHERE id='$($obj.Id)' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphNode'
                        RemoveCIEMGraphEntity -Entity Node -Filters @{ Id = $obj.Id } -Connection $Connection
                    }
                }
            }
        }
    }
}
