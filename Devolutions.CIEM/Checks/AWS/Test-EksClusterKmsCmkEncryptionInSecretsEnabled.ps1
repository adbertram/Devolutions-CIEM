function Test-EksClusterKmsCmkEncryptionInSecretsEnabled {
    <#
    .SYNOPSIS
        EKS cluster has Kubernetes secrets encryption enabled

    .DESCRIPTION
        **Amazon EKS** clusters configure **AWS KMS envelope encryption** so Kubernetes **Secrets** are stored in etcd as ciphertext at rest.

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

    # TODO: Implement check logic based on Prowler check: eks_cluster_kms_cmk_encryption_in_secrets_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check eks_cluster_kms_cmk_encryption_in_secrets_enabled for reference.', 'N/A', 'eks Resources')
}
