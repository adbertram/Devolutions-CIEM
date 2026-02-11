function Test-TransferServerInTransitEncryptionEnabled {
    <#
    .SYNOPSIS
        Transfer Family server has encryption in transit enabled

    .DESCRIPTION
        **AWS Transfer Family servers** are evaluated for presence of the unencrypted `FTP` protocol among enabled protocols, as opposed to encrypted options like SFTP, FTPS, or AS2.

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

    # TODO: Implement check logic based on Prowler check: transfer_server_in_transit_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check transfer_server_in_transit_encryption_enabled for reference.', 'N/A', 'transfer Resources')
}
