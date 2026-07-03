function CompareCIEMKeyedSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$BaselineItems,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$CurrentItems,

        [Parameter(Mandatory)]
        [string]$KeyProperty,

        [Parameter(Mandatory)]
        [hashtable]$TransitionMap
    )

    $ErrorActionPreference = 'Stop'

    foreach ($transitionKey in @('BaselineOnly', 'Both', 'CurrentOnly')) {
        if (-not $TransitionMap.ContainsKey($transitionKey)) {
            throw "Transition map is missing '$transitionKey'."
        }
        if ([string]::IsNullOrWhiteSpace([string]$TransitionMap[$transitionKey])) {
            throw "Transition map value for '$transitionKey' cannot be blank."
        }
    }

    function New-KeyedMap {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [object[]]$Items,

            [Parameter(Mandatory)]
            [string]$MapName
        )

        $ErrorActionPreference = 'Stop'

        $map = @{}
        foreach ($item in $Items) {
            if (-not $item.PSObject.Properties[$KeyProperty]) {
                throw "$MapName item is missing key property '$KeyProperty'."
            }
            $key = [string]$item.$KeyProperty
            if ([string]::IsNullOrWhiteSpace($key)) {
                throw "$MapName item has a blank '$KeyProperty' value."
            }
            if ($map.ContainsKey($key)) {
                throw "$MapName contains duplicate key '$key'."
            }
            $map[$key] = $item
        }
        $map
    }

    $baselineByKey = New-KeyedMap -Items $BaselineItems -MapName 'Baseline'
    $currentByKey = New-KeyedMap -Items $CurrentItems -MapName 'Current'
    $allKeys = @($baselineByKey.Keys + $currentByKey.Keys | Sort-Object -Unique)

    foreach ($key in $allKeys) {
        $hasBaseline = $baselineByKey.ContainsKey($key)
        $hasCurrent = $currentByKey.ContainsKey($key)
        $transition = if ($hasBaseline -and $hasCurrent) {
            [string]$TransitionMap['Both']
        }
        elseif ($hasBaseline) {
            [string]$TransitionMap['BaselineOnly']
        }
        else {
            [string]$TransitionMap['CurrentOnly']
        }

        [pscustomobject]@{
            Key          = $key
            Status       = $transition
            BaselineItem = if ($hasBaseline) { $baselineByKey[$key] } else { $null }
            CurrentItem  = if ($hasCurrent) { $currentByKey[$key] } else { $null }
        }
    }
}
