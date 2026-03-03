function Test-CIEMCollectedDataExists {
    <#
    .SYNOPSIS
        Tests whether collected data exists for an Azure provider.
    .DESCRIPTION
        Checks the azure_security_principals table for any rows matching
        the given provider ID. Returns $true if data exists, $false otherwise.

        This is the provider module's implementation of the standard interface
        that PSU uses to discover which providers have graph data available.
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

    $result = Invoke-CIEMQuery -Query "SELECT COUNT(*) AS cnt FROM azure_security_principals WHERE provider_id = @pid" -Parameters @{ pid = $ProviderName.ToLower() }
    [bool]($result -and $result.cnt -gt 0)
}
