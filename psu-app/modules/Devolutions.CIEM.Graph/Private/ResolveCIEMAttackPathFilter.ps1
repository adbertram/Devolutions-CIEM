function ResolveCIEMAttackPathFilter {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$PropertiesJson,

        [Parameter(Mandatory)]
        [PSCustomObject]$Filter
    )

    $ErrorActionPreference = 'Stop'

    $props = $PropertiesJson | ConvertFrom-Json -ErrorAction Stop
    $propValue = $props.($Filter.property)

    switch ($Filter.op) {
        'eq' { return $propValue -eq $Filter.value }
        'neq' { return $propValue -ne $Filter.value }
        'gt' { return [double]$propValue -gt [double]$Filter.value }
        'gt_or_null' { if ($null -eq $propValue) { return $true }; return [double]$propValue -gt [double]$Filter.value }
        'lt' { return [double]$propValue -lt [double]$Filter.value }
        'in' { return $propValue -in $Filter.value }
        'contains_port' {
            if (-not $propValue) { return $false }
            $targetPorts = @($Filter.value | ForEach-Object { [int]$_ })
            foreach ($portEntry in $propValue) {
                $portStr = [string]$portEntry.port
                if ($portStr -eq '*') {
                    return $true
                }
                if ($portStr -match '^\d+-\d+$') {
                    $parts = $portStr -split '-'
                    $a = [int]$parts[0]
                    $b = [int]$parts[1]
                    $low = [math]::Min($a, $b)
                    $high = [math]::Max($a, $b)
                    foreach ($tp in $targetPorts) {
                        if ($tp -ge $low -and $tp -le $high) { return $true }
                    }
                } elseif ($portStr -match '^\d+$') {
                    $portNum = [int]$portStr
                    if ($portNum -in $targetPorts) { return $true }
                }
                # Non-numeric, non-wildcard, non-range port strings (e.g. "Any") are skipped
            }
            return $false
        }
        default { throw "Unknown filter operator: $($Filter.op)" }
    }
}
