function Test-CIEMCollectedDataExists {
    <#
    .SYNOPSIS
        Tests whether collected data exists for an Azure provider.
    .DESCRIPTION
        Checks the azure_service_data table for any Entra rows matching
        the given provider ID. Returns $true if data exists, $false otherwise.
    .PARAMETER ProviderName
        The provider name (e.g., 'Azure').
    .OUTPUTS
        [bool]
    .EXAMPLE
        Test-CIEMCollectedDataExists -ProviderName 'Azure'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderName
    )

    $result = Invoke-CIEMQuery -Query "SELECT COUNT(*) AS cnt FROM azure_service_data WHERE provider_id = @pid AND service_name = 'Entra'" -Parameters @{ pid = $ProviderName.ToLower() }
    [bool]($result -and $result.cnt -gt 0)
}
