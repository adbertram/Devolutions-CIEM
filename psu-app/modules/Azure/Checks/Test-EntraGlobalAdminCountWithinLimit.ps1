function Test-EntraGlobalAdminCountWithinLimit {
    <#
    .SYNOPSIS
        Ensure fewer than 5 users have global administrator assignment.

    .DESCRIPTION
        This recommendation aims to maintain a balance between security and operational
        efficiency by ensuring that a minimum of 2 and a maximum of 4 users are assigned
        the Global Administrator role in Microsoft Entra ID. Having at least two Global
        Administrators ensures redundancy, while limiting the number to four reduces the
        risk of excessive privileged access.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'Entra' }).CacheData

    if (-not $svc.DirectoryRoles) {
        [CIEMScanResult]::Create(
            $Check,
            'SKIPPED',
            'Unable to retrieve directory roles - missing permissions',
            'N/A',
            'Global Administrator'
        )
        return
    }

    $globalAdminRole = $svc.DirectoryRoles | Where-Object { $_.displayName -eq 'Global Administrator' } | Select-Object -First 1

    if (-not $globalAdminRole) {
        [CIEMScanResult]::Create(
            $Check,
            'SKIPPED',
            'Global Administrator role not found in directory roles',
            'N/A',
            'Global Administrator'
        )
        return
    }

    $memberLookup = $svc.DirectoryRoleMembers[$globalAdminRole.id]
    $numGlobalAdmins = if ($null -eq $memberLookup) { 0 } else { @($memberLookup).Count }

    if ($numGlobalAdmins -lt 5) {
        [CIEMScanResult]::Create(
            $Check,
            'PASS',
            "There are $numGlobalAdmins global administrators.",
            $globalAdminRole.id,
            'Global Administrator'
        )
    }
    else {
        [CIEMScanResult]::Create(
            $Check,
            'FAIL',
            "There are $numGlobalAdmins global administrators. It should be less than five.",
            $globalAdminRole.id,
            'Global Administrator'
        )
    }
}
