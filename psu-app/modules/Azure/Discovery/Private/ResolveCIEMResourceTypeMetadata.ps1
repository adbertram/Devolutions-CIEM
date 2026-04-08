function ResolveCIEMResourceTypeMetadata {
    <#
    .SYNOPSIS
        Resolves an Azure/Entra resource type string to the api_source and
        graph_table metadata written into the azure_resource_types table.

    .DESCRIPTION
        Replaces the 3-arm if/elseif chain previously inlined inside
        Start-CIEMAzureDiscovery's Save-ResourceTypes nested helper with a
        single table-driven lookup. The decision rules are:

        microsoft.resources/*     -> ResourceGraph / ResourceContainers
        microsoft.authorization/* -> ResourceGraph / AuthorizationResources
        microsoft.*               -> ResourceGraph / Resources
        other (Graph entities)    -> Graph / $null
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Type
    )

    $ErrorActionPreference = 'Stop'

    # Ordered list of (prefix-regex, api-source, graph-table) rules evaluated top-down.
    # The first match wins. A final catch-all maps non-microsoft types to the Graph API
    # with a null GraphTable (since the azure_resource_types.graph_table column is
    # ResourceGraph-specific).
    $rules = @(
        @{ Pattern = '^microsoft\.resources/';     ApiSource = 'ResourceGraph'; GraphTable = 'ResourceContainers' }
        @{ Pattern = '^microsoft\.authorization/'; ApiSource = 'ResourceGraph'; GraphTable = 'AuthorizationResources' }
        @{ Pattern = '^microsoft\.';               ApiSource = 'ResourceGraph'; GraphTable = 'Resources' }
    )

    foreach ($rule in $rules) {
        if ($Type -match $rule.Pattern) {
            return @{
                ApiSource = $rule.ApiSource
                GraphTable = $rule.GraphTable
            }
        }
    }

    @{
        ApiSource = 'Graph'
        GraphTable = $null
    }
}
