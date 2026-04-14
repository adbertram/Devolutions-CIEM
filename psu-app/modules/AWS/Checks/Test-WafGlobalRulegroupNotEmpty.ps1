function Test-WafGlobalRulegroupNotEmpty {
    <#
    .SYNOPSIS
        AWS WAF Classic global rule group has at least one rule

    .DESCRIPTION
        **AWS WAF Classic global rule groups** are assessed for the presence of **one or more rules**. Empty groups are identified even when referenced by a web ACL, meaning the group adds no match logic.

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

    # TODO: Implement check logic based on Prowler check: waf_global_rulegroup_not_empty

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check waf_global_rulegroup_not_empty for reference.', 'N/A', 'waf Resources')
}
