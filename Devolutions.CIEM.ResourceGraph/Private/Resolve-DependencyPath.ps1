function Resolve-DependencyPath {
    <#
    .SYNOPSIS
        Walks a dotted property path with array expansion and returns all resolved terminal values.
    .DESCRIPTION
        Given a resource object and a path like "properties.networkProfile.networkInterfaces[].id",
        splits on '.', walks each segment, expands arrays on '[]' segments, and returns all
        resolved terminal values as string[].
    .EXAMPLE
        Resolve-DependencyPath -Resource $vm -Path 'properties.networkProfile.networkInterfaces[].id'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Resource,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $ErrorActionPreference = 'Stop'

    $segments = $Path -split '\.'
    # Start with a list of current values to walk (supports branching on arrays)
    $currentValues = [System.Collections.Generic.List[object]]::new()
    $currentValues.Add($Resource)

    foreach ($segment in $segments) {
        $isArray = $segment.EndsWith('[]')
        $isKeys = $segment.EndsWith('{keys}')
        $propertyName = if ($isArray) { $segment.Substring(0, $segment.Length - 2) }
                        elseif ($isKeys) { $segment.Substring(0, $segment.Length - 6) }
                        else { $segment }

        $nextValues = [System.Collections.Generic.List[object]]::new()
        foreach ($value in $currentValues) {
            if ($null -eq $value) { continue }

            # Access the property
            $prop = $value.$propertyName
            if ($null -eq $prop) { continue }

            if ($isKeys) {
                # Extract property names as values (for dictionary-keyed objects like userAssignedIdentities)
                foreach ($key in $prop.PSObject.Properties.Name) {
                    if ($null -ne $key) {
                        $nextValues.Add($key)
                    }
                }
            }
            elseif ($isArray) {
                # Expand array elements into separate branches
                foreach ($item in @($prop)) {
                    if ($null -ne $item) {
                        $nextValues.Add($item)
                    }
                }
            } else {
                $nextValues.Add($prop)
            }
        }

        $currentValues = $nextValues
        if ($currentValues.Count -eq 0) { return @() }
    }

    # Return terminal values as strings
    return [string[]]($currentValues | Where-Object { $null -ne $_ })
}
