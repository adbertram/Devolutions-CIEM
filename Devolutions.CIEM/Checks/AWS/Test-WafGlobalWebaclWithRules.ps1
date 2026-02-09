function Test-WafGlobalWebaclWithRules {
    <#
    .SYNOPSIS
        AWS WAF Classic global Web ACL has at least one rule or rule group

    .DESCRIPTION
        **AWS WAF Classic global web ACLs** are evaluated for the presence of at least one **rule** or **rule group** that inspects HTTP(S) requests

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

    # TODO: Implement check logic based on Prowler check: waf_global_webacl_with_rules

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check waf_global_webacl_with_rules for reference.', 'N/A', 'waf Resources')
}
