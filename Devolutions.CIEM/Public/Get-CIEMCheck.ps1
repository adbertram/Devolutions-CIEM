function Get-CIEMCheck {
    <#
    .SYNOPSIS
        Lists available CIEM security checks.

    .DESCRIPTION
        Returns a list of all available security checks from the AzureChecks.json
        metadata file. Supports filtering by service, severity, and check ID.

    .PARAMETER Service
        Filter checks by service name (Entra, IAM, KeyVault, Storage).

    .PARAMETER Severity
        Filter checks by severity level (critical, high, medium, low).

    .PARAMETER CheckId
        Filter to a specific check by ID.

    .OUTPUTS
        [PSCustomObject[]] Array of check objects with properties:
        - id: Check identifier
        - service: Service name
        - title: Check title
        - description: Full description
        - severity: Severity level
        - categories: Category tags

    .EXAMPLE
        Get-CIEMCheck
        # Returns all 46 checks

    .EXAMPLE
        Get-CIEMCheck -Service Entra
        # Returns 15 Entra ID checks

    .EXAMPLE
        Get-CIEMCheck -Severity high
        # Returns all high-severity checks

    .EXAMPLE
        Get-CIEMCheck -CheckId 'entra_security_defaults_enabled'
        # Returns specific check details
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateSet('Entra', 'IAM', 'KeyVault', 'Storage')]
        [string]$Service,

        [Parameter()]
        [ValidateSet('critical', 'high', 'medium', 'low')]
        [string]$Severity,

        [Parameter()]
        [string]$CheckId
    )

    $ErrorActionPreference = 'Stop'

    # Load checks metadata
    $checksPath = Join-Path $PSScriptRoot '../AzureChecks.json'

    if (-not (Test-Path $checksPath)) {
        throw "Checks metadata file not found: $checksPath"
    }

    $metadata = Get-Content $checksPath -Raw | ConvertFrom-Json
    $checks = $metadata

    # Handle both array and object with checks property
    if ($metadata.PSObject.Properties.Name -contains 'checks') {
        $checks = $metadata.checks
    }

    # Apply filters
    if ($Service) {
        $checks = $checks | Where-Object { $_.service -eq $Service }
    }

    if ($Severity) {
        $checks = $checks | Where-Object { $_.severity -eq $Severity }
    }

    if ($CheckId) {
        $checks = $checks | Where-Object { $_.id -eq $CheckId }
    }

    $checks
}
