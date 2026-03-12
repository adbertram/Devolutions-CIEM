function New-CIEMAzureResourceRelationship {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a data record in database')]
    [OutputType('CIEMAzureResourceRelationship[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$SourceId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$SourceType,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$TargetId,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$TargetType,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Relationship,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                New-CIEMAzureResourceRelationship `
                    -SourceId $obj.SourceId `
                    -SourceType $obj.SourceType `
                    -TargetId $obj.TargetId `
                    -TargetType $obj.TargetType `
                    -Relationship $obj.Relationship `
                    -CollectedAt $obj.CollectedAt
            }
            return
        }

        Invoke-CIEMQuery -Query @"
INSERT INTO azure_resource_relationships (source_id, source_type, target_id, target_type, relationship, collected_at)
VALUES (@source_id, @source_type, @target_id, @target_type, @relationship, @collected_at)
"@ -Parameters @{
            source_id    = $SourceId
            source_type  = $SourceType
            target_id    = $TargetId
            target_type  = $TargetType
            relationship = $Relationship
            collected_at = $CollectedAt
        } -AsNonQuery | Out-Null

        $newId = Invoke-CIEMQuery -Query "SELECT last_insert_rowid() as id"
        Get-CIEMAzureResourceRelationship -Id $newId.id
    }
}
