function Disable-CIEMCheck {
    <#
    .SYNOPSIS
        Disables a CIEM security check.

    .DESCRIPTION
        Sets the disabled flag to true for a check in ciem_checks.json,
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

        $ciemChecksPath = Join-Path $script:CIEMModulePath 'ciem_checks.json'
        if (-not (Test-Path $ciemChecksPath)) {
            Write-Error "Checks file not found: $ciemChecksPath"
            return
        }

        $ciemData = Get-Content $ciemChecksPath -Raw | ConvertFrom-Json -AsHashtable
        $modified = $false
    }

    process {
        foreach ($id in $CheckId) {
            $found = $false

            foreach ($providerKey in $ciemData.Keys) {
                for ($i = 0; $i -lt $ciemData[$providerKey].Count; $i++) {
                    if ($ciemData[$providerKey][$i].id -eq $id) {
                        $found = $true

                        if ($ciemData[$providerKey][$i].disabled) {
                            Write-Verbose "Check '$id' is already disabled"
                            break
                        }

                        if ($PSCmdlet.ShouldProcess($id, 'Disable CIEM check')) {
                            $ciemData[$providerKey][$i].disabled = $true
                            $modified = $true
                            Write-Verbose "Disabled check '$id' (provider: $providerKey)"
                        }
                        break
                    }
                }
                if ($found) { break }
            }

            if (-not $found) {
                Write-Error "Check '$id' not found in ciem_checks.json"
            }
        }
    }

    end {
        if ($modified) {
            $ciemData | ConvertTo-Json -Depth 10 | Set-Content -Path $ciemChecksPath -Encoding UTF8
            Write-Verbose "Saved changes to $ciemChecksPath"
        }
    }
}
