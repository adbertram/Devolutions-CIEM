enum CIEMEffectivePermissionProvider {
    Azure
    AWS
    GCP
    Kubernetes
}

enum CIEMPrincipalType {
    User
    Group
    ServicePrincipal
    ManagedIdentity
    Role
    ServiceAccount
    Application
    WorkloadIdentity
    Unknown
}

enum CIEMEntitlementType {
    RoleAssignment
    GroupMembership
    DirectoryRole
    AppRoleAssignment
    OAuthGrant
    ManagedPolicy
    InlinePolicy
    ResourcePolicy
    TrustPolicy
    ServiceControlPolicy
    PermissionBoundary
    IAMBinding
    DenyPolicy
    RoleBinding
    ClusterRoleBinding
}

enum CIEMAccessLevel {
    Read
    Write
    Manage
    PermissionAdmin
    DataAccess
    SecretAccess
    AssumeRole
    Impersonate
    Execute
    Unclassified
}

enum CIEMPermissionEffect {
    Allow
    Deny
    ConditionalAllow
    ConditionalDeny
}

enum CIEMPermissionPathType {
    Direct
    GroupInherited
    NestedGroupInherited
    ScopeInherited
    RoleAssumed
    ResourcePolicy
    TrustPolicy
    AppRole
    OAuthGrant
    ServiceControlPolicy
    PermissionBoundary
}

class CIEMEffectivePrincipal {
    [string]$Id
    [string]$DisplayName
    [CIEMPrincipalType]$Type
    [string]$NativeType
    [string]$ProviderAccountId
    [string]$PropertiesJson

    CIEMEffectivePrincipal() {}
}

class CIEMEffectiveEntitlement {
    [string]$Id
    [string]$Name
    [CIEMEntitlementType]$Type
    [string]$NativeType
    [string]$ScopeId
    [string]$ScopeType
    [string]$PropertiesJson

    CIEMEffectiveEntitlement() {}
}

class CIEMEffectiveResource {
    [string]$Id
    [string]$DisplayName
    [string]$Type
    [string]$ProviderAccountId
    [string]$Region
    [string]$PropertiesJson

    CIEMEffectiveResource() {}
}

class CIEMEffectivePermissionAction {
    [string]$NativeAction
    [string]$Description
    [CIEMAccessLevel]$AccessLevel
    [CIEMPermissionEffect]$Effect
    [string]$Condition
    [bool]$Privileged

    CIEMEffectivePermissionAction() {}
}

class CIEMEffectivePermissionPathStep {
    [int]$Order
    [CIEMPermissionPathType]$Type
    [string]$SourceId
    [string]$SourceName
    [string]$TargetId
    [string]$TargetName
    [string]$Description
    [string]$EvidenceId

    CIEMEffectivePermissionPathStep() {}
}

class CIEMEffectivePermissionEvidence {
    [string]$Id
    [string]$SourceSystem
    [string]$SourceApi
    [string]$SourceRecordId
    [string]$CollectedAt
    [string]$DataJson

    CIEMEffectivePermissionEvidence() {}
}

class CIEMEffectivePermission {
    [CIEMEffectivePermissionProvider]$Provider
    [CIEMEffectivePrincipal]$Principal
    [CIEMEffectiveEntitlement]$Entitlement
    [CIEMEffectiveResource]$Target
    [CIEMEffectivePermissionAction[]]$Actions
    [CIEMEffectivePermissionPathStep[]]$Path
    [CIEMEffectivePermissionEvidence[]]$Evidence
    [bool]$Privileged
    [string]$CollectedAt

    CIEMEffectivePermission() {}
}
