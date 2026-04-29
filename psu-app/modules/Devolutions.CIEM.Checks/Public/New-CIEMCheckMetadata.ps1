function New-CIEMCheckMetadata {
    <#
    .SYNOPSIS
        Rejects database-backed check metadata creation.

    .DESCRIPTION
        Static check metadata is provider-catalog-owned. The SQLite checks table
        stores only mutable enable/disable state.

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

    throw "Static check metadata is defined in provider catalogs. Add or update the provider check catalog instead of calling New-CIEMCheckMetadata."
}
