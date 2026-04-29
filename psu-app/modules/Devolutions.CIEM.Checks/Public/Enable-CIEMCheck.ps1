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
            $existing = @(Get-CIEMCheck -CheckId $id)
            if ($existing.Count -eq 0) {
                throw "Check '$id' not found."
            }
            if (-not $existing[0].Disabled) {
                Write-Verbose "Check '$id' is already enabled"
                continue
            }
            if ($PSCmdlet.ShouldProcess($id, 'Enable CIEM check')) {
                SetCIEMCheckState -Id $id -Disabled $false
                Write-Verbose "Enabled check '$id'"
            }
        }
    }
}
