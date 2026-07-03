function GetCIEMAzureDiscoveryCoverageReportData {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$RunId
    )

    $ErrorActionPreference = 'Stop'

    $coverageAreaPath = Join-Path $script:AzureDiscoveryRoot 'Data/discovery_coverage_areas.json'
    if (-not (Test-Path $coverageAreaPath)) {
        throw "Discovery coverage area map was not found at $coverageAreaPath."
    }

    $coverageAreas = @(Get-Content $coverageAreaPath -Raw | ConvertFrom-Json -ErrorAction Stop)
    if ($coverageAreas.Count -eq 0) {
        throw "Discovery coverage area map contains no areas."
    }

    if ($PSBoundParameters.ContainsKey('RunId')) {
        $runRows = @(Invoke-CIEMQuery -Query 'SELECT * FROM azure_discovery_runs WHERE id = @id' -Parameters @{ id = $RunId })
        if ($runRows.Count -eq 0) {
            throw "Discovery run $RunId was not found."
        }
    }
    else {
        $runRows = @(Invoke-CIEMQuery -Query "SELECT * FROM azure_discovery_runs WHERE completed_at IS NOT NULL AND completed_at <> '' ORDER BY julianday(started_at) DESC, id DESC LIMIT 1")
        if ($runRows.Count -eq 0) {
            throw "No completed discovery run was found."
        }
    }

    $run = $runRows[0]
    $errorEntries = @()
    if ($run.error_message) {
        $errorEntries = @($run.error_message -split ';\s*' | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })
    }

    $rows = @(foreach ($area in $coverageAreas) {
        foreach ($requiredProperty in @('area', 'sourceApi', 'runScopes', 'errorPrefixes')) {
            if (-not $area.PSObject.Properties[$requiredProperty]) {
                throw "Discovery coverage area map entry is missing required property '$requiredProperty'."
            }
        }

        $typeCount = 0
        $rowCount = 0
        $evidence = $null
        $missingReason = $null

        if ($area.PSObject.Properties['runTypeCountColumn']) {
            $typeCountProperty = $run.PSObject.Properties[$area.runTypeCountColumn]
            if (-not $typeCountProperty) {
                throw "Discovery run row is missing count column '$($area.runTypeCountColumn)'."
            }
            $typeCount = [int]$typeCountProperty.Value
        }

        if ($area.PSObject.Properties['runRowCountColumn']) {
            $rowCountProperty = $run.PSObject.Properties[$area.runRowCountColumn]
            if (-not $rowCountProperty) {
                throw "Discovery run row is missing count column '$($area.runRowCountColumn)'."
            }
            $rowCount = [int]$rowCountProperty.Value
        }

        if ($area.PSObject.Properties['countTable']) {
            if ($area.countTable -notmatch '^[a-z_]+$') {
                throw "Discovery coverage area '$($area.area)' has invalid count table '$($area.countTable)'."
            }
            $countRows = @(Invoke-CIEMQuery -Query "SELECT COUNT(*) AS row_count FROM $($area.countTable)")
            $rowCount = [int]$countRows[0].row_count
        }

        if ($area.PSObject.Properties['resourceTypeApiSource']) {
            $typeRows = @(Invoke-CIEMQuery -Query 'SELECT type, resource_count FROM azure_resource_types WHERE api_source = @api_source ORDER BY type' -Parameters @{ api_source = $area.resourceTypeApiSource })
            if ($typeRows.Count -gt 0) {
                $evidence = (($typeRows | ForEach-Object { "$($_.type)=$($_.resource_count)" }) -join '; ')
            }
        }
        elseif ($area.PSObject.Properties['evidenceLabel']) {
            $evidence = "$($area.evidenceLabel)=$rowCount"
        }

        $inScope = @($area.runScopes) -contains $run.scope
        if (-not $inScope) {
            $status = 'Skipped'
            $missingReason = "Run scope $($run.scope) did not include this area"
        }
        else {
            $matchedErrors = @(
                foreach ($entry in $errorEntries) {
                    foreach ($prefix in @($area.errorPrefixes)) {
                        if ($entry.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                            $entry
                        }
                    }
                }
            )

            if ($matchedErrors.Count -gt 0) {
                $missingReason = $matchedErrors[0]
                $status = if ($rowCount -gt 0) { 'Partial' } else { 'Missing' }
            }
            else {
                $status = 'Collected'
            }
        }

        $report = [CIEMAzureDiscoveryCoverageReport]::new()
        $report.Provider = 'Azure'
        $report.RunId = [int]$run.id
        $report.Scope = $run.scope
        $report.Area = $area.area
        $report.SourceApi = $area.sourceApi
        $report.Status = $status
        $report.TypeCount = $typeCount
        $report.RowCount = $rowCount
        $report.MissingReason = $missingReason
        $report.Evidence = $evidence
        $report
    })

    [pscustomobject]@{
        Rows = $rows
        Context = @{
            RunId = [int]$run.id
            Scope = $run.scope
            Status = $run.status
            ContextChipKeys = @('RunId', 'Scope', 'Status')
        }
    }
}
