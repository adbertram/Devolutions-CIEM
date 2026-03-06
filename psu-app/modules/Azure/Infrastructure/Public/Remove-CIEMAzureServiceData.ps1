function Remove-CIEMAzureServiceData {
    <#
    .SYNOPSIS
        Removes Azure service data from the database.
    .DESCRIPTION
        Deletes rows from the azure_service_data table. Supports deleting by
        ProviderId (bulk), by ServiceName, or by specific ResourceId.
    .PARAMETER ProviderId
        Delete all service data for a provider.
    .PARAMETER ServiceName
        Optional service name filter (e.g., 'Defender', 'Monitor').
    .PARAMETER ResourceId
        Optional specific resource ID to delete.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderId,

        [Parameter()]
        [string]$ServiceName,

        [Parameter()]
        [string]$ResourceId
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @("provider_id = @provider_id")
    $params = @{ provider_id = $ProviderId }

    if ($ServiceName) {
        $conditions += "service_name = @service_name"
        $params.service_name = $ServiceName
    }

    if ($ResourceId) {
        $conditions += "resource_id = @resource_id"
        $params.resource_id = $ResourceId
    }

    $target = "azure_service_data for provider '$ProviderId'"
    if ($ServiceName) { $target += " service '$ServiceName'" }
    if ($ResourceId) { $target += " resource '$ResourceId'" }

    if (-not $PSCmdlet.ShouldProcess($target, 'Remove')) {
        return
    }

    $query = "DELETE FROM azure_service_data WHERE $($conditions -join ' AND ')"
    Invoke-CIEMQuery -Query $query -Parameters $params -AsNonQuery | Out-Null
}
