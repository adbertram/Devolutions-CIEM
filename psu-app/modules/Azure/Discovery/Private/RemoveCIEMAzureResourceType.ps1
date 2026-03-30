function RemoveCIEMAzureResourceType {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ByType')]
    param(
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
                    if ($PSCmdlet.ShouldProcess($item.Type, 'Remove Azure resource type')) {
                        Write-CIEMLog -Message "DELETE azure_resource_types WHERE type='$($item.Type)' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ResourceType'
                        Invoke-CIEMQuery -Query "DELETE FROM azure_resource_types WHERE type = @type" -Parameters @{ type = $item.Type } -AsNonQuery | Out-Null
                    }
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all records', 'Remove all Azure resource types')) {
                    Write-CIEMLog -Message "DELETE azure_resource_types ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ResourceType'
                    Invoke-CIEMQuery -Query "DELETE FROM azure_resource_types" -AsNonQuery | Out-Null
                }
            }
            default {
                if ($PSCmdlet.ShouldProcess($Type, 'Remove Azure resource type')) {
                    Write-CIEMLog -Message "DELETE azure_resource_types WHERE type='$Type' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ResourceType'
                    Invoke-CIEMQuery -Query "DELETE FROM azure_resource_types WHERE type = @type" -Parameters @{ type = $Type } -AsNonQuery | Out-Null
                }
            }
        }
    }
}
