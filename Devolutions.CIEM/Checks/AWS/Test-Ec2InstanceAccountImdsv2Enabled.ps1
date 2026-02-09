function Test-Ec2InstanceAccountImdsv2Enabled {
    <#
    .SYNOPSIS
        IMDSv2 is required by default for EC2 instances at the account level

    .DESCRIPTION
        **EC2 account IMDS defaults** with `http_tokens`=`required` ensure new instances in the Region use **IMDSv2** by default and disable IMDSv1. *Existing instances keep their current setting.*

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

    # TODO: Implement check logic based on Prowler check: ec2_instance_account_imdsv2_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_instance_account_imdsv2_enabled for reference.', 'N/A', 'ec2 Resources')
}
