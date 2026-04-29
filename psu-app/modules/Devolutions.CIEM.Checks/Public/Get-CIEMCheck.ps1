function Get-CIEMCheck {
    <#
    .SYNOPSIS
        Lists available CIEM security checks.

    .DESCRIPTION
        Reads static check metadata from provider catalogs and overlays mutable
        disabled state from the SQLite checks table.

	        Returns PSCustomObjects (not class instances) to ensure compatibility
	        with PSU runspaces where PowerShell class types may not be available.

    .PARAMETER Provider
        Filter checks by cloud provider (Azure, AWS).

    .PARAMETER Service
        Filter checks by service name (e.g., Entra, IAM, KeyVault, Storage, iam, s3).

    .PARAMETER Severity
        Filter checks by severity level (critical, high, medium, low).

    .PARAMETER CheckId
        Filter to one or more checks by ID. Accepts a single string or an array.

    .OUTPUTS
        [PSCustomObject[]] Array of check objects with properties:
	        Id, Provider, Service, Title, Description, Risk, Severity,
	        Remediation, RelatedUrl, CheckScript, ExecutionMode, ManualReason,
	        Evaluator, EvaluatorConfig, DependsOn, DataNeeds, Permissions.

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
        [string[]]$CheckId
    )

    $ErrorActionPreference = 'Stop'

    $catalogRows = @(GetCIEMCheckCatalog -Provider $Provider)
    $stateRows = @(Invoke-CIEMQuery -Query 'SELECT id, disabled FROM checks')
    $stateById = @{}
    foreach ($stateRow in $stateRows) {
        $stateById[$stateRow.id] = [bool]$stateRow.disabled
    }

    $checks = @(foreach ($row in $catalogRows) {
        if ($Service -and $row.Service -ne $Service) {
            continue
        }
        if ($Severity -and $row.Severity -ne $Severity) {
            continue
        }
        if ($CheckId -and $CheckId -notcontains $row.Id) {
            continue
        }

        [PSCustomObject]@{
            Id          = $row.Id
            Provider    = $row.Provider
            Service     = $row.Service
            Title       = $row.Title
            Description = $row.Description
            Risk        = $row.Risk
            Severity    = $row.Severity
            Remediation = [PSCustomObject]@{
                Text = $row.Remediation.Text
                Url  = $row.Remediation.Url
            }
            RelatedUrl      = $row.RelatedUrl
            CheckScript     = $row.CheckScript
            ExecutionMode   = $row.ExecutionMode
            ManualReason    = $row.ManualReason
            Evaluator       = $row.Evaluator
            EvaluatorConfig = $row.EvaluatorConfig
            DependsOn       = @($row.DependsOn)
            DataNeeds       = if ($null -ne $row.DataNeeds) { @($row.DataNeeds) } else { $null }
            Disabled        = if ($stateById.ContainsKey($row.Id)) { $stateById[$row.Id] } else { [bool]$row.Disabled }
            Permissions     = $row.Permissions
        }
    })

    $checks
}
