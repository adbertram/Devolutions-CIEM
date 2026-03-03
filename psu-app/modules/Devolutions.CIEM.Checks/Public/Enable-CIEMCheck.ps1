function Enable-CIEMCheck {
    <#
    .SYNOPSIS
        Enables a CIEM security check.

    .DESCRIPTION
        Sets the disabled flag to false for a check in the SQLite checks table,
        allowing it to run during scans and be selected in the PSU app UI.

    .PARAMETER CheckId
        One or more check IDs to enable (e.g., 'entra_security_defaults_enabled').

    .EXAMPLE
        Enable-CIEMCheck -CheckId 'entra_security_defaults_enabled'
        # Enables a single check

    .EXAMPLE
        @('check_1', 'check_2') | Enable-CIEMCheck
        # Enables multiple checks via pipeline

    .EXAMPLE
        Enable-CIEMCheck -CheckId 'some_check' -WhatIf
        # Shows what would happen without making changes
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string[]]$CheckId
    )

    begin {
        $ErrorActionPreference = 'Stop'
    }

    process {
        foreach ($id in $CheckId) {
            $existing = Invoke-CIEMQuery -Query "SELECT id, disabled FROM checks WHERE id = @id" -Parameters @{ id = $id }
            if (-not $existing) {
                Write-Error "Check '$id' not found."
                continue
            }
            if (-not $existing.disabled) {
                Write-Verbose "Check '$id' is already enabled"
                continue
            }
            if ($PSCmdlet.ShouldProcess($id, 'Enable CIEM check')) {
                Invoke-CIEMQuery -Query "UPDATE checks SET disabled = 0 WHERE id = @id" -Parameters @{ id = $id } -AsNonQuery | Out-Null
                Write-Verbose "Enabled check '$id'"
            }
        }
    }
}
