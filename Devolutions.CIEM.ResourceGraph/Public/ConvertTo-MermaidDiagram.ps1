function ConvertTo-MermaidDiagram {
    <#
    .SYNOPSIS
        Converts a ResourceDependencyGraph to a Mermaid flowchart diagram string.
    .DESCRIPTION
        Takes a ResourceDependencyGraph object and produces Mermaid-compatible diagram syntax
        that can be rendered by the ud-mermaid PSU component (New-UDMermaid).
        Nodes are color-coded by category (compute, network, storage, security).
    .EXAMPLE
        $graph = New-ResourceDependencyGraph -Resources $armResources
        $diagram = ConvertTo-MermaidDiagram -Graph $graph
        New-UDMermaid -Diagram $diagram
    .EXAMPLE
        ConvertTo-MermaidDiagram -Graph $graph -Direction LR
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object]$Graph,

        [Parameter()]
        [ValidateSet('TD', 'LR', 'BT', 'RL')]
        [string]$Direction = 'TD'
    )
    $ErrorActionPreference = 'Stop'

    $schema = Read-ResourceTypeSchema

    # Build node ID mapping (ARM ID -> short Mermaid-safe ID)
    $nodeMap = @{}
    $index = 0
    foreach ($node in $Graph.Nodes.Values) {
        $nodeMap[$node.Id] = "n$index"
        $index++
    }

    $lines = [System.Collections.ArrayList]::new()
    [void]$lines.Add("graph $Direction")

    # Node definitions with display labels
    $nodeCategories = @{}
    foreach ($node in $Graph.Nodes.Values) {
        $shortId = $nodeMap[$node.Id]
        $typeEntry = $schema[$node.Type]
        $displayName = if ($typeEntry) { $typeEntry.DisplayName } else { ($node.Type -split '/')[-1] }
        # Sanitize labels: escape characters meaningful to Mermaid syntax and HTML injection
        $safeName = $node.Name -replace '["<>#;&`/\\|\[\]{}()]', '_'
        $safeDisplay = $displayName -replace '["<>#;&`/\\|\[\]{}()]', '_'
        $label = "$safeDisplay<br/>$safeName"

        [void]$lines.Add("    ${shortId}[`"$label`"]")

        # Track category for styling
        $category = if ($typeEntry) { $typeEntry.Category } else { 'compute' }
        if (-not $nodeCategories[$category]) { $nodeCategories[$category] = [System.Collections.ArrayList]::new() }
        [void]$nodeCategories[$category].Add($shortId)
    }

    # Edge definitions (deduplicate bidirectional pairs — Mermaid renders them poorly)
    $renderedPairs = @{}
    foreach ($edge in $Graph.Edges) {
        $sourceId = $nodeMap[$edge.SourceId]
        $targetId = $nodeMap[$edge.TargetId]
        $label = if ($edge.Cardinality -eq [ResourceCardinality]::OneToMany) { '1:N' } else { '1:1' }

        # Check if the reverse edge was already rendered
        $reverseKey = "${targetId}|${sourceId}"
        if ($renderedPairs.ContainsKey($reverseKey)) {
            # Skip — reverse direction already rendered
            continue
        }

        $forwardKey = "${sourceId}|${targetId}"
        $renderedPairs[$forwardKey] = $true
        [void]$lines.Add("    ${sourceId} -->|${label}| ${targetId}")
    }

    # Category color styles
    $categoryStyles = @{
        compute   = 'fill:#4A90D9,stroke:#2C5F8A,color:#fff'
        network   = 'fill:#50B83C,stroke:#2E7D20,color:#fff'
        storage   = 'fill:#F49342,stroke:#C26D1A,color:#fff'
        security  = 'fill:#DE3618,stroke:#A02010,color:#fff'
        database  = 'fill:#47C1BF,stroke:#2E8B89,color:#fff'
        container = 'fill:#006FBB,stroke:#004C80,color:#fff'
    }

    foreach ($entry in $categoryStyles.GetEnumerator()) {
        [void]$lines.Add("    classDef $($entry.Key) $($entry.Value)")
    }

    # Apply styles to nodes by category
    foreach ($entry in $nodeCategories.GetEnumerator()) {
        $nodeList = $entry.Value -join ','
        [void]$lines.Add("    class ${nodeList} $($entry.Key)")
    }

    return ($lines -join "`n")
}
