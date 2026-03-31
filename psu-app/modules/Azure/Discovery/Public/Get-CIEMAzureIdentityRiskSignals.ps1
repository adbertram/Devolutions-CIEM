function Get-CIEMAzureIdentityRiskSignals {
    <#
    .SYNOPSIS
        Returns detailed risk signals for a specific identity.
    .DESCRIPTION
        For a given principal ID, returns all effective role assignments, identifies inherited roles,
        computes risk signals (dormant permissions, public exposure, disabled accounts), and for
        managed identities resolves the hosting resource.
    .PARAMETER PrincipalId
        The Entra object ID of the identity to analyze.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$PrincipalId
    )

    $ErrorActionPreference = 'Stop'

    # Get the identity from Entra resources
    $identity = Get-CIEMAzureEntraResource -Id $PrincipalId
    if (-not $identity) {
        throw "Identity not found: $PrincipalId"
    }

    $parsed = ParseCIEMIdentityProperties -PropertiesJson $identity.Properties -EntraType $identity.Type
    $accountEnabled    = $parsed.AccountEnabled
    $isManagedIdentity = $parsed.IsManagedIdentity
    $daysSinceSignIn   = $parsed.DaysSinceSignIn

    # Get all effective role assignments
    $assignments = @(Get-CIEMAzureEffectiveRoleAssignment -PrincipalId $PrincipalId)

    # Build group display name lookup for inherited role annotation
    $groupIds = @($assignments | Where-Object { $_.OriginalPrincipalId -ne $PrincipalId } | ForEach-Object { $_.OriginalPrincipalId } | Select-Object -Unique)
    $groupNameLookup = @{}
    foreach ($gid in $groupIds) {
        $group = Get-CIEMAzureEntraResource -Id $gid
        if ($group) {
            $groupNameLookup[$gid] = $group.DisplayName
        }
    }

    # Enrich role assignments using TestCIEMAzurePrivilegedRole
    $roleAssignments = @($assignments | ForEach-Object {
        $isInherited = $_.OriginalPrincipalId -ne $PrincipalId
        $inheritedFrom = if ($isInherited) { $groupNameLookup[$_.OriginalPrincipalId] } else { $null }

        [PSCustomObject]@{
            RoleName      = $_.RoleName
            Scope         = $_.Scope
            IsPrivileged  = TestCIEMAzurePrivilegedRole -RoleName $_.RoleName -PermissionsJson $_.PermissionsJson
            IsInherited   = $isInherited
            InheritedFrom = $inheritedFrom
        }
    })

    $inheritedRoles = @($roleAssignments | Where-Object { $_.IsInherited })

    # Compute risk signals
    $riskSignals = @()

    # 1. Dormant privileged permissions
    $hasPrivilegedRole = ($roleAssignments | Where-Object { $_.IsPrivileged }) -as [bool]
    if ($hasPrivilegedRole -and ($null -eq $daysSinceSignIn -or $daysSinceSignIn -gt $script:DormantPermissionThresholdDays)) {
        if ($null -eq $daysSinceSignIn) {
            $riskSignals += [PSCustomObject]@{
                Signal          = 'dormant-privileged-permissions'
                Severity        = 'Critical'
                Description     = 'Holds privileged role with no recorded sign-in activity'
                DaysSinceSignIn = $null
            }
        } else {
            $riskSignals += [PSCustomObject]@{
                Signal          = 'dormant-privileged-permissions'
                Severity        = 'Critical'
                Description     = "Holds privileged role with no sign-in activity for $daysSinceSignIn days"
                DaysSinceSignIn = $daysSinceSignIn
            }
        }
    }

    # 2. Group-inherited privileged role
    $inheritedPrivileged = @($inheritedRoles | Where-Object { $_.IsPrivileged })
    foreach ($ip in $inheritedPrivileged) {
        $riskSignals += [PSCustomObject]@{
            Signal      = 'group-inherited-privileged-role'
            Severity    = 'High'
            Description = "Holds $($ip.RoleName) via group '$($ip.InheritedFrom)'"
        }
    }

    # 3. Disabled account with active assignments
    if (-not $accountEnabled -and $assignments.Count -gt 0) {
        $riskSignals += [PSCustomObject]@{
            Signal      = 'disabled-with-permissions'
            Severity    = 'High'
            Description = "Account is disabled but still holds $($assignments.Count) active role assignments"
        }
    }

    # 4. Managed identity public exposure
    $hostingResource = $null
    if ($isManagedIdentity) {
        $hostResource = ResolveCIEMManagedIdentityHost -PrincipalId $PrincipalId

        if ($hostResource) {
            $publicIPs = @(Get-CIEMAzureArmResource -Type 'microsoft.network/publicipaddresses' -ResourceGroup $hostResource.ResourceGroup)
            $hostingResource = [PSCustomObject]@{
                Id            = $hostResource.Id
                Name          = $hostResource.Name
                Type          = $hostResource.Type
                ResourceGroup = $hostResource.ResourceGroup
                HasPublicIP   = ($publicIPs.Count -gt 0)
            }

            if ($publicIPs.Count -gt 0) {
                $riskSignals += [PSCustomObject]@{
                    Signal      = 'managed-identity-public-exposure'
                    Severity    = 'Critical'
                    Description = "Managed identity on $($hostResource.Name) with public IP address"
                }
            }
        }
    }

    [PSCustomObject]@{
        Identity        = [PSCustomObject]@{
            Id                       = $identity.Id
            DisplayName              = $identity.DisplayName
            Type                     = $identity.Type
            AccountEnabled           = $accountEnabled
            LastSignIn               = $parsed.LastSignIn
            LastInteractiveSignIn    = $parsed.LastInteractiveSignIn
            LastNonInteractiveSignIn = $parsed.LastNonInteractiveSignIn
        }
        RoleAssignments = $roleAssignments
        RiskSignals     = $riskSignals
        InheritedRoles  = $inheritedRoles
        HostingResource = $hostingResource
    }
}
