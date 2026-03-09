function Remove-CIEMIdentityResourceAccess {
    <#
    .SYNOPSIS
        Removes identity-resource access rows from the database.
    .DESCRIPTION
        Deletes rows from the identity_resource_access table. Supports deleting by
        ProviderId (bulk), by IdentityId, or by ResourceType.
    .PARAMETER ProviderId
        Delete all access rows for a provider.
    .PARAMETER IdentityId
        Optional identity ID filter.
    .PARAMETER ResourceType
        Optional resource type filter.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderId,

        [Parameter()]
        [string]$IdentityId,

        [Parameter()]
        [string]$ResourceType
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @("provider_id = @provider_id")
    $params = @{ provider_id = $ProviderId }

    if ($IdentityId) {
        $conditions += "identity_id = @identity_id"
        $params.identity_id = $IdentityId
    }

    if ($ResourceType) {
        $conditions += "resource_type = @resource_type"
        $params.resource_type = $ResourceType
    }

    $target = "identity_resource_access for provider '$ProviderId'"
    if ($IdentityId) { $target += " identity '$IdentityId'" }
    if ($ResourceType) { $target += " type '$ResourceType'" }

    if (-not $PSCmdlet.ShouldProcess($target, 'Remove')) {
        return
    }

    $query = "DELETE FROM identity_resource_access WHERE $($conditions -join ' AND ')"
    Invoke-CIEMQuery -Query $query -Parameters $params -AsNonQuery | Out-Null
}
