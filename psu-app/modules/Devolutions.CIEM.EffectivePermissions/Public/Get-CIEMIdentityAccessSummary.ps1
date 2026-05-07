function Get-CIEMIdentityAccessSummary {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateSet('Azure', 'AWS')]
        [string]$Provider = 'Azure',

        [Parameter()]
        [ValidateSet('Read', 'Write', 'Manage', 'PermissionAdmin', 'DataAccess', 'SecretAccess', 'AssumeRole', 'Impersonate', 'Execute', 'Unclassified')]
        [string[]]$AccessLevel,

        [Parameter()]
        [switch]$PrivilegedOnly
    )

    $ErrorActionPreference = 'Stop'

    if ($Provider -ne 'Azure') {
        throw "Provider '$Provider' is not supported by Get-CIEMIdentityAccessSummary."
    }

    $permissionSplat = @{
        Provider = $Provider
        IncludeRaw = $true
    }
    if ($AccessLevel) {
        $permissionSplat.AccessLevel = $AccessLevel
    }
    if ($PrivilegedOnly) {
        $permissionSplat.PrivilegedOnly = $true
    }

    $permissions = @(Get-CIEMEffectivePermission @permissionSplat)
    if ($permissions.Count -eq 0) {
        return @()
    }

    $riskSummaryByPrincipalId = @{}
    foreach ($summary in @(Get-CIEMIdentityRiskSummary)) {
        $principalId = [string]$summary.Id
        if ($riskSummaryByPrincipalId.ContainsKey($principalId)) {
            throw "Duplicate identity risk summary found for principal '$principalId'."
        }
        $riskSummaryByPrincipalId[$principalId] = $summary
    }

    $severityRank = @{
        Critical = 4
        High = 3
        Medium = 2
        Low = 1
    }

    $rows = foreach ($group in @($permissions | Group-Object -Property { "$([string]$_.Provider)|$([string]$_.Principal.Id)" })) {
        $firstPermission = $group.Group[0]
        $principalId = [string]$firstPermission.Principal.Id
        $providerName = [string]$firstPermission.Provider

        if (-not $riskSummaryByPrincipalId.ContainsKey($principalId)) {
            throw "Identity risk summary not found for principal '$principalId'."
        }

        $riskSummary = $riskSummaryByPrincipalId[$principalId]
        $riskLevel = [string]$riskSummary.RiskLevel

        if (-not $severityRank.ContainsKey($riskLevel)) {
            throw "Unknown identity risk level '$riskLevel' for principal '$principalId'."
        }

        $accessLevels = @(
            $group.Group |
                ForEach-Object { $_.Actions } |
                ForEach-Object { [string]$_.AccessLevel } |
                Sort-Object -Unique
        )

        $targetIds = @(
            $group.Group |
                ForEach-Object { [string]$_.Target.Id } |
                Sort-Object -Unique
        )

        [PSCustomObject]@{
            Id                       = "$providerName-$principalId"
            Provider                 = $providerName
            PrincipalId              = $principalId
            ObjectId                 = $principalId
            Principal                = [string]$firstPermission.Principal.DisplayName
            PrincipalType            = [string]$firstPermission.Principal.Type
            EntitlementCount         = [int]$riskSummary.EntitlementCount
            PrivilegedRoleCount      = [int]$riskSummary.PrivilegedCount
            EffectivePermissionCount = $group.Group.Count
            TargetCount              = $targetIds.Count
            RiskLevel                = $riskLevel
            LastActivity             = if ($riskSummary.LastSignIn) { ([datetimeoffset]$riskSummary.LastSignIn).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ') } else { $null }
            AccessLevels             = @($accessLevels)
        }
    }

    @($rows | Sort-Object `
        @{ Expression = {
                $severityRank[$_.RiskLevel]
            }; Descending = $true },
        @{ Expression = { $_.Principal } },
        @{ Expression = { $_.ObjectId } })
}
