function Test-SagemakerNotebookInstanceEncryptionEnabled {
    <#
    .SYNOPSIS
        SageMaker notebook instance is encrypted with a KMS key

    .DESCRIPTION
        **Amazon SageMaker notebook instances** are assessed for **at-rest encryption** using an AWS KMS key. The finding reflects whether a `KmsKeyId` is configured for the notebook's ML volume encryption.

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

    # TODO: Implement check logic based on Prowler check: sagemaker_notebook_instance_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check sagemaker_notebook_instance_encryption_enabled for reference.', 'N/A', 'sagemaker Resources')
}
