function Test-IamPolicyAttachedOnlyToGroupOrRoles {
    <#
    .SYNOPSIS
        IAM user has no inline or attached policies

    .DESCRIPTION
        **IAM users** have identity-based policies attached directly (managed or inline) instead of inheriting permissions via **groups** or **roles**.

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

    # TODO: Implement check logic based on Prowler check: iam_policy_attached_only_to_group_or_roles

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check iam_policy_attached_only_to_group_or_roles for reference.', 'N/A', 'iam Resources')
}
