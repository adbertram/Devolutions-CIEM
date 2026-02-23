function Read-ResourceTypeSchema {
    <#
    .SYNOPSIS
        Loads the azure.resource-types.json schema file (cached after first read).
    .DESCRIPTION
        Reads the resource types schema from the module's Schemas directory and returns
        a hashtable keyed by ARM resource type, each containing a dependencyPaths sub-hashtable.
        Results are cached in module scope to avoid repeated disk I/O.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    $ErrorActionPreference = 'Stop'

    if ($script:CachedResourceTypeSchema) {
        return $script:CachedResourceTypeSchema
    }

    $schemaPath = Join-Path $PSScriptRoot '..' 'Schemas' 'azure.resource-types.json'
    if (-not (Test-Path $schemaPath)) {
        throw "Resource type schema not found at: $schemaPath"
    }

    $schema = Get-Content -Path $schemaPath -Raw | ConvertFrom-Json

    $result = @{}
    foreach ($prop in $schema.resourceTypes.PSObject.Properties) {
        $result[$prop.Name] = [ResourceType]::FromSchemaEntry($prop.Name, $prop.Value)
    }

    $script:CachedResourceTypeSchema = $result
    return $result
}
