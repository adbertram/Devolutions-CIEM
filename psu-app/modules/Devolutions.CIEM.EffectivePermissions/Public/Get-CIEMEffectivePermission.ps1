function Get-CIEMEffectivePermission {
    [CmdletBinding()]
    [OutputType([CIEMEffectivePermission[]])]
    param(
        [Parameter()]
        [CIEMEffectivePermissionProvider[]]$Provider,

        [Parameter()]
        [string]$PrincipalId,

        [Parameter()]
        [CIEMPrincipalType[]]$PrincipalType,

        [Parameter()]
        [string]$ResourceId,

        [Parameter()]
        [string]$ResourceType,

        [Parameter()]
        [CIEMAccessLevel[]]$AccessLevel,

        [Parameter()]
        [CIEMEntitlementType[]]$EntitlementType,

        [Parameter()]
        [switch]$PrivilegedOnly,

        [Parameter()]
        [bool]$IncludeInherited = $true,

        [Parameter()]
        [switch]$IncludeDenied,

        [Parameter()]
        [switch]$IncludeRaw
    )

    $ErrorActionPreference = 'Stop'

    $selectedProviders = if ($Provider) {
        @($Provider)
    } else {
        @([CIEMEffectivePermissionProvider]::Azure)
    }

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($providerName in $selectedProviders) {
        switch ($providerName) {
            ([CIEMEffectivePermissionProvider]::Azure) {
                $results.AddRange(@(ResolveCIEMAzureEffectivePermission -IncludeInherited:$IncludeInherited))
            }
            ([CIEMEffectivePermissionProvider]::AWS) {
                $results.AddRange(@(ResolveCIEMAwsEffectivePermission))
            }
            default {
                throw "Provider '$providerName' is not supported by Get-CIEMEffectivePermission."
            }
        }
    }

    $filtered = @($results)

    if ($PrincipalId) {
        $filtered = @($filtered | Where-Object { $_.Principal.Id -eq $PrincipalId })
    }
    if ($PrincipalType) {
        $filtered = @($filtered | Where-Object { $_.Principal.Type -in $PrincipalType })
    }
    if ($ResourceId) {
        $filtered = @($filtered | Where-Object { $_.Target.Id -eq $ResourceId })
    }
    if ($ResourceType) {
        $filtered = @($filtered | Where-Object { $_.Target.Type -eq $ResourceType })
    }
    if ($AccessLevel) {
        $filtered = @($filtered | Where-Object {
            @($_.Actions | Where-Object { $_.AccessLevel -in $AccessLevel }).Count -gt 0
        })
    }
    if ($EntitlementType) {
        $filtered = @($filtered | Where-Object { $_.Entitlement.Type -in $EntitlementType })
    }
    if ($PrivilegedOnly) {
        $filtered = @($filtered | Where-Object { $_.Privileged })
    }
    if (-not $IncludeDenied) {
        $filtered = @($filtered | Where-Object {
            @($_.Actions | Where-Object { $_.Effect -in @([CIEMPermissionEffect]::Deny, [CIEMPermissionEffect]::ConditionalDeny) }).Count -eq 0
        })
    }
    if (-not $IncludeRaw) {
        foreach ($item in $filtered) {
            foreach ($evidence in @($item.Evidence)) {
                $evidence.DataJson = $null
            }
        }
    }

    @($filtered)
}
