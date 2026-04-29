function Get-CIEMGraphEdge {
    [CmdletBinding()]
    [OutputType('CIEMGraphEdge[]')]
    param(
        [Parameter()]
        [int]$Id,

        [Parameter()]
        [string]$SourceId,

        [Parameter()]
        [string]$TargetId,

        [Parameter()]
        [string]$Kind,

        [Parameter()]
        [int]$Computed
    )

    $ErrorActionPreference = 'Stop'

    $filters = @{}
    foreach ($name in @('Id', 'SourceId', 'TargetId', 'Kind', 'Computed')) {
        if ($PSBoundParameters.ContainsKey($name)) {
            $filters[$name] = $PSBoundParameters[$name]
        }
    }

    GetCIEMGraphEntity -Entity Edge -Filters $filters
}
