function Get-CIEMCheck {
    <#
    .SYNOPSIS
        Lists available CIEM security checks.

    .DESCRIPTION
        Reads check metadata from the centralized ciem_checks.json file.
        The file contains provider-keyed arrays (azure, aws) of check objects.

        Returns PSCustomObjects (not class instances) to ensure compatibility
        with PSU runspaces where PowerShell class types may not be available.

    .PARAMETER Provider
        Filter checks by cloud provider (Azure, AWS).

    .PARAMETER Service
        Filter checks by service name (e.g., Entra, IAM, KeyVault, Storage, iam, s3).

    .PARAMETER Severity
        Filter checks by severity level (critical, high, medium, low).

    .PARAMETER CheckId
        Filter to a specific check by ID.

    .OUTPUTS
        [PSCustomObject[]] Array of check objects with properties:
        Id, Provider, Service, Title, Description, Risk, Severity,
        Remediation, RelatedUrl, CheckScript, DependsOn, Permissions.

    .EXAMPLE
        Get-CIEMCheck
        # Returns all checks across all providers

    .EXAMPLE
        Get-CIEMCheck -Provider AWS
        # Returns all AWS checks

    .EXAMPLE
        Get-CIEMCheck -Service Entra -Severity high
        # Returns high-severity Entra checks

    .EXAMPLE
        Get-CIEMCheck -CheckId 'entra_security_defaults_enabled'
        # Returns specific check details
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Provider,

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
    $checks = [System.Collections.ArrayList]::new()

    # Map JSON provider keys to display names
    $providerMap = @{ 'azure' = 'Azure'; 'aws' = 'AWS' }

    foreach ($providerName in $allData.PSObject.Properties.Name) {
        $providerDisplay = $providerMap[$providerName]
        if (-not $providerDisplay) {
            Write-Warning "Unknown provider '$providerName' in ciem_checks.json, skipping."
            continue
        }

        foreach ($jsonObj in @($allData.$providerName)) {
            if ($null -eq $jsonObj) { continue }

            $null = $checks.Add([PSCustomObject]@{
                Id            = $jsonObj.id
                Provider      = $providerDisplay
                Service       = $jsonObj.service
                Title         = $jsonObj.title
                Description   = $jsonObj.description
                Risk          = $jsonObj.risk
                Severity      = [string]$jsonObj.severity
                Remediation   = [PSCustomObject]@{
                    Text = $jsonObj.remediation.text
                    Url  = $jsonObj.remediation.url
                }
                RelatedUrl    = $jsonObj.relatedUrl
                CheckScript   = $jsonObj.checkScript
                DependsOn     = @($jsonObj.dependsOn | Where-Object { $_ })
                Permissions   = & {
                    $raw = $jsonObj.permissions
                    $p = @{ Graph = @(); ARM = @(); KeyVaultDataPlane = @(); IAM = @() }
                    if ($null -ne $raw) {
                        foreach ($prop in $raw.PSObject.Properties) {
                            switch ($prop.Name.ToLower()) {
                                'graph'             { $p.Graph = @($prop.Value) }
                                'arm'               { $p.ARM = @($prop.Value) }
                                'keyvaultdataplane' { $p.KeyVaultDataPlane = @($prop.Value) }
                                'iam'               { $p.IAM = @($prop.Value) }
                            }
                        }
                    }
                    [PSCustomObject]$p
                }
            })
        }
    }

    # Apply filters
    $result = @($checks)

    if ($PSBoundParameters.ContainsKey('Provider')) {
        $result = $result | Where-Object { $_.Provider -eq $Provider }
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
