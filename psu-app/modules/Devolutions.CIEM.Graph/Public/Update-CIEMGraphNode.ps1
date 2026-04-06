function Update-CIEMGraphNode {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMGraphNode[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByProperties')]
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

        [Parameter(ParameterSetName = 'ByProperties')]
        [switch]$PassThru,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    process {
        $ErrorActionPreference = 'Stop'

        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $parameters = @{
                    id              = $obj.Id
                    kind            = $obj.Kind
                    display_name    = $obj.DisplayName
                    provider        = $obj.Provider
                    subscription_id = $obj.SubscriptionId
                    resource_group  = $obj.ResourceGroup
                    properties      = $obj.Properties
                    collected_at    = $obj.CollectedAt
                }

                Invoke-CIEMQuery -Query @"
UPDATE graph_nodes
SET kind = @kind, display_name = @display_name, provider = @provider,
    subscription_id = @subscription_id, resource_group = @resource_group,
    properties = @properties, collected_at = @collected_at
WHERE id = @id
"@ -Parameters $parameters -AsNonQuery | Out-Null
            }
            return
        }

        $columnMap = @{
            Kind           = 'kind'
            DisplayName    = 'display_name'
            Provider       = 'provider'
            SubscriptionId = 'subscription_id'
            ResourceGroup  = 'resource_group'
            Properties     = 'properties'
            CollectedAt    = 'collected_at'
        }

        $setClauses = @()
        $parameters = @{ id = $Id }

        foreach ($paramName in $columnMap.Keys) {
            if ($PSBoundParameters.ContainsKey($paramName)) {
                $col = $columnMap[$paramName]
                $setClauses += "$col = @$col"
                $parameters[$col] = $PSBoundParameters[$paramName]
            }
        }

        if ($setClauses.Count -eq 0) {
            return
        }

        $sql = "UPDATE graph_nodes SET " + ($setClauses -join ', ') + " WHERE id = @id"
        Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null

        if ($PassThru) {
            Get-CIEMGraphNode -Id $Id
        }
    }
}
