function Save-CIEMGraphNode {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation for bulk data')]
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
        [PSObject[]]$InputObject,

        [Parameter()]
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    process {
        $ErrorActionPreference = 'Stop'

        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $collectedAt = if ($obj.CollectedAt) { $obj.CollectedAt } else { (Get-Date).ToString('o') }
                $provider = if ($obj.Provider) { $obj.Provider } else { 'azure' }
                $parameters = @{
                    id              = $obj.Id
                    kind            = $obj.Kind
                    display_name    = $obj.DisplayName
                    provider        = $provider
                    subscription_id = $obj.SubscriptionId
                    resource_group  = $obj.ResourceGroup
                    properties      = $obj.Properties
                    collected_at    = $collectedAt
                }

                $sql = @"
INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, subscription_id, resource_group, properties, collected_at)
VALUES (@id, @kind, @display_name, @provider, @subscription_id, @resource_group, @properties, @collected_at)
"@

                if ($Connection) {
                    Invoke-PSUSQLiteQuery -Connection $Connection -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
                } else {
                    Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
                }
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

        $sql = @"
INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, subscription_id, resource_group, properties, collected_at)
VALUES (@id, @kind, @display_name, @provider, @subscription_id, @resource_group, @properties, @collected_at)
"@

        if ($Connection) {
            Invoke-PSUSQLiteQuery -Connection $Connection -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
        } else {
            Invoke-CIEMQuery -Query $sql -Parameters $parameters -AsNonQuery | Out-Null
        }
    }
}
