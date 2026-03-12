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
        [PSObject[]]$InputObject
    )
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'InputObject' {
                foreach ($item in $InputObject) {
                    if ($PSCmdlet.ShouldProcess($item.Id, 'Remove Azure Entra resource')) {
                        Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources WHERE id = @id" -Parameters @{ id = $item.Id } -AsNonQuery | Out-Null
                    }
                }
            }
            'ByType' {
                if ($PSCmdlet.ShouldProcess("type '$Type'", 'Remove all Azure Entra resources')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources WHERE type = @type" -Parameters @{ type = $Type } -AsNonQuery | Out-Null
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all records', 'Remove all Azure Entra resources')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources" -AsNonQuery | Out-Null
                }
            }
            default {
                if ($PSCmdlet.ShouldProcess($Id, 'Remove Azure Entra resource')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null
                }
            }
        }
    }
}
