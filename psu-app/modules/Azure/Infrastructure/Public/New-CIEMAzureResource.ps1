function New-CIEMAzureResource {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates data record')]
    [OutputType('CIEMAzureResource[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Type,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ParentId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Name,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Location,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Tags,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureResource[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) { $p = @{ id=$item.Id; provider_id=$item.ProviderId; type=$item.Type; parent_id=$item.ParentId; name=$item.Name; location=$item.Location; tags=$item.Tags; now=$now }; $cId=$item.Id }
            else { $p = @{ id=$Id; provider_id=$ProviderId; type=$Type; parent_id=$ParentId; name=$Name; location=$Location; tags=$Tags; now=$now }; $cId=$Id }
            $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_resources WHERE id = @id" -Parameters @{ id = $cId }
            if ($existing) { throw "Azure resource '$cId' already exists." }
            Invoke-CIEMQuery -Query "INSERT INTO azure_resources (id, provider_id, type, parent_id, name, location, tags, collected_at) VALUES (@id, @provider_id, @type, @parent_id, @name, @location, @tags, @now)" -Parameters $p -AsNonQuery | Out-Null
            Get-CIEMAzureResource -Id $cId
        }
    }
}
