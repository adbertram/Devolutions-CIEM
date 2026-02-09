function Test-KeyvaultAccessOnlyThroughPrivateEndpoints {
    <#
    .SYNOPSIS
        Ensure that public network access when using private endpoint is disabled.

    .DESCRIPTION
        Checks if Key Vaults with private endpoints have public network access disabled.

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

    # TODO: Implement check logic based on Prowler check: keyvault_access_only_through_private_endpoints

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check keyvault_access_only_through_private_endpoints for reference.', 'N/A', 'keyvault Resources')
}
