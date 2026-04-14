function New-CIEMCheckMetadata {
    <#
    .SYNOPSIS
        Creates a check metadata record in the database if it doesn't already exist.

    .DESCRIPTION
        Inserts a record into the checks table. Skips silently if a record with
        the same ID already exists (idempotent).

    .PARAMETER Id
        The check identifier (e.g., 'entra_security_defaults_enabled').

    .PARAMETER Provider
        Cloud provider name (Azure, AWS).

    .PARAMETER Service
        Service display name (e.g., Entra, KeyVault).

    .PARAMETER Title
        Human-readable check title.

    .PARAMETER Severity
        Check severity level.

    .PARAMETER CheckScript
        Filename of the PowerShell check script (e.g., 'Test-EntraSecurityDefaultsEnabled.ps1').

    .EXAMPLE
        New-CIEMCheckMetadata -Id 'entra_security_defaults_enabled' -Provider Azure -Service Entra `
            -Title 'Security defaults enabled' -Severity high -CheckScript 'Test-EntraSecurityDefaultsEnabled.ps1'
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a configuration object in database')]
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Provider,
        [Parameter(Mandatory)][string]$Service,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][ValidateSet('critical','high','medium','low')][string]$Severity,
        [Parameter(Mandatory)][string]$CheckScript,
        [Parameter()][string]$Description,
        [Parameter()][string]$Risk,
        [Parameter()][string]$RemediationText,
        [Parameter()][string]$RemediationUrl,
        [Parameter()][string]$RelatedUrl,
        [Parameter()][bool]$Disabled = $true,
        [Parameter()][string]$Permissions,
        [Parameter()][string[]]$DependsOn,
        [Parameter()][string[]]$DataNeeds
    )

    $ErrorActionPreference = 'Stop'

    $existing = Invoke-CIEMQuery -Query "SELECT id FROM checks WHERE id = @id" -Parameters @{ id = $Id }
    if ($existing) {
        Write-Verbose "Check metadata '$Id' already exists, skipping."
        return
    }

    Save-CIEMCheck @PSBoundParameters
    Write-Verbose "Created check metadata '$Id' in database."
}
