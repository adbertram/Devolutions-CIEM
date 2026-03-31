function ResolveCIEMScopeLabel {
    <#
    .SYNOPSIS
        Converts an Azure ARM scope string to a friendly display label.
    .PARAMETER Scope
        The ARM scope string (e.g., /subscriptions/{id}/resourceGroups/{name}).
    .PARAMETER SubscriptionNameLookup
        Hashtable of subscription ID to friendly name.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Scope,

        [Parameter()]
        [hashtable]$SubscriptionNameLookup = @{}
    )

    $ErrorActionPreference = 'Stop'

    # Root scope
    if ($Scope -eq '/') {
        return 'Root Scope'
    }

    # Parse the scope into segments
    $segments = $Scope.Trim('/') -split '/'

    # /subscriptions/{id}
    if ($segments.Count -eq 2 -and $segments[0] -eq 'subscriptions') {
        $subId = $segments[1]
        $subName = $SubscriptionNameLookup[$subId]
        if ($subName) {
            return "$subName (subscription)"
        }
        return "$subId (subscription)"
    }

    # /subscriptions/{id}/resourceGroups/{name}
    if ($segments.Count -eq 4 -and $segments[0] -eq 'subscriptions' -and $segments[2] -eq 'resourceGroups') {
        return "$($segments[3]) (resource group)"
    }

    # /subscriptions/{id}/resourceGroups/{rg}/providers/{type}/{name}[/subtype/subname...]
    if ($segments.Count -ge 6 -and $segments[0] -eq 'subscriptions' -and $segments[2] -eq 'resourceGroups' -and $segments[4] -eq 'providers') {
        # Return the last segment (resource name)
        return $segments[-1]
    }

    # Fallback: return the last path segment
    return $segments[-1]
}
