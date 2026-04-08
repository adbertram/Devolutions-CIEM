function ConvertFromCIEMStoredResource {
    <#
    .SYNOPSIS
        Rehydrates a stored Azure resource row into a PSCustomObject whose shape
        matches the original API response.

    .DESCRIPTION
        Discovery writes each resource to the database as a Properties JSON blob
        plus a handful of indexed columns (Id, DisplayName, Name, Type, ParentId,
        SubscriptionId, ResourceGroup). At scan time we need to reverse that
        back into a single object whose top-level shape matches what the Graph
        or Resource Graph APIs originally returned (id, displayName, name, type,
        parentId, subscriptionId, resourceGroup plus all properties).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Resource
    )

    $ErrorActionPreference = 'Stop'

    $value = if ($Resource.Properties) {
        $Resource.Properties | ConvertFrom-Json -ErrorAction Stop
    }
    else {
        [pscustomobject]@{}
    }

    foreach ($pair in @(
        @{ Name = 'id'; Value = $Resource.Id },
        @{ Name = 'displayName'; Value = $Resource.DisplayName },
        @{ Name = 'name'; Value = $Resource.Name },
        @{ Name = 'type'; Value = $Resource.Type },
        @{ Name = 'parentId'; Value = $Resource.ParentId },
        @{ Name = 'subscriptionId'; Value = $Resource.SubscriptionId },
        @{ Name = 'resourceGroup'; Value = $Resource.ResourceGroup }
    )) {
        if ($pair.Value -and -not ($value.PSObject.Properties.Name -contains $pair.Name)) {
            $value | Add-Member -NotePropertyName $pair.Name -NotePropertyValue $pair.Value
        }
    }

    $value
}
