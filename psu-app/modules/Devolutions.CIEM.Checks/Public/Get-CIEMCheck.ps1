function Get-CIEMCheck {
    <#
    .SYNOPSIS
        Lists available CIEM security checks.

    .DESCRIPTION
        Reads check metadata exclusively from the SQLite database (checks table).

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

    # Build parameterized query with filters
    $conditions = @()
    $params = @{}

    if ($PSBoundParameters.ContainsKey('Provider')) {
        $conditions += "provider = @provider"
        $params.provider = $Provider
    }

    if ($Service) {
        $conditions += "service = @service"
        $params.service = $Service
    }

    if ($Severity) {
        $conditions += "severity = @severity"
        $params.severity = $Severity
    }

    if ($CheckId) {
        $conditions += "id = @id"
        $params.id = $CheckId
    }

    $query = "SELECT * FROM checks"
    if ($conditions.Count -gt 0) {
        $query += " WHERE " + ($conditions -join ' AND ')
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)

    # Convert rows to the expected PSCustomObject shape
    $checks = @(foreach ($row in $rows) {
        # Parse permissions JSON
        $permissionsObj = & {
            $p = @{ Graph = @(); ARM = @(); KeyVaultDataPlane = @(); IAM = @() }
            if ($row.permissions) {
                try {
                    $raw = $row.permissions | ConvertFrom-Json
                    foreach ($prop in $raw.PSObject.Properties) {
                        switch ($prop.Name.ToLower()) {
                            'graph'             { $p.Graph = @($prop.Value) }
                            'arm'               { $p.ARM = @($prop.Value) }
                            'keyvaultdataplane' { $p.KeyVaultDataPlane = @($prop.Value) }
                            'iam'               { $p.IAM = @($prop.Value) }
                        }
                    }
                } catch {
                    Write-Verbose "Failed to parse permissions JSON for check $($row.id): $_"
                }
            }
            [PSCustomObject]$p
        }

        # Parse depends_on JSON
        $dependsOnArr = @()
        if ($row.depends_on) {
            try {
                $dependsOnArr = @($row.depends_on | ConvertFrom-Json)
            } catch {
                Write-Verbose "Failed to parse depends_on JSON for check $($row.id): $_"
            }
        }

        [PSCustomObject]@{
            Id          = $row.id
            Provider    = $row.provider
            Service     = $row.service
            Title       = $row.title
            Description = $row.description
            Risk        = $row.risk
            Severity    = $row.severity
            Remediation = [PSCustomObject]@{
                Text = $row.remediation_text
                Url  = $row.remediation_url
            }
            RelatedUrl  = $row.related_url
            CheckScript = $row.check_script
            DependsOn   = $dependsOnArr
            Disabled    = [bool]$row.disabled
            Permissions = $permissionsObj
        }
    })

    $checks
}
