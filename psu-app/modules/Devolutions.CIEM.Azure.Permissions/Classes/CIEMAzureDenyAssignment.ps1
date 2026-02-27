class CIEMAzureDenyAssignment {
    [string]$Id
    [string]$ProviderId
    [string]$DenyAssignmentName
    [string]$Description
    [string]$Scope
    [bool]$DoNotApplyToChildren
    [string]$Principals
    [string]$ExcludePrincipals
    [string]$PermissionsActions
    [string]$PermissionsNotActions
    [string]$PermissionsDataActions
    [string]$PermissionsNotDataActions
    [string]$Condition
    [bool]$IsSystemProtected
    [datetime]$CollectedAt

    CIEMAzureDenyAssignment() {
        $this.IsSystemProtected = $true
        $this.CollectedAt = Get-Date
    }
}
