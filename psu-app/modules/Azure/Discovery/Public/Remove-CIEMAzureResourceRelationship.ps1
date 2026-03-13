function Remove-CIEMAzureResourceRelationship {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [int]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ByCombo')]
        [string]$SourceId,

        [Parameter(Mandatory, ParameterSetName = 'ByCombo')]
        [string]$TargetId,

        [Parameter(Mandatory, ParameterSetName = 'ByCombo')]
        [string]$Relationship,

        [Parameter(Mandatory, ParameterSetName = 'All')]
        [switch]$All,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [Parameter()]
        [object]$Connection
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                if ($PSCmdlet.ShouldProcess("Id $Id", 'Remove Azure resource relationship')) {
                    $q = "DELETE FROM azure_resource_relationships WHERE id = @id"
                    $p = @{ id = $Id }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
            'ByCombo' {
                if ($PSCmdlet.ShouldProcess("$SourceId -> $TargetId ($Relationship)", 'Remove Azure resource relationship')) {
                    $q = "DELETE FROM azure_resource_relationships WHERE source_id = @source_id AND target_id = @target_id AND relationship = @relationship"
                    $p = @{
                        source_id    = $SourceId
                        target_id    = $TargetId
                        relationship = $Relationship
                    }
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all rows', 'Remove Azure resource relationships')) {
                    $q = "DELETE FROM azure_resource_relationships"
                    if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -AsNonQuery | Out-Null }
                    else { Invoke-CIEMQuery -Query $q -AsNonQuery | Out-Null }
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess("Id $($obj.Id)", 'Remove Azure resource relationship')) {
                        $q = "DELETE FROM azure_resource_relationships WHERE id = @id"
                        $p = @{ id = $obj.Id }
                        if ($Connection) { Invoke-PSUSQLiteQuery -Connection $Connection -Query $q -Parameters $p -AsNonQuery | Out-Null }
                        else { Invoke-CIEMQuery -Query $q -Parameters $p -AsNonQuery | Out-Null }
                    }
                }
            }
        }
    }
}
