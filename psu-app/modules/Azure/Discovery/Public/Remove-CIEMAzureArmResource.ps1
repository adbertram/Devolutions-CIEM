function Remove-CIEMAzureArmResource {
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
            'ById' {
                if ($PSCmdlet.ShouldProcess($Id, 'Remove ARM resource')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null
                }
            }
            'ByType' {
                if ($PSCmdlet.ShouldProcess("Type=$Type", 'Remove ARM resources')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources WHERE type = @type" -Parameters @{ type = $Type } -AsNonQuery | Out-Null
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all records', 'Remove ARM resources')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources" -AsNonQuery | Out-Null
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess($obj.Id, 'Remove ARM resource')) {
                        Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources WHERE id = @id" -Parameters @{ id = $obj.Id } -AsNonQuery | Out-Null
                    }
                }
            }
        }
    }
}
