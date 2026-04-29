function ResolveCIEMAdminEnvFilePath {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$EnvFilePath
    )

    $ErrorActionPreference = 'Stop'

    if ($EnvFilePath) {
        if (Test-Path -Path $EnvFilePath -PathType Leaf) {
            return (Resolve-Path -Path $EnvFilePath).Path
        }

        return $null
    }

    foreach ($path in @(
        (Join-Path $PWD '.env'),
        (Join-Path $script:RepoRoot '.env'),
        (Join-Path $script:AdminRoot '.env')
    )) {
        if (Test-Path -Path $path -PathType Leaf) {
            return (Resolve-Path -Path $path).Path
        }
    }

    return $null
}

function ReadCIEMAdminEnvFile {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$EnvFilePath
    )

    $ErrorActionPreference = 'Stop'

    $envVars = @{}
    $resolvedPath = ResolveCIEMAdminEnvFilePath -EnvFilePath $EnvFilePath
    if (-not $resolvedPath) {
        return $envVars
    }

    foreach ($line in (Get-Content -Path $resolvedPath -ErrorAction Stop)) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') {
            continue
        }

        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $envVars[$key] = $value
        }
    }

    return $envVars
}

function GetCIEMRuntimeTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$EnvFilePath,

        [Parameter()]
        [string]$Url,

        [Parameter()]
        [string]$Token,

        [Parameter()]
        [string]$ResourceGroup,

        [Parameter()]
        [string]$WebAppName
    )

    $ErrorActionPreference = 'Stop'

    $registryPath = Join-Path -Path $script:AdminRoot -ChildPath 'Data/runtime-targets.psd1'
    if (-not (Test-Path -Path $registryPath -PathType Leaf)) {
        throw "CIEM runtime target registry not found: $registryPath"
    }

    $registry = Import-PowerShellDataFile -Path $registryPath
    if (-not $registry.ContainsKey($Name)) {
        throw "Unsupported CIEM runtime target '$Name'. Expected one of: $(@($registry.Keys | Sort-Object) -join ', ')."
    }

    $definition = $registry[$Name]
    $envVars = ReadCIEMAdminEnvFile -EnvFilePath $EnvFilePath
    $urlVariable = [string]$definition.UrlVariable
    $tokenVariable = [string]$definition.TokenVariable

    if (-not $Url) {
        $Url = [string]$envVars[$urlVariable]
    }
    if (-not $Token) {
        $Token = [string]$envVars[$tokenVariable]
    }

    if (-not $Url) {
        throw "$urlVariable is required in .env for '$Name' PSU connections."
    }
    if (-not $Token) {
        throw "$tokenVariable is required in .env for '$Name' PSU connections."
    }

    $Url = $Url.TrimEnd('/')
    $isAzure = [bool]$definition.IsAzure
    if ($isAzure -and -not $ResourceGroup) {
        $ResourceGroup = [string]$definition.ResourceGroup
    }
    if ($isAzure -and -not $WebAppName -and $Url -match 'https://([^.]+)\.azurewebsites\.net') {
        $WebAppName = $matches[1]
    }

    [PSCustomObject]@{
        Name             = $Name
        Url              = $Url
        Token            = $Token
        IsAzure          = $isAzure
        ResourceGroup    = $ResourceGroup
        WebAppName       = $WebAppName
        UrlVariable      = $urlVariable
        TokenVariable    = $tokenVariable
        UsesPublishPoint = [bool]$definition.UsesPublishPoint
    }
}
