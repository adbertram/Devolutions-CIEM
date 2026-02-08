function Test-Ec2SecuritygroupAllowIngressFromInternetToTcpPortElasticsearchKibana920093005601 {
    <#
    .SYNOPSIS
        Security group does not allow ingress from 0.0.0.0/0 or ::/0 to Elasticsearch/Kibana TCP ports 9200, 9300, and 5601

    .DESCRIPTION
        **EC2 security groups** restrict public ingress to Elasticsearch/Kibana ports `9200`, `9300`, and `5601`, denying sources `0.0.0.0/0` and `::/0`

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

    # TODO: Implement check logic based on Prowler check: ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_elasticsearch_kibana_9200_9300_5601

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_elasticsearch_kibana_9200_9300_5601 for reference.', 'N/A', 'ec2 Resources')
}
