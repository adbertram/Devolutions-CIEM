function Get-CIEMCheck {
    <#
    .SYNOPSIS
        Lists available CIEM security checks.

    .DESCRIPTION
        Returns a list of all available security checks from the AzureChecks.json
        metadata file as typed CIEMCheck objects. Supports filtering by cloud provider,
        service, severity, and check ID.

    .PARAMETER CloudProvider
        Filter checks by cloud provider (Azure, AWS).

    .PARAMETER Service
        Filter checks by service name (Entra, IAM, KeyVault, Storage).

    .PARAMETER Severity
        Filter checks by severity level (critical, high, medium, low).

    .PARAMETER CheckId
        Filter to a specific check by ID.

    .OUTPUTS
        [CIEMCheck[]] Array of CIEMCheck objects.

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
    [OutputType([CIEMCheck[]])]
    param(
        [Parameter()]
        [ValidateSet('Azure', 'AWS')]
        [string]$CloudProvider,

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

    # Load checks from JSON
    $checksPath = Join-Path $script:ModuleRoot 'AzureChecks.json'

    if (-not (Test-Path $checksPath)) {
        throw "Checks metadata file not found: $checksPath"
    }

    $metadata = Get-Content $checksPath -Raw | ConvertFrom-Json

    # Handle both array format and object-with-checks-property format
    $jsonChecks = if ($metadata.PSObject.Properties.Name -contains 'checks') {
        @($metadata.checks)
    }
    else {
        @($metadata)
    }

    # Convert to typed CIEMCheck objects
    $checks = @($jsonChecks | ForEach-Object {
        [CIEMCheck]::FromJsonObject($_, [CIEMCloudProvider]::Azure)
    })

    # Apply filters
    if ($CloudProvider) {
        $checks = $checks | Where-Object { $_.CloudProvider -eq $CloudProvider }
    }

    if ($Service) {
        $checks = $checks | Where-Object { $_.Service -eq $Service }
    }

    if ($Severity) {
        $checks = $checks | Where-Object { $_.Severity -eq $Severity }
    }

    if ($CheckId) {
        $checks = $checks | Where-Object { $_.Id -eq $CheckId }
    }

    $checks
}
