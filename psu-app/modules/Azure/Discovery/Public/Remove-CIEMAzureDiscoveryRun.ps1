function Remove-CIEMAzureDiscoveryRun {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [int]$Id,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                if ($PSCmdlet.ShouldProcess($Id, 'Remove Azure discovery run')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess($obj.Id, 'Remove Azure discovery run')) {
                        Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs WHERE id = @id" -Parameters @{ id = $obj.Id } -AsNonQuery | Out-Null
                    }
                }
            }
        }
    }
}
