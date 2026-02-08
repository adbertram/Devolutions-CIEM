function Get-CIEMCheck {
    <#
    .SYNOPSIS
        Lists available CIEM security checks.

    .DESCRIPTION
        Reads check metadata from the centralized ciem_checks.json file.
        The file contains provider-keyed arrays (azure, aws) of check objects.

    .PARAMETER CloudProvider
        Filter checks by cloud provider (Azure, AWS).

    .PARAMETER Service
        Filter checks by service name (e.g., Entra, IAM, KeyVault, Storage, iam, s3).

    .PARAMETER Severity
        Filter checks by severity level (critical, high, medium, low).

    .PARAMETER CheckId
        Filter to a specific check by ID.

    .OUTPUTS
        [CIEMCheck[]] Array of CIEMCheck objects.

    .EXAMPLE
        Get-CIEMCheck
        # Returns all checks across all providers

    .EXAMPLE
        Get-CIEMCheck -CloudProvider AWS
        # Returns all AWS checks

    .EXAMPLE
        Get-CIEMCheck -Service Entra -Severity high
        # Returns high-severity Entra checks

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
        [string]$Service,

        [Parameter()]
        [ValidateSet('critical', 'high', 'medium', 'low')]
        [string]$Severity,

        [Parameter()]
        [string]$CheckId
    )

    $ErrorActionPreference = 'Stop'

    $checksPath = Join-Path $script:ModuleRoot 'ciem_checks.json'
    if (-not (Test-Path $checksPath)) {
        Write-Warning "Checks file not found: $checksPath"
        return @()
    }

    $allData = Get-Content $checksPath -Raw | ConvertFrom-Json
    # Use ArrayList instead of List[CIEMCheck] to avoid type identity issues
    # when Import-Module -Force recreates class types in PSU runspaces
    $checks = [System.Collections.ArrayList]::new()

    foreach ($providerName in $allData.PSObject.Properties.Name) {
        try {
            $providerEnum = [CIEMCloudProvider]$providerName
        } catch {
            Write-Warning "Unknown provider '$providerName' in ciem_checks.json, skipping."
            continue
        }
        foreach ($jsonObj in @($allData.$providerName)) {
            if ($null -eq $jsonObj) { continue }
            try {
                $check = [CIEMCheck]::FromJsonObject($jsonObj, $providerEnum)
                $null = $checks.Add($check)
            } catch {
                Write-Warning "Failed to parse check '$($jsonObj.id)' for provider '$providerName': $_"
            }
        }
    }

    # Apply filters
    $result = @($checks)

    if ($CloudProvider) {
        $result = $result | Where-Object { $_.CloudProvider -eq $CloudProvider }
    }

    if ($Service) {
        $result = $result | Where-Object { $_.Service -eq $Service }
    }

    if ($Severity) {
        $result = $result | Where-Object { $_.Severity -eq $Severity }
    }

    if ($CheckId) {
        $result = $result | Where-Object { $_.Id -eq $CheckId }
    }

    $result
}
