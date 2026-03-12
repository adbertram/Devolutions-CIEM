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
                        Invoke-CIEMQuery -Query "DELETE FROM azure_resource_types WHERE type = @type" -Parameters @{ type = $item.Type } -AsNonQuery | Out-Null
                    }
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all records', 'Remove all Azure resource types')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_resource_types" -AsNonQuery | Out-Null
                }
            }
            default {
                if ($PSCmdlet.ShouldProcess($Type, 'Remove Azure resource type')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_resource_types WHERE type = @type" -Parameters @{ type = $Type } -AsNonQuery | Out-Null
                }
            }
        }
    }
}
