class CIEMAzureResourceRelationship {
    [int]$Id
    [string]$SourceId
    [string]$TargetId
    [string]$RelationshipType
    [string]$Properties
    [datetime]$CollectedAt

    CIEMAzureResourceRelationship() {
        $this.CollectedAt = Get-Date
    }
}
