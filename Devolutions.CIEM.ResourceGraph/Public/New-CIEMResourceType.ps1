function New-CIEMResourceType {
    <#
    .SYNOPSIS
        Adds a new resource type to the azure.resource-types.json schema.
    .DESCRIPTION
        Registers a new ARM resource type in the schema file so it participates in
        dependency graph building. Validates that the type doesn't already exist and
        that all dependency path entries have a valid Path value.
    .EXAMPLE
        New-CIEMResourceType -ArmType 'Microsoft.Web/sites' -DisplayName 'App Service' -Category compute
    .EXAMPLE
        New-CIEMResourceType -ArmType 'Microsoft.Sql/servers' -DisplayName 'SQL Server' -Category database -DependencyPaths @{
            identity = @{ Path = 'identity.userAssignedIdentities' }
        }
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([ResourceType])]
    param(
        [Parameter(Mandatory)]
        [string]$ArmType,

        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [ValidateSet('compute', 'network', 'storage', 'security', 'identity', 'database', 'container')]
        [string]$Category,

        [Parameter()]
        [hashtable]$DependencyPaths = @{}
    )
    $ErrorActionPreference = 'Stop'

    $schemaPath = Join-Path $PSScriptRoot '..' 'Schemas' 'azure.resource-types.json'
    if (-not (Test-Path $schemaPath)) {
        throw "Resource type schema not found at: $schemaPath"
    }

    $schema = Get-Content -Path $schemaPath -Raw | ConvertFrom-Json

    # Error if ArmType already exists
    $existing = $schema.resourceTypes.PSObject.Properties | Where-Object { $_.Name -eq $ArmType }
    if ($existing) {
        throw "Resource type '$ArmType' already exists in schema."
    }

    # Validate dependency paths
    foreach ($entry in $DependencyPaths.GetEnumerator()) {
        if (-not $entry.Value.Path) {
            throw "Dependency path '$($entry.Key)' is missing required 'Path' key."
        }
    }

    # Build the ResourceType object
    $rt = [ResourceType]::new()
    $rt.ArmType = $ArmType
    $rt.Category = $Category
    $rt.DisplayName = $DisplayName
    foreach ($entry in $DependencyPaths.GetEnumerator()) {
        $rt.DependencyPaths[$entry.Key] = [DependencyPath]::new($entry.Value.Path)
    }

    if ($PSCmdlet.ShouldProcess($ArmType, 'Add resource type to schema')) {
        # Add to schema and write back
        $schema.resourceTypes | Add-Member -NotePropertyName $ArmType -NotePropertyValue $rt.ToSchemaEntry()
        $schema | ConvertTo-Json -Depth 10 | Set-Content -Path $schemaPath -Encoding utf8
        return $rt
    }
}
