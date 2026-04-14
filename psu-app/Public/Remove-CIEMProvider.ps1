function Remove-CIEMProvider {
    <#
    .SYNOPSIS
        Removes a CIEM cloud provider.

    .DESCRIPTION
        Removes a provider from the CIEM SQLite database. CASCADE constraints
        automatically remove associated auth profiles.

    .PARAMETER Name
        Provider name to remove (case-insensitive).

    .OUTPUTS
        None.

    .EXAMPLE
        Remove-CIEMProvider -Name 'GCP' -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    $providerId = $Name.ToLower()

    # Verify provider exists
    $existing = Invoke-CIEMQuery -Query "SELECT id FROM providers WHERE id = @id" -Parameters @{ id = $providerId }
    if (-not $existing) {
        throw "Provider '$Name' not found."
    }

    if (-not $PSCmdlet.ShouldProcess($Name, 'Remove CIEM provider')) {
        return
    }

    Write-CIEMLog -Message "DELETE providers WHERE id='$providerId' (CASCADE) (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-Provider'

    InvokeCIEMTransaction {
        param($conn)
        Invoke-PSUSQLiteQuery -Connection $conn -Query "DELETE FROM providers WHERE id = @id" -Parameters @{ id = $providerId } -AsNonQuery | Out-Null
    }
}
