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

    $conn = Open-PSUSQLiteConnection -Database $script:DatabasePath
    try {
        $tx = $conn.BeginTransaction()

        # Enable foreign keys for CASCADE to work
        Invoke-PSUSQLiteQuery -Connection $conn -Query "PRAGMA foreign_keys=ON" -AsNonQuery | Out-Null

        # Delete provider (CASCADE handles auth profiles, collected data, etc.)
        Invoke-PSUSQLiteQuery -Connection $conn -Query "DELETE FROM providers WHERE id = @id" -Parameters @{ id = $providerId } -AsNonQuery | Out-Null

        $tx.Commit()
    }
    catch {
        if ($tx) { $tx.Rollback() }
        throw
    }
    finally {
        $conn.Dispose()
    }
}
