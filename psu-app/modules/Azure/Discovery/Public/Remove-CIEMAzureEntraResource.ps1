function Remove-CIEMAzureEntraResource {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByType')]
        [string]$Type,
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
            'InputObject' {
                foreach ($item in $InputObject) {
                    if ($PSCmdlet.ShouldProcess($item.Id, 'Remove Azure Entra resource')) {
                        Write-CIEMLog -Message "DELETE azure_entra_resources WHERE id='$($item.Id)' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EntraResource'
                        RemoveCIEMAzureEntity -Entity 'EntraResource' -Filters @{ Id = $item.Id } -Connection $Connection
                    }
                }
            }
            'ByType' {
                if ($PSCmdlet.ShouldProcess("type '$Type'", 'Remove all Azure Entra resources')) {
                    Write-CIEMLog -Message "DELETE azure_entra_resources WHERE type='$Type' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EntraResource'
                    RemoveCIEMAzureEntity -Entity 'EntraResource' -Filters @{ Type = $Type } -Connection $Connection
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all records', 'Remove all Azure Entra resources')) {
                    Write-CIEMLog -Message "DELETE azure_entra_resources ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EntraResource'
                    RemoveCIEMAzureEntity -Entity 'EntraResource' -All -Connection $Connection
                }
            }
            default {
                if ($PSCmdlet.ShouldProcess($Id, 'Remove Azure Entra resource')) {
                    Write-CIEMLog -Message "DELETE azure_entra_resources WHERE id='$Id' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EntraResource'
                    RemoveCIEMAzureEntity -Entity 'EntraResource' -Filters @{ Id = $Id } -Connection $Connection
                }
            }
        }
    }
}
