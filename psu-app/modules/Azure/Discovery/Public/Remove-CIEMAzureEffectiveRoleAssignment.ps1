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
        [object]$Connection
    )

    process {
        $ErrorActionPreference = 'Stop'
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                if ($PSCmdlet.ShouldProcess("Id $Id", 'Remove Azure effective role assignment')) {
                    Write-CIEMLog -Message "DELETE azure_effective_role_assignments WHERE id=$Id (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EffectiveRoleAssignment'
                    $q = "DELETE FROM azure_effective_role_assignments WHERE id = @id"
                    $p = @{ id = $Id }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
            'ByPrincipalId' {
                if ($PSCmdlet.ShouldProcess("PrincipalId $PrincipalId", 'Remove Azure effective role assignments')) {
                    Write-CIEMLog -Message "DELETE azure_effective_role_assignments WHERE principal_id='$PrincipalId' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EffectiveRoleAssignment'
                    $q = "DELETE FROM azure_effective_role_assignments WHERE principal_id = @principal_id"
                    $p = @{ principal_id = $PrincipalId }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all rows', 'Remove Azure effective role assignments')) {
                    Write-CIEMLog -Message "DELETE azure_effective_role_assignments ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EffectiveRoleAssignment'
                    $q = "DELETE FROM azure_effective_role_assignments"
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -AsNonQuery | Out-Null }
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess("Id $($obj.Id)", 'Remove Azure effective role assignment')) {
                        Write-CIEMLog -Message "DELETE azure_effective_role_assignments WHERE id=$($obj.Id) (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-EffectiveRoleAssignment'
                        $q = "DELETE FROM azure_effective_role_assignments WHERE id = @id"
                        $p = @{ id = $obj.Id }
                        if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                        else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    }
                }
            }
        }
    }
}
