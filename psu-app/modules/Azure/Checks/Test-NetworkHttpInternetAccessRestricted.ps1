function Test-NetworkHttpInternetAccessRestricted {
    <#
    .SYNOPSIS
        Network security group restricts inbound HTTP (port 80) access from the Internet

    .DESCRIPTION
        **Azure NSG** are evaluated for inbound rules that allow public **HTTP** access on `TCP 80`, including cases where `80` is covered by a port range, from `0.0.0.0/0`, `Internet`, or `*`.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: network_http_internet_access_restricted

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check network_http_internet_access_restricted for reference.', 'N/A', 'network Resources')
}
