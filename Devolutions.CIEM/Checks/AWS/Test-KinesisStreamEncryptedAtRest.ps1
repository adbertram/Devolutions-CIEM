function Test-KinesisStreamEncryptedAtRest {
    <#
    .SYNOPSIS
        Kinesis stream is encrypted at rest with KMS

    .DESCRIPTION
        **Amazon Kinesis Data Streams** with **server-side encryption** use **AWS KMS** to protect records at rest. The evaluation determines whether a stream has `SSE-KMS` configured with a KMS key; streams lacking KMS-based at rest encryption are identified.

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

    # TODO: Implement check logic based on Prowler check: kinesis_stream_encrypted_at_rest

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check kinesis_stream_encrypted_at_rest for reference.', 'N/A', 'kinesis Resources')
}
