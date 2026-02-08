function Test-FirehoseStreamEncryptedAtRest {
    <#
    .SYNOPSIS
        Kinesis Data Firehose delivery stream is encrypted at rest

    .DESCRIPTION
        **Amazon Data Firehose** delivery streams must enable **server-side encryption at rest** with AWS KMS regardless of the source type. Encryption of upstream sources such as **Kinesis Data Streams** or **MSK** does not replace the need to protect the delivery stream itself.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: firehose_stream_encrypted_at_rest

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check firehose_stream_encrypted_at_rest for reference.', 'N/A', 'firehose Resources')
}
