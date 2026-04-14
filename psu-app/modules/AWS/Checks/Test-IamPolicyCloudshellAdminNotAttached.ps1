function Test-IamPolicyCloudshellAdminNotAttached {
    <#
    .SYNOPSIS
        No IAM users, groups, or roles have the AWSCloudShellFullAccess policy attached

    .DESCRIPTION
        **IAM identities** with the AWS managed policy `AWSCloudShellFullAccess` attached are identified across users, groups, and roles.
        
        This indicates principals are granted `cloudshell:*` on `*`, enabling full CloudShell features, including environment startup and file transfer.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: iam_policy_cloudshell_admin_not_attached

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check iam_policy_cloudshell_admin_not_attached for reference.', 'N/A', 'iam Resources')
}
