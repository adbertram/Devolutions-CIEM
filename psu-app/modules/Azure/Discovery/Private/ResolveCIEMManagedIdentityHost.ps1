function ResolveCIEMManagedIdentityHost {
    <#
    .SYNOPSIS
        Finds the ARM resource hosting a managed identity by its principal ID.
    .DESCRIPTION
        Queries azure_arm_resources where the identity JSON column contains the given principal ID.
        Returns the first matching ARM resource or $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PrincipalId
    )

    $ErrorActionPreference = 'Stop'

    $sql = "SELECT * FROM azure_arm_resources WHERE identity LIKE '%' || @principalId || '%' LIMIT 1"
    $rows = @(Invoke-CIEMQuery -Query $sql -Parameters @{ principalId = $PrincipalId })

    if ($rows.Count -eq 0) {
        return $null
    }

    $row = $rows[0]
    [PSCustomObject]@{
        Id            = $row.id
        Name          = $row.name
        Type          = $row.type
        ResourceGroup = $row.resource_group
        SubscriptionId = $row.subscription_id
    }
}
