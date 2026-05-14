function GetCIEMAuthenticationProfileFieldSchema {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$Method
    )

    $ErrorActionPreference = 'Stop'

    $schemaPath = Join-Path $script:ModuleRoot 'Data/authentication_profile_field_schema.json'
    if (-not (Test-Path -Path $schemaPath -PathType Leaf)) {
        throw "Authentication profile field schema was not found: $schemaPath"
    }

    $schema = @(Get-Content -Path $schemaPath -Raw | ConvertFrom-Json -Depth 10)

    if ($PSBoundParameters.ContainsKey('Provider')) {
        $schema = @($schema | Where-Object { $_.provider -eq $Provider })
    }
    if ($PSBoundParameters.ContainsKey('Method')) {
        $schema = @($schema | Where-Object { $_.method -eq $Method })
    }

    $schema
}
