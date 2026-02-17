function Enable-CIEMCheck {
    <#
    .SYNOPSIS
        Enables a CIEM security check.

    .DESCRIPTION
        Sets the disabled flag to false for a check in ciem_checks.json,
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

                        if (-not $ciemData[$providerKey][$i].disabled) {
                            Write-Verbose "Check '$id' is already enabled"
                            break
                        }

                        if ($PSCmdlet.ShouldProcess($id, 'Enable CIEM check')) {
                            $ciemData[$providerKey][$i].disabled = $false
                            $modified = $true
                            Write-Verbose "Enabled check '$id' (provider: $providerKey)"
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
