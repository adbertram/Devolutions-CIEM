function Remove-CIEMGraphEdge {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [int]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ByKind')]
        [string]$Kind,

        [Parameter(Mandatory, ParameterSetName = 'ByComputed')]
        [int]$Computed,

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
                if ($PSCmdlet.ShouldProcess("Id $Id", 'Remove graph edge')) {
                    Write-CIEMLog -Message "DELETE graph_edges WHERE id=$Id (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphEdge'
                    RemoveCIEMGraphEntity -Entity Edge -Filters @{ Id = $Id } -Connection $Connection
                }
            }
            'ByKind' {
                if ($PSCmdlet.ShouldProcess("Kind '$Kind'", 'Remove graph edges')) {
                    Write-CIEMLog -Message "DELETE graph_edges WHERE kind='$Kind' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphEdge'
                    RemoveCIEMGraphEntity -Entity Edge -Filters @{ Kind = $Kind } -Connection $Connection
                }
            }
            'ByComputed' {
                if ($PSCmdlet.ShouldProcess("Computed=$Computed", 'Remove graph edges')) {
                    Write-CIEMLog -Message "DELETE graph_edges WHERE computed=$Computed (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphEdge'
                    RemoveCIEMGraphEntity -Entity Edge -Filters @{ Computed = $Computed } -Connection $Connection
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all rows', 'Remove graph edges')) {
                    Write-CIEMLog -Message "DELETE graph_edges ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphEdge'
                    RemoveCIEMGraphEntity -Entity Edge -All -Connection $Connection
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess("Id $($obj.Id)", 'Remove graph edge')) {
                        Write-CIEMLog -Message "DELETE graph_edges WHERE id=$($obj.Id) (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-GraphEdge'
                        RemoveCIEMGraphEntity -Entity Edge -Filters @{ Id = $obj.Id } -Connection $Connection
                    }
                }
            }
        }
    }
}
