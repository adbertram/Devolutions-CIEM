function Remove-CIEMAzureEffectiveRoleAssignment {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [int]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ByPrincipalId')]
        [string]$PrincipalId,

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
                if ($PSCmdlet.ShouldProcess("Id $Id", 'Remove Azure effective role assignment')) {
                    Write-CIEMLog -Message "DELETE azure_effective_role_assignments WHERE id=$Id (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EffectiveRoleAssignment'
                    RemoveCIEMAzureEntity -Entity 'EffectiveRoleAssignment' -Filters @{ Id = $Id } -Connection $Connection
                }
            }
            'ByPrincipalId' {
                if ($PSCmdlet.ShouldProcess("PrincipalId $PrincipalId", 'Remove Azure effective role assignments')) {
                    Write-CIEMLog -Message "DELETE azure_effective_role_assignments WHERE principal_id='$PrincipalId' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EffectiveRoleAssignment'
                    RemoveCIEMAzureEntity -Entity 'EffectiveRoleAssignment' -Filters @{ PrincipalId = $PrincipalId } -Connection $Connection
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all rows', 'Remove Azure effective role assignments')) {
                    Write-CIEMLog -Message "DELETE azure_effective_role_assignments ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EffectiveRoleAssignment'
                    RemoveCIEMAzureEntity -Entity 'EffectiveRoleAssignment' -All -Connection $Connection
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess("Id $($obj.Id)", 'Remove Azure effective role assignment')) {
                        Write-CIEMLog -Message "DELETE azure_effective_role_assignments WHERE id=$($obj.Id) (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EffectiveRoleAssignment'
                        RemoveCIEMAzureEntity -Entity 'EffectiveRoleAssignment' -Filters @{ Id = $obj.Id } -Connection $Connection
                    }
                }
            }
        }
    }
}
