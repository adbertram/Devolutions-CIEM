function GetCIEMStableAttackPathProgressKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$AttackPath
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace([string]$AttackPath.RuleId)) {
        throw 'Attack path progress keys require a non-empty RuleId.'
    }

    $pathNodes = @($AttackPath.Path)
    if ($pathNodes.Count -eq 0) {
        throw "Attack path '$($AttackPath.Id)' has no path nodes."
    }

    $canonicalPath = @(foreach ($node in $pathNodes) {
        if ([string]::IsNullOrWhiteSpace([string]$node.kind)) {
            throw "Attack path '$($AttackPath.Id)' has a path node with blank kind."
        }
        if ([string]::IsNullOrWhiteSpace([string]$node.id)) {
            throw "Attack path '$($AttackPath.Id)' has a path node with blank id."
        }

        [ordered]@{
            kind = [string]$node.kind
            id   = [string]$node.id
        }
    })

    $canonicalEdges = @(foreach ($edge in @($AttackPath.Edges)) {
        foreach ($propertyName in @('source_id', 'target_id', 'kind')) {
            if (-not $edge.PSObject.Properties[$propertyName]) {
                throw "Attack path '$($AttackPath.Id)' edge is missing '$propertyName'."
            }
            if ([string]::IsNullOrWhiteSpace([string]$edge.$propertyName)) {
                throw "Attack path '$($AttackPath.Id)' edge has blank '$propertyName'."
            }
        }

        [ordered]@{
            sourceId = [string]$edge.source_id
            targetId = [string]$edge.target_id
            kind     = [string]$edge.kind
        }
    })

    $payload = [ordered]@{
        ruleId = [string]$AttackPath.RuleId
        path   = $canonicalPath
        edges  = $canonicalEdges
    } | ConvertTo-Json -Depth 20 -Compress

    "attack-path:$(GetCIEMSHA256Hash -InputText $payload)"
}
