function SyncCIEMCheckCatalog {
    <#
    .SYNOPSIS
        Validates provider check catalogs and seeds mutable check state.

    .DESCRIPTION
        Static check metadata is read from provider catalog files. The SQLite
        checks table stores only mutable state required by scan result foreign
        keys and user enable/disable overrides.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider
    )

    $ErrorActionPreference = 'Stop'

    $catalog = @(GetCIEMCheckCatalog -Provider $Provider)
    $existingRows = @(Invoke-CIEMQuery -Query 'SELECT id, disabled FROM checks')
    $existingById = @{}
    foreach ($row in $existingRows) {
        if ($existingById.ContainsKey($row.id)) {
            throw "Existing check state contains duplicate id '$($row.id)'."
        }
        $existingById[$row.id] = [bool]$row.disabled
    }

    foreach ($entry in $catalog) {
        $disabled = if ($existingById.ContainsKey($entry.Id)) {
            $existingById[$entry.Id]
        }
        else {
            [bool]$entry.Disabled
        }

        SetCIEMCheckState -Id $entry.Id -Disabled $disabled
    }
}
