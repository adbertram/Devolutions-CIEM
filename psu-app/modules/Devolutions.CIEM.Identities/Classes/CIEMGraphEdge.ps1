enum CIEMGraphRelationship {
    # Identity
    REPORTS_TO
    MEMBER_OF
    OWNER_OF
    HAS_SERVICE_PRINCIPAL
    # App roles
    HAS_APP_ROLE
    ASSIGNED_TO
    # RBAC
    HAS_ROLE_ASSIGNMENT
    USES_ROLE
    HAS_PERMISSIONS
    # Computed
    CAN_READ
    CAN_WRITE
    CAN_MANAGE
}

class CIEMGraphEdge {
    [string]$SourceId
    [string]$TargetId
    [CIEMGraphRelationship]$Relationship
    [hashtable]$Properties

    CIEMGraphEdge() {
        $this.Properties = @{}
    }

    CIEMGraphEdge([string]$SourceId, [string]$TargetId, [CIEMGraphRelationship]$Relationship) {
        $this.SourceId = $SourceId
        $this.TargetId = $TargetId
        $this.Relationship = $Relationship
        $this.Properties = @{}
    }
}
