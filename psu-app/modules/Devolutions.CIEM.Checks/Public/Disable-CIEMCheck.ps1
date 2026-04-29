function Disable-CIEMCheck {
    <#
    .SYNOPSIS
        Disables a CIEM security check.

    .DESCRIPTION
        Sets the disabled flag to true for a check in the SQLite checks table,
        preventing it from running during scans or being selected in the PSU app UI.

    .PARAMETER CheckId
        One or more check IDs to disable (e.g., 'entra_security_defaults_enabled').

    .EXAMPLE
        Disable-CIEMCheck -CheckId 'entra_security_defaults_enabled'
        # Disables a single check

    .EXAMPLE
        @('check_1', 'check_2') | Disable-CIEMCheck
        # Disables multiple checks via pipeline

    .EXAMPLE
        Disable-CIEMCheck -CheckId 'some_check' -WhatIf
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
                Write-Error "Check '$id' not found."
                continue
            }
            if ($existing[0].Disabled) {
                Write-Verbose "Check '$id' is already disabled"
                continue
            }
            if ($PSCmdlet.ShouldProcess($id, 'Disable CIEM check')) {
                SetCIEMCheckState -Id $id -Disabled $true
                Write-Verbose "Disabled check '$id'"
            }
        }
    }
}
