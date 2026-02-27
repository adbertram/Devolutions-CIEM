function Test-NetworkSshInternetAccessRestricted {
    <#
    .SYNOPSIS
        Network security group does not allow inbound SSH (TCP port 22) from the Internet

    .DESCRIPTION
        **Azure NSG** inbound rules that allow **SSH** on `TCP 22` from `0.0.0.0/0`, `Internet`, or `*` are identified, including rules where port ranges include `22` and protocol is `TCP` or `*`.
        
        Indicates NSGs exposing SSH to the Internet.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: network_ssh_internet_access_restricted

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check network_ssh_internet_access_restricted for reference.', 'N/A', 'network Resources')
}
