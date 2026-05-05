function ConvertTo-CIEMPSUCommandOutputText {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object[]]$Output
    )

    $ErrorActionPreference = 'Stop'

    $text = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @($Output)) {
        if ($null -eq $item) {
            continue
        }

        if ($item -is [string]) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                $text.Add($item)
            }
            continue
        }

        foreach ($propertyName in @('message', 'data')) {
            $property = $item.PSObject.Properties[$propertyName]
            if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                $text.Add([string]$property.Value)
                break
            }
        }
    }

    @($text)
}
