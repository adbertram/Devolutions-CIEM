class CIEMAzureRoleAssignment {
    [string]$Id
    [string]$ProviderId
    [string]$PrincipalId
    [string]$PrincipalType
    [string]$RoleDefinitionId
    [string]$Scope
    [string]$Condition
    [string]$ConditionVersion
    [string]$Description
    [string]$CreatedOn
    [datetime]$CollectedAt

    CIEMAzureRoleAssignment() {
        $this.CollectedAt = Get-Date
    }
}
