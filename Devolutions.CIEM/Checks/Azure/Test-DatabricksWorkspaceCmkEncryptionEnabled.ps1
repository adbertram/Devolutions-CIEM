function Test-DatabricksWorkspaceCmkEncryptionEnabled {
    <#
    .SYNOPSIS
        Databricks workspace uses a customer-managed key (CMK) for encryption at rest

    .DESCRIPTION
        **Azure Databricks workspaces** are evaluated for use of **customer-managed keys** (`CMK`) on at-rest encryption, based on the workspace's managed disk encryption configuration.

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

    # TODO: Implement check logic based on Prowler check: databricks_workspace_cmk_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check databricks_workspace_cmk_encryption_enabled for reference.', 'N/A', 'databricks Resources')
}
