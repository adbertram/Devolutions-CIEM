function Test-StoragegatewayGatewayFaultTolerant {
    <#
    .SYNOPSIS
        AWS Storage Gateway gateway is not hosted on EC2

    .DESCRIPTION
        AWS Storage Gateway hosted on an **EC2 instance** is flagged by assessing each gateway's hosting environment, distinguishing **single-instance EC2** deployments from **non-EC2** platforms that can leverage platform-level high availability.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: storagegateway_gateway_fault_tolerant

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check storagegateway_gateway_fault_tolerant for reference.', 'N/A', 'storagegateway Resources')
}
