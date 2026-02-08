function Convert-ProwlerCheck {
    <#
    .SYNOPSIS
        Converts Prowler Python checks to PowerShell format for the Devolutions.CIEM module.

    .DESCRIPTION
        Reads Prowler check definitions (metadata.json and Python implementation) and generates:
        1. A PowerShell check script (Test-*.ps1)
        2. A JSON metadata entry for AzureChecks.json

    .PARAMETER CheckPath
        Path to a Prowler check directory containing the metadata.json and .py files.

    .PARAMETER CheckId
        The check ID to convert. Will locate the check in the prowler directory.

    .PARAMETER Provider
        Cloud provider: azure or aws. Required when using -CheckId.

    .PARAMETER OutputDirectory
        Directory to output generated files. Defaults to Private/<Provider>/Checks.

    .PARAMETER MetadataOnly
        Only outputs the JSON metadata entry without generating the PowerShell script.

    .PARAMETER ScriptOnly
        Only generates the PowerShell script without outputting metadata.

    .PARAMETER Permissions
        Hashtable of permissions to override inferred permissions.

    .EXAMPLE
        Convert-ProwlerCheck -CheckPath './prowler/prowler/providers/azure/services/entra/entra_security_defaults_enabled'

    .EXAMPLE
        Convert-ProwlerCheck -CheckId 'entra_security_defaults_enabled' -Provider azure
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByPath')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByPath', Position = 0)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$CheckPath,

        [Parameter(Mandatory, ParameterSetName = 'ById', Position = 0)]
        [ValidatePattern('^[a-z][a-z0-9]*(_[a-z0-9]+)+$')]
        [string]$CheckId,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateSet('azure', 'aws')]
        [string]$Provider,

        [Parameter()]
        [string]$OutputDirectory,

        [Parameter()]
        [switch]$MetadataOnly,

        [Parameter()]
        [switch]$ScriptOnly,

        [Parameter()]
        [hashtable]$Permissions
    )

    $ErrorActionPreference = 'Stop'

    #region Helper Functions

    # Converts snake_case text to PascalCase (e.g., 'my_check_name' -> 'MyCheckName')
    function ConvertTo-PascalCase {
        param([string]$Text)
        ($Text -split '_' | ForEach-Object {
            if ($_.Length -gt 0) {
                $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower()
            }
        }) -join ''
    }

    # Maps Prowler service names to display-friendly names used in the module
    function Get-ServiceDisplayName {
        param([string]$ServiceName)

        $serviceMap = @{
            'entra'      = 'Entra'
            'iam'        = 'IAM'
            'storage'    = 'Storage'
            'keyvault'   = 'KeyVault'
            'defender'   = 'Defender'
            'monitor'    = 'Monitor'
            'network'    = 'Network'
            'compute'    = 'Compute'
            'sqlserver'  = 'SqlServer'
            'cosmosdb'   = 'CosmosDb'
            'app'        = 'App'
            'containerregistry' = 'ContainerRegistry'
        }

        if ($serviceMap.ContainsKey($ServiceName.ToLower())) {
            $serviceMap[$ServiceName.ToLower()]
        }
        else {
            $ServiceName.Substring(0, 1).ToUpper() + $ServiceName.Substring(1).ToLower()
        }
    }

    # Generates the PowerShell function name from check ID (e.g., 'entra_mfa_check' -> 'Test-EntraMfaCheck')
    function Get-CheckFunctionName {
        param([string]$CheckId)
        $parts = $CheckId -split '_'
        $pascalParts = $parts | ForEach-Object {
            if ($_.Length -gt 0) {
                $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower()
            }
        }
        "Test-$($pascalParts -join '')"
    }

    # Analyzes Prowler Python code to infer required Azure/Graph permissions
    function Get-InferredPermission {
        param(
            [string]$PythonCode,
            [string]$ServiceName,
            [string]$ProviderName
        )

        $perms = @{}

        if ($ProviderName -eq 'azure') {
            $graphPatterns = @{
                'users'                    = 'User.Read.All'
                'directory_roles'          = 'RoleManagement.Read.Directory'
                'security_default'         = 'Policy.Read.All'
                'authorization_policy'     = 'Policy.Read.All'
                'conditional_access'       = 'Policy.Read.All'
                'named_locations'          = 'Policy.Read.All'
                'group_settings'           = 'Directory.Read.All'
                'authentication_methods'   = 'UserAuthenticationMethod.Read.All'
                'mfa'                      = 'UserAuthenticationMethod.Read.All'
            }

            $graphPermissions = @()
            foreach ($pattern in $graphPatterns.GetEnumerator()) {
                if ($PythonCode -match $pattern.Key) {
                    if ($graphPermissions -notcontains $pattern.Value) {
                        $graphPermissions += $pattern.Value
                    }
                }
            }
            if ($graphPermissions.Count -gt 0) {
                $perms['graph'] = $graphPermissions
            }

            $armPatterns = @{
                'storage'    = 'Microsoft.Storage/storageAccounts/read'
                'keyvault'   = 'Microsoft.KeyVault/vaults/read'
                'role'       = 'Microsoft.Authorization/roleDefinitions/read'
                'diagnostic' = 'Microsoft.Insights/diagnosticSettings/read'
            }

            $armPermissions = @()
            foreach ($pattern in $armPatterns.GetEnumerator()) {
                if ($ServiceName -match $pattern.Key -or $PythonCode -match $pattern.Key) {
                    if ($armPermissions -notcontains $pattern.Value) {
                        $armPermissions += $pattern.Value
                    }
                }
            }
            if ($armPermissions.Count -gt 0) {
                $perms['arm'] = $armPermissions
            }

            if ($ServiceName -eq 'keyvault') {
                $kvPatterns = @{ 'keys' = 'keys/list'; 'secrets' = 'secrets/list'; 'certificates' = 'certificates/list' }
                $kvPermissions = @()
                foreach ($pattern in $kvPatterns.GetEnumerator()) {
                    if ($PythonCode -match $pattern.Key -and $kvPermissions -notcontains $pattern.Value) {
                        $kvPermissions += $pattern.Value
                    }
                }
                if ($kvPermissions.Count -gt 0) {
                    $perms['keyvaultDataPlane'] = $kvPermissions
                }
            }
        }
        elseif ($ProviderName -eq 'aws') {
            $perms['iam'] = @('iam:ListUsers', 'iam:ListAttachedUserPolicies')
        }

        if ($perms.Count -eq 0) {
            switch ($ServiceName.ToLower()) {
                'entra' { $perms['graph'] = @('Policy.Read.All') }
                'iam'   { $perms['arm'] = @('Microsoft.Authorization/roleDefinitions/read') }
                'storage' { $perms['arm'] = @('Microsoft.Storage/storageAccounts/read') }
                'keyvault' { $perms['arm'] = @('Microsoft.KeyVault/vaults/read') }
                default { $perms['graph'] = @('Directory.Read.All') }
            }
        }

        $perms
    }

    # Generates a PowerShell check function scaffold from Prowler metadata
    function ConvertTo-PowerShellCheck {
        param(
            [hashtable]$Metadata,
            [string]$FunctionName
        )

        $scriptContent = @"
function $FunctionName {
    <#
    .SYNOPSIS
        $($Metadata.CheckTitle)

    .DESCRIPTION
        $($Metadata.Description -replace "`n", "`n        ")

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]`$Check
    )

    `$ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: $($Metadata.CheckID)

    [CIEMScanResult]::Create(`$Check, 'MANUAL', 'This check requires manual implementation. See Prowler check $($Metadata.CheckID) for reference.', 'N/A', '$($Metadata.ServiceName) Resources')
}
"@
        $scriptContent
    }

    # Converts Prowler metadata to CIEM-compatible JSON metadata format
    function ConvertTo-CheckMetadataJson {
        param(
            [hashtable]$Metadata,
            [string]$FunctionName,
            [string]$ServiceDisplayName,
            [hashtable]$Perms
        )

        $categories = @()
        foreach ($cat in $Metadata.Categories) {
            $mappedCat = switch -Regex ($cat) {
                'identity|access|iam' { 'identity' }
                'encrypt' { 'encryption' }
                'network' { 'network' }
                'log|audit|monitor' { 'logging' }
                'compliance' { 'compliance' }
                default { $null }
            }
            if ($mappedCat -and $categories -notcontains $mappedCat) {
                $categories += $mappedCat
            }
        }

        [ordered]@{
            id           = $Metadata.CheckID
            service      = $ServiceDisplayName
            title        = $Metadata.CheckTitle
            description  = $Metadata.Description
            risk         = $Metadata.Risk
            severity     = $Metadata.Severity.ToLower()
            categories   = $categories
            remediation  = [ordered]@{
                text = 'See Devolutions PAM for remediation guidance.'
                url  = 'https://devolutions.net/pam'
            }
            relatedUrl   = if ($Metadata.RelatedUrl) { $Metadata.RelatedUrl } else { '' }
            checkScript  = "$FunctionName.ps1"
            dependsOn    = @($Metadata.DependsOn | Where-Object { $_ })
            permissions  = $Perms
        }
    }

    #endregion Helper Functions

    #region Main Logic

    # Resolve prowler providers path from config
    $prowlerProvidersPath = Join-Path $script:ModuleRoot $script:Config.prowler.path

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $serviceName = ($CheckId -split '_')[0]
        $checkSearchPath = Join-Path $prowlerProvidersPath "$Provider/services/$serviceName/$CheckId"

        if (-not (Test-Path $checkSearchPath)) {
            $foundPath = Get-ChildItem -Path (Join-Path $prowlerProvidersPath "$Provider/services") -Recurse -Directory |
                Where-Object { $_.Name -eq $CheckId } |
                Select-Object -First 1 -ExpandProperty FullName

            if ($foundPath) {
                $CheckPath = $foundPath
            }
            else {
                throw "Check '$CheckId' not found in $Provider/services/"
            }
        }
        else {
            $CheckPath = $checkSearchPath
        }
    }

    $CheckPath = Resolve-Path $CheckPath

    if (-not $CheckId) {
        $CheckId = Split-Path $CheckPath -Leaf
    }

    $metadataPath = Join-Path $CheckPath "$CheckId.metadata.json"
    if (-not (Test-Path $metadataPath)) {
        throw "Metadata file not found: $metadataPath"
    }
    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json -AsHashtable

    $pythonPath = Join-Path $CheckPath "$CheckId.py"
    $pythonCode = ''
    if (Test-Path $pythonPath) {
        $pythonCode = Get-Content $pythonPath -Raw
    }

    if (-not $Provider) {
        if ($CheckPath -match 'providers[/\\](azure|aws|gcp)') {
            $Provider = $Matches[1]
        }
        else {
            throw "Could not determine provider from path. Please specify -Provider parameter."
        }
    }

    $serviceName = $metadata.ServiceName
    $serviceDisplayName = Get-ServiceDisplayName -ServiceName $serviceName
    $functionName = Get-CheckFunctionName -CheckId $CheckId

    if (-not $Permissions) {
        $Permissions = Get-InferredPermission -PythonCode $pythonCode -ServiceName $serviceName -ProviderName $Provider
    }

    if (-not $OutputDirectory) {
        $OutputDirectory = Join-Path -Path $script:ModuleRoot -ChildPath $script:Config.checksPath -AdditionalChildPath "$Provider/Checks"
    }

    $results = @{
        CheckId       = $CheckId
        FunctionName  = $functionName
        Service       = $serviceDisplayName
        Provider      = $Provider
    }

    if (-not $MetadataOnly) {
        $scriptContent = ConvertTo-PowerShellCheck -Metadata $metadata -FunctionName $functionName
        $scriptPath = Join-Path $OutputDirectory "$functionName.ps1"

        if (-not (Test-Path $OutputDirectory)) {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        }

        $scriptContent | Set-Content -Path $scriptPath -Encoding UTF8
        $results.ScriptPath = $scriptPath
        Write-Verbose "Generated: $scriptPath"
    }

    if (-not $ScriptOnly) {
        $checkMetadata = ConvertTo-CheckMetadataJson -Metadata $metadata -FunctionName $functionName -ServiceDisplayName $serviceDisplayName -Perms $Permissions
        $results.Metadata = $checkMetadata

        $jsonOutput = $checkMetadata | ConvertTo-Json -Depth 10
        Write-Verbose "JSON Metadata:"
        Write-Verbose $jsonOutput

        $metadataOutputPath = Join-Path $OutputDirectory "$functionName.metadata.json"
        $jsonOutput | Set-Content -Path $metadataOutputPath -Encoding UTF8
        $results.MetadataPath = $metadataOutputPath
    }

    [PSCustomObject]$results

    #endregion Main Logic
}
