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
        [PSObject[]]$InputObject
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                if ($PSCmdlet.ShouldProcess("Id $Id", 'Remove Azure resource relationship')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null
                }
            }
            'ByCombo' {
                if ($PSCmdlet.ShouldProcess("$SourceId -> $TargetId ($Relationship)", 'Remove Azure resource relationship')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships WHERE source_id = @source_id AND target_id = @target_id AND relationship = @relationship" -Parameters @{
                        source_id    = $SourceId
                        target_id    = $TargetId
                        relationship = $Relationship
                    } -AsNonQuery | Out-Null
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all rows', 'Remove Azure resource relationships')) {
                    Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships" -AsNonQuery | Out-Null
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess("Id $($obj.Id)", 'Remove Azure resource relationship')) {
                        Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships WHERE id = @id" -Parameters @{ id = $obj.Id } -AsNonQuery | Out-Null
                    }
                }
            }
        }
    }
}
