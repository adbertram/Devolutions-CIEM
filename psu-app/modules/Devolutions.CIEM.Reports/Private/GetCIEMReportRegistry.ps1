function GetCIEMReportRegistry {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $registryPath = Join-Path $script:ReportsRoot 'Data/reports.json'
    if (-not (Test-Path $registryPath)) {
        throw "CIEM report registry was not found at $registryPath."
    }

    $entries = @(Get-Content $registryPath -Raw | ConvertFrom-Json -Depth 20 -ErrorAction Stop)
    if ($entries.Count -eq 0) {
        throw 'CIEM report registry contains no reports.'
    }

    TestCIEMReportRegistry -Entries $entries | Out-Null
    $entries
}

function TestCIEMReportRegistry {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$Entries
    )

    $ErrorActionPreference = 'Stop'

    if ($null -eq $Entries) {
        $registryPath = Join-Path $script:ReportsRoot 'Data/reports.json'
        if (-not (Test-Path $registryPath)) {
            throw "CIEM report registry was not found at $registryPath."
        }
        $Entries = @(Get-Content $registryPath -Raw | ConvertFrom-Json -Depth 20 -ErrorAction Stop)
    }

    if ($Entries.Count -eq 0) {
        throw 'CIEM report registry contains no reports.'
    }

    $allowedFields = @(
        'id',
        'provider',
        'category',
        'title',
        'description',
        'executorName',
        'columns',
        'visuals',
        'parameters',
        'statusSummary',
        'emptyState'
    )
    $allowedVisuals = @(
        'coverage-status-summary',
        'coverage-row-table'
    )
    $seenIds = @{}

    foreach ($entry in $Entries) {
        $properties = @($entry.PSObject.Properties.Name | Sort-Object)
        $unexpectedFields = @($properties | Where-Object { $_ -notin $allowedFields })
        if ($unexpectedFields.Count -gt 0) {
            throw "CIEM report registry entry has unknown field(s): $($unexpectedFields -join ', ')."
        }

        $missingFields = @($allowedFields | Where-Object { $_ -notin $properties })
        if ($missingFields.Count -gt 0) {
            throw "CIEM report registry entry is missing required field(s): $($missingFields -join ', ')."
        }

        foreach ($property in @('id', 'provider', 'category', 'title', 'description', 'executorName', 'emptyState')) {
            if ([string]::IsNullOrWhiteSpace([string]$entry.$property)) {
                throw "CIEM report registry entry '$($entry.id)' has empty '$property'."
            }
        }

        if ($seenIds.ContainsKey([string]$entry.id)) {
            throw "CIEM report registry contains duplicate id '$($entry.id)'."
        }
        $seenIds[[string]$entry.id] = $true

        $executorCommand = Get-Command -Name ([string]$entry.executorName) -CommandType Function -ErrorAction Stop

        if (@($entry.columns).Count -eq 0) {
            throw "CIEM report '$($entry.id)' has no columns."
        }

        if (@($entry.visuals).Count -eq 0) {
            throw "CIEM report '$($entry.id)' has no visuals."
        }

        foreach ($visual in @($entry.visuals)) {
            if ([string]$visual -notin $allowedVisuals) {
                throw "CIEM report '$($entry.id)' references unsupported visual '$visual'."
            }
        }

        if (@($entry.statusSummary).Count -eq 0) {
            throw "CIEM report '$($entry.id)' has no statusSummary entries."
        }

        foreach ($summary in @($entry.statusSummary)) {
            foreach ($summaryProperty in @('status', 'color')) {
                if (-not $summary.PSObject.Properties[$summaryProperty]) {
                    throw "CIEM report '$($entry.id)' statusSummary entry is missing '$summaryProperty'."
                }
                if ([string]::IsNullOrWhiteSpace([string]$summary.$summaryProperty)) {
                    throw "CIEM report '$($entry.id)' statusSummary entry has empty '$summaryProperty'."
                }
            }
        }

        $parameterNames = @{}
        $parameterSelectorIds = @{}
        foreach ($parameter in @($entry.parameters)) {
            if ($parameter -is [string]) {
                throw "CIEM report '$($entry.id)' has a non-object parameter entry."
            }

            foreach ($parameterProperty in @('name', 'selectorId', 'label', 'optionSource', 'allowEmpty')) {
                if (-not $parameter.PSObject.Properties[$parameterProperty]) {
                    throw "CIEM report '$($entry.id)' parameter entry is missing '$parameterProperty'."
                }
            }

            foreach ($stringProperty in @('name', 'selectorId', 'label', 'optionSource')) {
                if ([string]::IsNullOrWhiteSpace([string]$parameter.$stringProperty)) {
                    throw "CIEM report '$($entry.id)' parameter entry has empty '$stringProperty'."
                }
            }

            if ($parameter.allowEmpty -isnot [bool]) {
                throw "CIEM report '$($entry.id)' parameter '$($parameter.name)' has non-boolean allowEmpty."
            }

            $parameterName = [string]$parameter.name
            if ($parameterNames.ContainsKey($parameterName)) {
                throw "CIEM report '$($entry.id)' contains duplicate parameter name '$parameterName'."
            }
            $parameterNames[$parameterName] = $true

            $selectorId = [string]$parameter.selectorId
            if ($parameterSelectorIds.ContainsKey($selectorId)) {
                throw "CIEM report '$($entry.id)' contains duplicate parameter selectorId '$selectorId'."
            }
            $parameterSelectorIds[$selectorId] = $true

            if (-not $executorCommand.Parameters.ContainsKey($parameterName)) {
                throw "CIEM report '$($entry.id)' declares parameter '$parameterName' that executor '$($entry.executorName)' does not accept."
            }
        }
    }

    $true
}
