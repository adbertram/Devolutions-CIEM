function Remove-CIEMCheck {
    <#
    .SYNOPSIS
        Removes a CIEM security check.

    .DESCRIPTION
        Removes a check by deleting its entry from ciem_checks.json and
        removing its Test-*.ps1 script file from the Checks/<Provider>/ directory.

    .PARAMETER CheckId
        The check ID to remove (e.g., 'entra_security_defaults_enabled').

    .EXAMPLE
        Remove-CIEMCheck -CheckId 'entra_security_defaults_enabled'
        # Removes the check metadata and script file

    .EXAMPLE
        Get-CIEMCheck -Service Entra | Select-Object -Last 1 | ForEach-Object { Remove-CIEMCheck -CheckId $_.Id }
        # Removes the last Entra check
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$CheckId
    )

    $ErrorActionPreference = 'Stop'

    $ciemChecksPath = Join-Path $script:ModuleRoot 'ciem_checks.json'
    if (-not (Test-Path $ciemChecksPath)) {
        Write-Error "Checks file not found: $ciemChecksPath"
        return
    }

    $ciemData = Get-Content $ciemChecksPath -Raw | ConvertFrom-Json -AsHashtable

    # Search all provider arrays for the check
    $foundProvider = $null
    $foundIndex = -1
    $foundCheck = $null

    foreach ($providerKey in $ciemData.Keys) {
        for ($i = 0; $i -lt $ciemData[$providerKey].Count; $i++) {
            if ($ciemData[$providerKey][$i].id -eq $CheckId) {
                $foundProvider = $providerKey
                $foundIndex = $i
                $foundCheck = $ciemData[$providerKey][$i]
                break
            }
        }
        if ($foundProvider) { break }
    }

    if (-not $foundProvider) {
        Write-Error "Check '$CheckId' not found in ciem_checks.json"
        return
    }

    if (-not $PSCmdlet.ShouldProcess($CheckId, 'Remove CIEM check')) {
        return
    }

    # Remove from the provider array
    $ciemData[$foundProvider] = @($ciemData[$foundProvider] | Where-Object { $_.id -ne $CheckId })
    $ciemData | ConvertTo-Json -Depth 10 | Set-Content -Path $ciemChecksPath -Encoding UTF8
    Write-Verbose "Removed '$CheckId' from ciem_checks.json (provider: $foundProvider)"

    # Delete the script file
    if ($foundCheck.checkScript) {
        $providerDisplayName = (Get-Culture).TextInfo.ToTitleCase($foundProvider)
        $scriptPath = Join-Path -Path $script:ModuleRoot -ChildPath $script:Config.checksPath -AdditionalChildPath $providerDisplayName, $foundCheck.checkScript

        if (Test-Path $scriptPath) {
            Remove-Item -Path $scriptPath -Force
            Write-Verbose "Deleted script: $scriptPath"
        } else {
            Write-Warning "Script file not found (already deleted?): $scriptPath"
        }
    }
}
