function GetCIEMCheckCatalog {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Provider
    )

    $ErrorActionPreference = 'Stop'

    $allowedFields = @(
        'Id',
        'SourceCheckId',
        'Provider',
        'Service',
        'Title',
        'Description',
        'Risk',
        'Severity',
        'Remediation',
        'RelatedUrl',
        'CheckScript',
        'DependsOn',
        'Permissions',
        'Disabled',
        'DataNeeds',
        'ExecutionMode',
        'ManualReason',
        'Evaluator',
        'EvaluatorConfig'
    )
    $requiredFields = @(
        'Id',
        'SourceCheckId',
        'Provider',
        'Service',
        'Title',
        'Description',
        'Risk',
        'Severity',
        'Remediation',
        'RelatedUrl',
        'DependsOn',
        'Permissions',
        'Disabled',
        'ExecutionMode',
        'ManualReason'
    )
    $allowedExecutionModes = @('script', 'rule', 'manual', 'notImplemented')
    $nonScriptModes = @('manual', 'notImplemented')
    $allowedSeverities = @('critical', 'high', 'medium', 'low')
    $ruleEvaluatorRequiredFields = @{
        propertyEquals        = @('DataNeed', 'ResourceType', 'PropertyPath', 'ExpectedValue')
        propertyNotEquals     = @('DataNeed', 'ResourceType', 'PropertyPath', 'DisallowedValue')
        propertyExists        = @('DataNeed', 'ResourceType', 'PropertyPath')
        countWithinLimit      = @('DataNeed', 'ResourceType', 'Filter', 'Maximum')
        edgeExists            = @('SourceKind', 'EdgeKind', 'TargetKind', 'Filter')
        roleAssignmentMatches = @('PrincipalKind', 'RoleName', 'ScopeKind', 'Filter')
    }

    $providerNames = if ($Provider) {
        @($Provider)
    }
    else {
        @(
            Get-ChildItem -LiteralPath (Join-Path $script:ModuleRoot 'modules') -Directory |
                Where-Object {
                    Test-Path -LiteralPath (Join-Path $_.FullName 'Checks/check_catalog.json') -PathType Leaf
                } |
                Select-Object -ExpandProperty Name |
                Sort-Object
        )
    }

    $allCatalogRows = @()
    $globalIds = @{}

    foreach ($providerName in $providerNames) {
        $checksRoot = Join-Path $script:ModuleRoot "modules/$providerName/Checks"
        $catalogPath = Join-Path $checksRoot 'check_catalog.json'
        if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
            throw "No check catalog found for provider '$providerName' at '$catalogPath'."
        }

        $catalog = @(
            Get-Content -LiteralPath $catalogPath -Raw |
                ConvertFrom-Json -AsHashtable -ErrorAction Stop
        )
        if ($catalog.Count -eq 0) {
            throw "Check catalog '$catalogPath' is empty."
        }

        $catalogByScript = @{}
        $providerIds = @{}

        foreach ($entry in $catalog) {
            $unknownFields = @($entry.Keys | Where-Object { $_ -notin $allowedFields })
            if ($unknownFields.Count -gt 0) {
                throw "Catalog entry '$($entry['Id'])' in '$catalogPath' declares unknown field(s): $($unknownFields -join ', ')."
            }

            foreach ($fieldName in $requiredFields) {
                if (-not $entry.ContainsKey($fieldName)) {
                    throw "Catalog entry in '$catalogPath' is missing $fieldName."
                }
            }

            foreach ($fieldName in @('Id', 'Provider', 'Service', 'Title', 'Severity', 'ExecutionMode')) {
                if ([string]::IsNullOrWhiteSpace([string]$entry[$fieldName])) {
                    throw "Catalog entry in '$catalogPath' is missing $fieldName."
                }
            }

            if ($entry['Provider'] -ne $providerName) {
                throw "Catalog entry '$($entry['Id'])' declares provider '$($entry['Provider'])' but is stored under '$providerName'."
            }
            if ($entry['Severity'] -notin $allowedSeverities) {
                throw "Catalog entry '$($entry['Id'])' declares invalid severity '$($entry['Severity'])'."
            }
            if ($entry['ExecutionMode'] -notin $allowedExecutionModes) {
                throw "Catalog entry '$($entry['Id'])' declares invalid execution mode '$($entry['ExecutionMode'])'."
            }
            if ($providerIds.ContainsKey($entry['Id']) -or $globalIds.ContainsKey($entry['Id'])) {
                throw "Duplicate check id '$($entry['Id'])' in provider check catalogs."
            }

            $executionMode = [string]$entry['ExecutionMode']
            $checkScript = if ($entry.ContainsKey('CheckScript') -and $null -ne $entry['CheckScript']) {
                [string]$entry['CheckScript']
            }
            else {
                ''
            }

            if ($executionMode -eq 'script') {
                if ([string]::IsNullOrWhiteSpace($checkScript)) {
                    throw "Script catalog entry '$($entry['Id'])' is missing CheckScript."
                }
                if ($catalogByScript.ContainsKey($checkScript)) {
                    throw "Duplicate check script '$checkScript' in '$catalogPath'."
                }
                $scriptPath = Join-Path $checksRoot $checkScript
                if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
                    throw "Check catalog '$catalogPath' references missing script '$checkScript'."
                }
                $catalogByScript[$checkScript] = $entry
            }
            elseif ($executionMode -in $nonScriptModes) {
                if (-not [string]::IsNullOrWhiteSpace($checkScript)) {
                    throw "Non-script catalog entry '$($entry['Id'])' must not declare CheckScript."
                }
                if ([string]::IsNullOrWhiteSpace([string]$entry['ManualReason'])) {
                    throw "Non-script catalog entry '$($entry['Id'])' must declare ManualReason."
                }
            }
            elseif ($executionMode -eq 'rule') {
                if (-not [string]::IsNullOrWhiteSpace($checkScript)) {
                    throw "Rule catalog entry '$($entry['Id'])' must not declare CheckScript."
                }
                if ([string]::IsNullOrWhiteSpace([string]$entry['Evaluator'])) {
                    throw "Rule catalog entry '$($entry['Id'])' must declare Evaluator."
                }
                if (-not $ruleEvaluatorRequiredFields.ContainsKey($entry['Evaluator'])) {
                    throw "Rule catalog entry '$($entry['Id'])' declares unsupported evaluator '$($entry['Evaluator'])'."
                }
                if (-not $entry.ContainsKey('EvaluatorConfig') -or $null -eq $entry['EvaluatorConfig']) {
                    throw "Rule catalog entry '$($entry['Id'])' must declare EvaluatorConfig."
                }
                foreach ($requiredField in $ruleEvaluatorRequiredFields[$entry['Evaluator']]) {
                    if (-not $entry['EvaluatorConfig'].ContainsKey($requiredField)) {
                        throw "Rule catalog entry '$($entry['Id'])' evaluator '$($entry['Evaluator'])' is missing $requiredField."
                    }
                }
            }

            $dataNeeds = if ($entry.ContainsKey('DataNeeds') -and $null -ne $entry['DataNeeds']) {
                @($entry['DataNeeds'])
            }
            else {
                $null
            }

            if (-not [System.Convert]::ToBoolean($entry['Disabled']) -and $executionMode -in @('script', 'rule')) {
                if ($null -eq $dataNeeds -or $dataNeeds.Count -eq 0) {
                    throw "Enabled catalog entry '$($entry['Id'])' must declare at least one data need."
                }
            }
            if ($null -ne $dataNeeds) {
                foreach ($needKey in @($dataNeeds)) {
                    if ($needKey -cne $needKey.ToLowerInvariant()) {
                        throw "Catalog entry '$($entry['Id'])' declares non-canonical data need '$needKey'."
                    }
                }
            }

            $permissions = @{
                Graph             = @()
                ARM               = @()
                KeyVaultDataPlane = @()
                IAM               = @()
            }
            foreach ($permissionPlane in @($entry['Permissions'].Keys)) {
                switch ($permissionPlane.ToLowerInvariant()) {
                    'graph'             { $permissions.Graph = @($entry['Permissions'][$permissionPlane]) }
                    'arm'               { $permissions.ARM = @($entry['Permissions'][$permissionPlane]) }
                    'keyvaultdataplane' { $permissions.KeyVaultDataPlane = @($entry['Permissions'][$permissionPlane]) }
                    'iam'               { $permissions.IAM = @($entry['Permissions'][$permissionPlane]) }
                    default             { throw "Catalog entry '$($entry['Id'])' declares unsupported permission plane '$permissionPlane'." }
                }
            }

            $evaluatorConfig = if ($entry.ContainsKey('EvaluatorConfig') -and $null -ne $entry['EvaluatorConfig']) {
                $entry['EvaluatorConfig'] | ConvertTo-Json -Compress -Depth 10
            }
            else {
                $null
            }

            $allCatalogRows += [PSCustomObject]@{
                Id              = [string]$entry['Id']
                SourceCheckId   = [string]$entry['SourceCheckId']
                Provider        = [string]$entry['Provider']
                Service         = [string]$entry['Service']
                Title           = [string]$entry['Title']
                Description     = [string]$entry['Description']
                Risk            = [string]$entry['Risk']
                Severity        = [string]$entry['Severity']
                Remediation     = [PSCustomObject]@{
                    Text = [string]$entry['Remediation']['Text']
                    Url  = [string]$entry['Remediation']['Url']
                }
                RelatedUrl      = [string]$entry['RelatedUrl']
                CheckScript     = $checkScript
                ExecutionMode   = $executionMode
                ManualReason    = if ($null -ne $entry['ManualReason']) { [string]$entry['ManualReason'] } else { $null }
                Evaluator       = if ($entry.ContainsKey('Evaluator') -and $null -ne $entry['Evaluator']) { [string]$entry['Evaluator'] } else { $null }
                EvaluatorConfig = $evaluatorConfig
                DependsOn       = if ($entry.ContainsKey('DependsOn') -and $null -ne $entry['DependsOn']) { @($entry['DependsOn']) } else { @() }
                DataNeeds       = $dataNeeds
                Disabled        = [System.Convert]::ToBoolean($entry['Disabled'])
                Permissions     = [PSCustomObject]$permissions
            }

            $providerIds[$entry['Id']] = $true
            $globalIds[$entry['Id']] = $true
        }

        $scriptFiles = @(Get-ChildItem -LiteralPath $checksRoot -Filter '*.ps1' -File | Select-Object -ExpandProperty Name)
        $missingCatalogScripts = @($scriptFiles | Where-Object { -not $catalogByScript.ContainsKey($_) })
        if ($missingCatalogScripts.Count -gt 0) {
            throw "Check catalog '$catalogPath' is missing script entries: $($missingCatalogScripts -join ', ')"
        }
    }

    $allCatalogRows
}
