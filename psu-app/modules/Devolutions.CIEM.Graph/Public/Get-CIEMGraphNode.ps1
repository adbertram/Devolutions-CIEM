function Get-CIEMGraphNode {
    [CmdletBinding()]
    [OutputType('CIEMGraphNode[]')]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter()]
        [string]$Kind,

        [Parameter()]
        [string]$DisplayName,

        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$SubscriptionId
    )

    $ErrorActionPreference = 'Stop'

    $filters = @{}
    foreach ($name in @('Id', 'Kind', 'DisplayName', 'Provider', 'SubscriptionId')) {
        if ($PSBoundParameters.ContainsKey($name)) {
            $filters[$name] = $PSBoundParameters[$name]
        }
    }

    GetCIEMGraphEntity -Entity Node -Filters $filters
}
