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
                    $q = "DELETE FROM azure_arm_resources WHERE id = @id"
                    $p = @{ id = $Id }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
            'ByType' {
                if ($PSCmdlet.ShouldProcess("Type=$Type", 'Remove ARM resources')) {
                    Write-CIEMLog -Message "DELETE azure_arm_resources WHERE type='$Type' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ArmResource'
                    $q = "DELETE FROM azure_arm_resources WHERE type = @type"
                    $p = @{ type = $Type }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all records', 'Remove ARM resources')) {
                    Write-CIEMLog -Message "DELETE azure_arm_resources ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ArmResource'
                    $q = "DELETE FROM azure_arm_resources"
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -AsNonQuery | Out-Null }
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess($obj.Id, 'Remove ARM resource')) {
                        Write-CIEMLog -Message "DELETE azure_arm_resources WHERE id='$($obj.Id)' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ArmResource'
                        $q = "DELETE FROM azure_arm_resources WHERE id = @id"
                        $p = @{ id = $obj.Id }
                        if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                        else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    }
                }
            }
        }
    }
}