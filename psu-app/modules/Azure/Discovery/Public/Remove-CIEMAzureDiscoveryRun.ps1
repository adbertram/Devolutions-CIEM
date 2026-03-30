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
                    Write-CIEMLog -Message "DELETE azure_discovery_runs WHERE id=$Id (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-DiscoveryRun'
                    Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess($obj.Id, 'Remove Azure discovery run')) {
                        Write-CIEMLog -Message "DELETE azure_discovery_runs WHERE id=$($obj.Id) (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-DiscoveryRun'
                        Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs WHERE id = @id" -Parameters @{ id = $obj.Id } -AsNonQuery | Out-Null
                    }
                }
            }
        }
    }
}
