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
        'lt' { return [double]$propValue -lt [double]$Filter.value }
        'in' { return $propValue -in $Filter.value }
        'contains_port' {
            if (-not $propValue) { return $false }
            $targetPorts = @($Filter.value | ForEach-Object { [int]$_ })
            foreach ($portEntry in $propValue) {
                $portNum = [int]$portEntry.port
                if ($portNum -in $targetPorts) {
                    return $true
                }
            }
            return $false
        }
        default { throw "Unknown filter operator: $($Filter.op)" }
    }
}
