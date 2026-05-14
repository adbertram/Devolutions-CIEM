function Update-CIEMProvider {
    <#
    .SYNOPSIS
        Updates an existing CIEM cloud provider.

    .DESCRIPTION
        Modifies properties of a provider in the CIEM SQLite database.
        Only specified parameters are updated; unspecified ones are preserved.

        Authentication context is managed separately via generic authentication
        profile assignments.

    .PARAMETER Name
        Provider name to update (case-insensitive).

    .PARAMETER Enabled
        Whether the provider is enabled.

    .PARAMETER PassThru
        Returns the updated provider object. By default, this function produces no output.

    .OUTPUTS
        [CIEMProvider] When -PassThru is specified, the updated provider object with computed CheckCount.

    .EXAMPLE
        Update-CIEMProvider -Name 'GCP' -Enabled $true
    #>
    [CmdletBinding()]
    [OutputType('CIEMProvider')]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [bool]$Enabled,

        [Parameter()]
        [switch]$PassThru
    )

    $ErrorActionPreference = 'Stop'

    $providerId = $Name.ToLower()
    $now = (Get-Date).ToString('o')

    # Verify provider exists
    $existing = Invoke-CIEMQuery -Query "SELECT id, type FROM providers WHERE id = @id" -Parameters @{ id = $providerId }
    if (-not $existing) {
        throw "Provider '$Name' not found. Use New-CIEMProvider to create it."
    }

    # Update enabled flag
    if ($PSBoundParameters.ContainsKey('Enabled')) {
        Invoke-CIEMQuery -Query "UPDATE providers SET enabled = @enabled, updated_at = @now WHERE id = @id" -Parameters @{
            id = $providerId; enabled = if ($Enabled) { 1 } else { 0 }; now = $now
        } -AsNonQuery | Out-Null
    }

    if ($PassThru) {
        Get-CIEMProvider -Name $Name
    }
}
