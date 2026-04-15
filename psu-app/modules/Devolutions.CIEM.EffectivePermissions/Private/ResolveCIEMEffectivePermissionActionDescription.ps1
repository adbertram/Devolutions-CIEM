function GetCIEMEffectivePermissionDescriptionCatalog {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    if (-not $script:CIEMEffectivePermissionDescriptionCatalog) {
        $catalogPath = Join-Path $script:EffectivePermissionsRoot 'Data/effective_permission_descriptions.json'
        if (-not (Test-Path -LiteralPath $catalogPath)) {
            throw "Effective permission description catalog not found: $catalogPath"
        }

        $script:CIEMEffectivePermissionDescriptionCatalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }

    $script:CIEMEffectivePermissionDescriptionCatalog
}

function ConvertCIEMAnchoredLiteralRegexPattern {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern
    )

    $ErrorActionPreference = 'Stop'

    if (-not ($Pattern.StartsWith('^') -and $Pattern.EndsWith('$'))) {
        return $null
    }

    $body = $Pattern.Substring(1, $Pattern.Length - 2)
    $literal = [System.Text.StringBuilder]::new()
    $regexOperators = '.^$*+?()[]{}|'

    for ($i = 0; $i -lt $body.Length; $i++) {
        $character = $body[$i]
        if ($character -eq '\') {
            $i++
            if ($i -ge $body.Length) {
                throw "Invalid action description regex pattern '$Pattern'."
            }

            [void]$literal.Append($body[$i])
            continue
        }

        if ($regexOperators.Contains($character)) {
            return $null
        }

        [void]$literal.Append($character)
    }

    $literal.ToString()
}

function GetCIEMEffectivePermissionActionDescriptionIndex {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    if (-not $script:CIEMEffectivePermissionActionDescriptionIndex) {
        $catalog = GetCIEMEffectivePermissionDescriptionCatalog
        $exactDescriptions = [System.Collections.Hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)
        $patternDescriptions = [System.Collections.Generic.List[object]]::new()

        foreach ($entry in @($catalog.actionDescriptions)) {
            $provider = [string]$entry.provider
            $literalAction = ConvertCIEMAnchoredLiteralRegexPattern -Pattern ([string]$entry.pattern)

            if ($literalAction) {
                if (-not $exactDescriptions.ContainsKey($provider)) {
                    $exactDescriptions[$provider] = [System.Collections.Hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)
                }

                if ($exactDescriptions[$provider].ContainsKey($literalAction)) {
                    throw "Duplicate effective permission action description for provider '$provider' and action '$literalAction'."
                }

                $exactDescriptions[$provider][$literalAction] = [string]$entry.description
                continue
            }

            [void]$patternDescriptions.Add($entry)
        }

        $script:CIEMEffectivePermissionActionDescriptionIndex = [pscustomobject]@{
            ExactDescriptions = $exactDescriptions
            PatternDescriptions = @($patternDescriptions)
        }
    }

    $script:CIEMEffectivePermissionActionDescriptionIndex
}

function GetCIEMEffectivePermissionCatalogValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Map,

        [Parameter(Mandatory)]
        [string]$Key
    )

    $ErrorActionPreference = 'Stop'

    $property = $Map.PSObject.Properties[$Key]
    if ($property) {
        return [string]$property.Value
    }

    $null
}

function ConvertCIEMPermissionIdentifierToWords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $ErrorActionPreference = 'Stop'

    ($Value -creplace '([a-z0-9])([A-Z])', '$1 $2' -replace '[-_]', ' ' -replace '\s+', ' ').Trim().ToLowerInvariant()
}

function ResolveCIEMEffectivePermissionScopeDescription {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [string]$TargetType
    )

    $ErrorActionPreference = 'Stop'

    $catalog = GetCIEMEffectivePermissionDescriptionCatalog
    if ([string]::IsNullOrWhiteSpace($TargetType)) {
        throw "Effective permission description mapping missing for target scope '$TargetType'."
    }

    $scope = GetCIEMEffectivePermissionCatalogValue -Map $catalog.scopeDescriptions -Key $TargetType
    if ($scope) {
        return $scope
    }

    throw "Effective permission description mapping missing for target scope '$TargetType'."
}

function ResolveCIEMEffectivePermissionResourceDescription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ResourcePath
    )

    $ErrorActionPreference = 'Stop'

    $catalog = GetCIEMEffectivePermissionDescriptionCatalog
    $key = $ResourcePath.ToLowerInvariant()
    $description = GetCIEMEffectivePermissionCatalogValue -Map $catalog.resourceDescriptions -Key $key
    if ($description) {
        return $description
    }

    throw "Effective permission description mapping missing for Azure resource path '$ResourcePath'."
}

function ResolveCIEMGenericAzureActionDescription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NativeAction,

        [Parameter(Mandatory)]
        [string]$ScopeDescription
    )

    $ErrorActionPreference = 'Stop'

    $segments = @($NativeAction -split '/' | Where-Object { $_ })
    if ($segments.Count -eq 0) {
        throw 'NativeAction cannot be empty.'
    }

    if ($NativeAction -eq '*') {
        return "Can manage all resources in $ScopeDescription"
    }

    $operation = $segments[-1]
    if ($segments.Count -eq 1) {
        $operationLabel = ConvertCIEMPermissionIdentifierToWords -Value $operation
        return "Can perform $operationLabel in $ScopeDescription"
    }

    $resourceSegmentEnd = $segments.Count - 2
    $actionLabel = $null
    if ($operation -eq 'action' -and $segments.Count -gt 2) {
        $actionLabel = ConvertCIEMPermissionIdentifierToWords -Value $segments[-2]
        $resourceSegmentEnd = $segments.Count - 3
    }

    $resourcePath = ($segments[0..$resourceSegmentEnd] -join '/')
    $resourceDescription = ResolveCIEMEffectivePermissionResourceDescription -ResourcePath $resourcePath

    switch ($operation.ToLowerInvariant()) {
        '*' {
            return "Can manage $resourceDescription in $ScopeDescription"
        }
        'read' {
            return "Can read $resourceDescription in $ScopeDescription"
        }
        'write' {
            return "Can create or modify $resourceDescription in $ScopeDescription"
        }
        'delete' {
            return "Can delete $resourceDescription in $ScopeDescription"
        }
        'action' {
            return "Can run the $actionLabel action on $resourceDescription in $ScopeDescription"
        }
        default {
            $operationLabel = ConvertCIEMPermissionIdentifierToWords -Value $operation
            return "Can perform $operationLabel on $resourceDescription in $ScopeDescription"
        }
    }
}

function ResolveCIEMTargetActionDescription {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [string]$TargetType,

        [Parameter(Mandatory)]
        [string]$NativeAction
    )

    $ErrorActionPreference = 'Stop'

    $catalog = GetCIEMEffectivePermissionDescriptionCatalog
    if (-not [string]::IsNullOrWhiteSpace($TargetType)) {
        $description = GetCIEMEffectivePermissionCatalogValue -Map $catalog.targetActionDescriptions -Key $TargetType
        if ($description) {
            return $description
        }
    }

    throw "Effective permission description mapping missing for target type '$TargetType' and native action '$NativeAction'."
}

function ResolveCIEMDirectoryRoleActionDescription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$DirectoryRoleName
    )

    $ErrorActionPreference = 'Stop'

    $catalog = GetCIEMEffectivePermissionDescriptionCatalog
    $description = GetCIEMEffectivePermissionCatalogValue -Map $catalog.directoryRoleDescriptions -Key $DirectoryRoleName
    if ($description) {
        return $description
    }

    throw "Effective permission description mapping missing for Microsoft Entra directory role '$DirectoryRoleName'."
}

function ResolveCIEMGraphPermissionActionDescription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PermissionSubject,

        [Parameter(Mandatory)]
        [string]$PermissionVerb
    )

    $ErrorActionPreference = 'Stop'

    $catalog = GetCIEMEffectivePermissionDescriptionCatalog
    $subject = GetCIEMEffectivePermissionCatalogValue -Map $catalog.graphPermissionSubjects -Key $PermissionSubject
    if (-not $subject) {
        throw "Effective permission description mapping missing for Microsoft Graph permission subject '$PermissionSubject'."
    }

    $verb = GetCIEMEffectivePermissionCatalogValue -Map $catalog.graphPermissionVerbs -Key $PermissionVerb
    if (-not $verb) {
        throw "Effective permission description mapping missing for Microsoft Graph permission verb '$PermissionVerb'."
    }

    "Can $verb Microsoft Graph $subject data"
}

function ResolveCIEMEffectivePermissionActionDescription {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [CIEMEffectivePermissionProvider]$Provider,

        [Parameter(Mandatory)]
        [string]$NativeAction,

        [Parameter()]
        [AllowNull()]
        [string]$TargetType
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($NativeAction)) {
        throw 'NativeAction cannot be empty.'
    }

    $index = GetCIEMEffectivePermissionActionDescriptionIndex
    $providerKey = [string]$Provider
    $description = $null

    if ($index.ExactDescriptions.ContainsKey($providerKey)) {
        $description = $index.ExactDescriptions[$providerKey][$NativeAction]
    }

    if ($description) {
        if ($description -match '\{scope\}') {
            $scopeDescription = ResolveCIEMEffectivePermissionScopeDescription -TargetType $TargetType
            return $description.Replace('{scope}', $scopeDescription)
        }

        return $description
    }

    foreach ($entry in @($index.PatternDescriptions)) {
        if ([string]$entry.provider -ne [string]$Provider) {
            continue
        }

        if ([regex]::IsMatch($NativeAction, [string]$entry.pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $description = [string]$entry.description
            if ($description -match '\{scope\}') {
                $scopeDescription = ResolveCIEMEffectivePermissionScopeDescription -TargetType $TargetType
                return $description.Replace('{scope}', $scopeDescription)
            }

            return $description
        }
    }

    if ($TargetType -eq 'EntraDirectoryRole') {
        return ResolveCIEMDirectoryRoleActionDescription -DirectoryRoleName $NativeAction
    }

    if ($NativeAction -match '^([A-Za-z0-9-]+)\.([A-Za-z][A-Za-z0-9]*)(\.|$)') {
        return ResolveCIEMGraphPermissionActionDescription -PermissionSubject $Matches[1] -PermissionVerb $Matches[2]
    }

    if ($TargetType -match '^Entra') {
        return ResolveCIEMTargetActionDescription -TargetType $TargetType -NativeAction $NativeAction
    }

    if ($Provider -eq [CIEMEffectivePermissionProvider]::Azure -and $NativeAction -match '/') {
        $scopeDescription = ResolveCIEMEffectivePermissionScopeDescription -TargetType $TargetType
        return ResolveCIEMGenericAzureActionDescription -NativeAction $NativeAction -ScopeDescription $scopeDescription
    }

    if ($Provider -eq [CIEMEffectivePermissionProvider]::Azure) {
        $scopeDescription = ResolveCIEMEffectivePermissionScopeDescription -TargetType $TargetType
        return ResolveCIEMAzureRoleNameActionDescription -RoleName $NativeAction -ScopeDescription $scopeDescription
    }

    ResolveCIEMTargetActionDescription -TargetType $TargetType -NativeAction $NativeAction
}

function ResolveCIEMAzureRoleNameActionDescription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RoleName,

        [Parameter(Mandatory)]
        [string]$ScopeDescription
    )

    $ErrorActionPreference = 'Stop'

    $catalog = GetCIEMEffectivePermissionDescriptionCatalog
    $description = GetCIEMEffectivePermissionCatalogValue -Map $catalog.azureRoleNameDescriptions -Key $RoleName
    if ($description) {
        return $description.Replace('{scope}', $ScopeDescription)
    }

    throw "Effective permission description mapping missing for Azure role name '$RoleName'."
}
