function Test-AzureChecksSchema {
    <#
    .SYNOPSIS
        Validates AzureChecks.json against its schema.

    .DESCRIPTION
        Performs validation of the AzureChecks.json file to ensure all check
        definitions conform to the expected schema. Validates:
        - Required properties exist
        - Property types are correct
        - Enum values are valid
        - String patterns match
        - Permissions structure is valid

    .PARAMETER Path
        Path to the AzureChecks.json file. Defaults to the module's AzureChecks.json.

    .OUTPUTS
        [PSCustomObject] Validation result with IsValid, Errors, and Warnings properties.

    .EXAMPLE
        Test-AzureChecksSchema
        # Validates the default AzureChecks.json

    .EXAMPLE
        Test-AzureChecksSchema -Path './custom-checks.json'
        # Validates a custom checks file
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$Path
    )

    $ErrorActionPreference = 'Stop'

    # Default to module's AzureChecks.json
    if (-not $Path) {
        $Path = Join-Path $PSScriptRoot '../../AzureChecks.json'
    }

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    # Validation constants
    $validServices = @('Entra', 'IAM', 'KeyVault', 'Storage')
    $validSeverities = @('low', 'medium', 'high', 'critical')
    $validCategories = @('encryption', 'identity', 'network', 'logging', 'compliance')
    $validKvDataPlanePerms = @('keys/list', 'keys/get', 'secrets/list', 'secrets/get', 'certificates/list', 'certificates/get')

    # Regex patterns
    $idPattern = '^[a-z]+(_[a-z0-9]+)+$'
    $checkScriptPattern = '^Test-[A-Z][a-zA-Z0-9]+\.ps1$'
    $graphPermPattern = '^[A-Z][a-zA-Z]+\.[A-Z][a-zA-Z]+(\.[A-Z][a-zA-Z]+)?$'
    $armPermPattern = '^Microsoft\.[A-Za-z]+/[a-zA-Z/]+$'

    # Load and parse JSON
    $checksJson = $null
    $earlyExit = $false

    if (-not (Test-Path $Path)) {
        $errors.Add("File not found: $Path")
        $earlyExit = $true
    }

    if (-not $earlyExit) {
        try {
            $checksJson = Get-Content -Path $Path -Raw | ConvertFrom-Json
        }
        catch {
            $errors.Add("Invalid JSON: $($_.Exception.Message)")
            $earlyExit = $true
        }
    }

    # Validate root is array
    if (-not $earlyExit -and $checksJson -isnot [array]) {
        $errors.Add("Root element must be an array")
        $earlyExit = $true
    }

    if ($earlyExit) {
        [PSCustomObject]@{
            IsValid  = $false
            Errors   = $errors.ToArray()
            Warnings = $warnings.ToArray()
            Path     = $Path
        }
    }
    else {
        if ($checksJson.Count -eq 0) {
            $errors.Add("Checks array cannot be empty")
        }

        # Track IDs for uniqueness check
        $seenIds = @{}

        # Validate each check
        for ($i = 0; $i -lt $checksJson.Count; $i++) {
            $check = $checksJson[$i]
            $prefix = "Check[$i]"

            # Get ID early for better error messages
            $checkId = if ($check.id) { $check.id } else { "index $i" }
            $prefix = "Check '$checkId'"

            # Required string properties
            $requiredStrings = @('id', 'service', 'title', 'description', 'risk', 'severity', 'checkScript')
            foreach ($prop in $requiredStrings) {
                if (-not $check.PSObject.Properties[$prop]) {
                    $errors.Add("$prefix : Missing required property '$prop'")
                }
                elseif ($check.$prop -isnot [string]) {
                    $errors.Add("$prefix : Property '$prop' must be a string")
                }
                elseif ([string]::IsNullOrWhiteSpace($check.$prop)) {
                    $errors.Add("$prefix : Property '$prop' cannot be empty")
                }
            }

            # Validate ID format and uniqueness
            if ($check.id) {
                if ($check.id -notmatch $idPattern) {
                    $errors.Add("$prefix : ID must be snake_case (e.g., 'entra_security_defaults_enabled')")
                }
                if ($seenIds.ContainsKey($check.id)) {
                    $errors.Add("$prefix : Duplicate ID found (first occurrence at index $($seenIds[$check.id]))")
                }
                else {
                    $seenIds[$check.id] = $i
                }
            }

            # Validate service enum
            if ($check.service -and $check.service -notin $validServices) {
                $errors.Add("$prefix : Invalid service '$($check.service)'. Must be one of: $($validServices -join ', ')")
            }

            # Validate severity enum
            if ($check.severity -and $check.severity -notin $validSeverities) {
                $errors.Add("$prefix : Invalid severity '$($check.severity)'. Must be one of: $($validSeverities -join ', ')")
            }

            # Validate checkScript pattern
            if ($check.checkScript -and $check.checkScript -notmatch $checkScriptPattern) {
                $errors.Add("$prefix : checkScript must match pattern 'Test-*.ps1' (e.g., 'Test-EntraSecurityDefaultsEnabled.ps1')")
            }

            # Validate title/description length
            if ($check.title -and $check.title.Length -lt 10) {
                $warnings.Add("$prefix : Title is very short (< 10 chars)")
            }
            if ($check.description -and $check.description.Length -lt 20) {
                $warnings.Add("$prefix : Description is very short (< 20 chars)")
            }

            # Validate categories array
            if (-not $check.PSObject.Properties['categories']) {
                $errors.Add("$prefix : Missing required property 'categories'")
            }
            elseif ($check.categories -isnot [array]) {
                $errors.Add("$prefix : Property 'categories' must be an array")
            }
            else {
                foreach ($cat in $check.categories) {
                    if ($cat -notin $validCategories) {
                        $errors.Add("$prefix : Invalid category '$cat'. Must be one of: $($validCategories -join ', ')")
                    }
                }
            }

            # Validate remediation object
            if (-not $check.PSObject.Properties['remediation']) {
                $errors.Add("$prefix : Missing required property 'remediation'")
            }
            elseif ($check.remediation -isnot [PSCustomObject]) {
                $errors.Add("$prefix : Property 'remediation' must be an object")
            }
            else {
                if (-not $check.remediation.text) {
                    $errors.Add("$prefix : remediation.text is required")
                }
                if (-not $check.remediation.PSObject.Properties['url']) {
                    $errors.Add("$prefix : remediation.url is required")
                }
            }

            # Validate relatedUrl exists (can be empty string)
            if (-not $check.PSObject.Properties['relatedUrl']) {
                $errors.Add("$prefix : Missing required property 'relatedUrl'")
            }

            # Validate dependsOn array
            if (-not $check.PSObject.Properties['dependsOn']) {
                $errors.Add("$prefix : Missing required property 'dependsOn'")
            }
            elseif ($check.dependsOn -isnot [array]) {
                $errors.Add("$prefix : Property 'dependsOn' must be an array")
            }
            else {
                foreach ($dep in $check.dependsOn) {
                    if ($dep -notmatch $idPattern) {
                        $errors.Add("$prefix : dependsOn value '$dep' must be a valid check ID (snake_case)")
                    }
                }
            }

            # Validate permissions object
            if (-not $check.PSObject.Properties['permissions']) {
                $errors.Add("$prefix : Missing required property 'permissions'")
            }
            elseif ($check.permissions -isnot [PSCustomObject]) {
                $errors.Add("$prefix : Property 'permissions' must be an object")
            }
            else {
                $permProps = $check.permissions.PSObject.Properties.Name
                $validPermProps = @('graph', 'arm', 'keyvaultDataPlane')

                # Must have at least one permission type
                if ($permProps.Count -eq 0) {
                    $errors.Add("$prefix : permissions must have at least one of: $($validPermProps -join ', ')")
                }

                # Check for invalid permission types
                foreach ($prop in $permProps) {
                    if ($prop -notin $validPermProps) {
                        $errors.Add("$prefix : Invalid permission type '$prop'. Must be one of: $($validPermProps -join ', ')")
                    }
                }

                # Validate graph permissions
                if ($check.permissions.graph) {
                    if ($check.permissions.graph -isnot [array]) {
                        $errors.Add("$prefix : permissions.graph must be an array")
                    }
                    else {
                        foreach ($perm in $check.permissions.graph) {
                            if ($perm -notmatch $graphPermPattern) {
                                $errors.Add("$prefix : Invalid Graph permission '$perm'. Expected format like 'Policy.Read.All'")
                            }
                        }
                    }
                }

                # Validate ARM permissions
                if ($check.permissions.arm) {
                    if ($check.permissions.arm -isnot [array]) {
                        $errors.Add("$prefix : permissions.arm must be an array")
                    }
                    else {
                        foreach ($perm in $check.permissions.arm) {
                            if ($perm -notmatch $armPermPattern) {
                                $errors.Add("$prefix : Invalid ARM permission '$perm'. Expected format like 'Microsoft.Storage/storageAccounts/read'")
                            }
                        }
                    }
                }

                # Validate Key Vault data plane permissions
                if ($check.permissions.keyvaultDataPlane) {
                    if ($check.permissions.keyvaultDataPlane -isnot [array]) {
                        $errors.Add("$prefix : permissions.keyvaultDataPlane must be an array")
                    }
                    else {
                        foreach ($perm in $check.permissions.keyvaultDataPlane) {
                            if ($perm -notin $validKvDataPlanePerms) {
                                $errors.Add("$prefix : Invalid keyvaultDataPlane permission '$perm'. Must be one of: $($validKvDataPlanePerms -join ', ')")
                            }
                        }
                    }
                }
            }
        }

        # Return validation result
        [PSCustomObject]@{
            IsValid    = $errors.Count -eq 0
            Errors     = $errors.ToArray()
            Warnings   = $warnings.ToArray()
            Path       = $Path
            CheckCount = $checksJson.Count
        }
    }
}
