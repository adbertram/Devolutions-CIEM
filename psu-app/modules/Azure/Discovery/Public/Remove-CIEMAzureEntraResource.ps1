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
        [object]$Connection
    )
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'InputObject' {
                foreach ($item in $InputObject) {
                    if ($PSCmdlet.ShouldProcess($item.Id, 'Remove Azure Entra resource')) {
                        Write-CIEMLog -Message "DELETE azure_entra_resources WHERE id='$($item.Id)' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EntraResource'
                        $q = "DELETE FROM azure_entra_resources WHERE id = @id"
                        $p = @{ id = $item.Id }
                        if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                        else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    }
                }
            }
            'ByType' {
                if ($PSCmdlet.ShouldProcess("type '$Type'", 'Remove all Azure Entra resources')) {
                    Write-CIEMLog -Message "DELETE azure_entra_resources WHERE type='$Type' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EntraResource'
                    $q = "DELETE FROM azure_entra_resources WHERE type = @type"
                    $p = @{ type = $Type }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all records', 'Remove all Azure Entra resources')) {
                    Write-CIEMLog -Message "DELETE azure_entra_resources ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EntraResource'
                    $q = "DELETE FROM azure_entra_resources"
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -AsNonQuery | Out-Null }
                }
            }
            default {
                if ($PSCmdlet.ShouldProcess($Id, 'Remove Azure Entra resource')) {
                    Write-CIEMLog -Message "DELETE azure_entra_resources WHERE id='$Id' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EntraResource'
                    $q = "DELETE FROM azure_entra_resources WHERE id = @id"
                    $p = @{ id = $Id }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
        }
    }
}
