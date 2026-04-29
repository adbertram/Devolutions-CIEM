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
        [PSObject[]]$InputObject,

        [Parameter()]
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    process {
        $ErrorActionPreference = 'Stop'
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                if ($PSCmdlet.ShouldProcess($Id, 'Remove ARM resource')) {
                    Write-CIEMLog -Message "DELETE azure_arm_resources WHERE id='$Id' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ArmResource'
                    RemoveCIEMAzureEntity -Entity 'ArmResource' -Filters @{ Id = $Id } -Connection $Connection
                }
            }
            'ByType' {
                if ($PSCmdlet.ShouldProcess("Type=$Type", 'Remove ARM resources')) {
                    Write-CIEMLog -Message "DELETE azure_arm_resources WHERE type='$Type' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ArmResource'
                    RemoveCIEMAzureEntity -Entity 'ArmResource' -Filters @{ Type = $Type } -Connection $Connection
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all records', 'Remove ARM resources')) {
                    Write-CIEMLog -Message "DELETE azure_arm_resources ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ArmResource'
                    RemoveCIEMAzureEntity -Entity 'ArmResource' -All -Connection $Connection
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess($obj.Id, 'Remove ARM resource')) {
                        Write-CIEMLog -Message "DELETE azure_arm_resources WHERE id='$($obj.Id)' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ArmResource'
                        RemoveCIEMAzureEntity -Entity 'ArmResource' -Filters @{ Id = $obj.Id } -Connection $Connection
                    }
                }
            }
        }
    }
}
