function Test-DefenderAutoProvisioningLogAnalyticsAgentVmsOn {
    <#
    .SYNOPSIS
        Defender auto-provisioning of Log Analytics agent for Azure VMs is enabled

    .DESCRIPTION
        **Microsoft Defender for Cloud** auto-provisioning of the **Log Analytics agent** to Azure VMs is configured to `On` at the subscription level

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

    # TODO: Implement check logic based on Prowler check: defender_auto_provisioning_log_analytics_agent_vms_on

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check defender_auto_provisioning_log_analytics_agent_vms_on for reference.', 'N/A', 'defender Resources')
}
