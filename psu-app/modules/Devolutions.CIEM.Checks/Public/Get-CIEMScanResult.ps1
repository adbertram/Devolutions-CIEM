function Get-CIEMScanResult {
    <#
    .SYNOPSIS
        Retrieves scan results for a specific ScanRun from the database.
    .DESCRIPTION
        Retrieves the scan results for a given ScanRunId by joining scan_results
        with checks to reconstruct the full result objects.
    .PARAMETER ScanRunId
        The ID of the ScanRun to get results for (required).
    .EXAMPLE
        $scanRun = Get-CIEMScanRun | Select-Object -First 1
        $results = Get-CIEMScanResult -ScanRunId $scanRun.Id
    .EXAMPLE
        $failed = Get-CIEMScanResult -ScanRunId $scanRun.Id | Where-Object { $_.Status -eq 'FAIL' }
    .OUTPUTS
        [PSCustomObject[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScanRunId
    )

    $ErrorActionPreference = 'Stop'

    $rows = @(Invoke-CIEMQuery -Query @"
SELECT sr.status, sr.status_extended, sr.resource_id, sr.resource_name, sr.location,
       c.id AS check_id, c.provider, c.service, c.title, c.description, c.risk, c.severity,
       c.remediation_text, c.remediation_url, c.related_url, c.check_script, c.disabled,
       c.permissions, c.depends_on
FROM scan_results sr
JOIN checks c ON sr.check_id = c.id
WHERE sr.scan_run_id = @scan_run_id
"@ -Parameters @{ scan_run_id = $ScanRunId })

    if ($rows.Count -eq 0) {
        Write-Verbose "No results found for ScanRunId: $ScanRunId"
        return @()
    }

    $results = @(foreach ($row in $rows) {
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
                } catch {}
            }
            [PSCustomObject]$p
        }

        # Parse depends_on JSON
        $dependsOnArr = @()
        if ($row.depends_on) {
            try { $dependsOnArr = @($row.depends_on | ConvertFrom-Json) } catch {}
        }

        [PSCustomObject]@{
            Check = [PSCustomObject]@{
                Id          = $row.check_id
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
            Status         = $row.status
            StatusExtended = $row.status_extended
            ResourceId     = $row.resource_id
            ResourceName   = $row.resource_name
            Location       = $row.location
        }
    })

    $results
}
