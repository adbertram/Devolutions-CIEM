function New-CIEMGraphNode {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a data record in database')]
    [OutputType('CIEMGraphNode[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Kind,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$DisplayName,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Provider,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$SubscriptionId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ResourceGroup,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Properties,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        $ErrorActionPreference = 'Stop'

        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $splat = @{
                    Id            = $obj.Id
                    Kind          = $obj.Kind
                    DisplayName   = $obj.DisplayName
                    Provider      = $obj.Provider
                    SubscriptionId = $obj.SubscriptionId
                    ResourceGroup = $obj.ResourceGroup
                    Properties    = $obj.Properties
                    CollectedAt   = $obj.CollectedAt
                }
                New-CIEMGraphNode @splat
            }
            return
        }

        if (-not $CollectedAt) {
            $CollectedAt = (Get-Date).ToString('o')
        }

        if (-not $Provider) {
            $Provider = 'azure'
        }

        $parameters = @{
            id              = $Id
            kind            = $Kind
            display_name    = $DisplayName
            provider        = $Provider
            subscription_id = $SubscriptionId
            resource_group  = $ResourceGroup
            properties      = $Properties
            collected_at    = $CollectedAt
        }

        Invoke-CIEMQuery -Query @"
INSERT INTO graph_nodes (id, kind, display_name, provider, subscription_id, resource_group, properties, collected_at)
VALUES (@id, @kind, @display_name, @provider, @subscription_id, @resource_group, @properties, @collected_at)
"@ -Parameters $parameters -AsNonQuery | Out-Null

        Get-CIEMGraphNode -Id $Id
    }
}
