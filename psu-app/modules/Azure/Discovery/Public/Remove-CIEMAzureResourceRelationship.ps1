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
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    process {
        $ErrorActionPreference = 'Stop'
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {
                if ($PSCmdlet.ShouldProcess("Id $Id", 'Remove Azure resource relationship')) {
                    Write-CIEMLog -Message "DELETE azure_resource_relationships WHERE id=$Id (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-Relationship'
                    RemoveCIEMAzureEntity -Entity 'ResourceRelationship' -Filters @{ Id = $Id } -Connection $Connection
                }
            }
            'ByCombo' {
                if ($PSCmdlet.ShouldProcess("$SourceId -> $TargetId ($Relationship)", 'Remove Azure resource relationship')) {
                    Write-CIEMLog -Message "DELETE azure_resource_relationships WHERE source='$SourceId' target='$TargetId' rel='$Relationship' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-Relationship'
                    RemoveCIEMAzureEntity -Entity 'ResourceRelationship' -Filters @{
                        SourceId = $SourceId
                        TargetId = $TargetId
                        Relationship = $Relationship
                    } -Connection $Connection
                }
            }
            'All' {
                if ($PSCmdlet.ShouldProcess('all rows', 'Remove Azure resource relationships')) {
                    Write-CIEMLog -Message "DELETE azure_resource_relationships ALL ROWS (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-Relationship'
                    RemoveCIEMAzureEntity -Entity 'ResourceRelationship' -All -Connection $Connection
                }
            }
            'InputObject' {
                foreach ($obj in $InputObject) {
                    if ($PSCmdlet.ShouldProcess("Id $($obj.Id)", 'Remove Azure resource relationship')) {
                        Write-CIEMLog -Message "DELETE azure_resource_relationships WHERE id=$($obj.Id) (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-Relationship'
                        RemoveCIEMAzureEntity -Entity 'ResourceRelationship' -Filters @{ Id = $obj.Id } -Connection $Connection
                    }
                }
            }
        }
    }
}
