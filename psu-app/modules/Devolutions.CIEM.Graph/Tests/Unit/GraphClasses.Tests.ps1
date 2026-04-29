BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Graph Classes' {

    Context 'CIEMGraphNode class' {
        It 'CIEMGraphNode stores and retrieves all properties (Id, Kind, DisplayName, Provider, SubscriptionId, ResourceGroup, Properties, CollectedAt)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMGraphNode]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'Id'
            $props | Should -Contain 'Kind'
            $props | Should -Contain 'DisplayName'
            $props | Should -Contain 'Provider'
            $props | Should -Contain 'SubscriptionId'
            $props | Should -Contain 'ResourceGroup'
            $props | Should -Contain 'Properties'
            $props | Should -Contain 'CollectedAt'
        }
    }

    Context 'CIEMGraphEdge class' {
        It 'CIEMGraphEdge stores and retrieves all properties (Id, SourceId, TargetId, Kind, Properties, Computed, CollectedAt)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMGraphEdge]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'Id'
            $props | Should -Contain 'SourceId'
            $props | Should -Contain 'TargetId'
            $props | Should -Contain 'Kind'
            $props | Should -Contain 'Properties'
            $props | Should -Contain 'Computed'
            $props | Should -Contain 'CollectedAt'
        }
    }

    Context 'CIEMAttackPath class' {
        It 'CIEMAttackPath stores and retrieves pattern metadata (PatternId, PatternName, Severity, Category)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMAttackPath]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'PatternId'
            $props | Should -Contain 'PatternName'
            $props | Should -Contain 'Severity'
            $props | Should -Contain 'Category'
        }

        It 'CIEMAttackPath stores and retrieves path data (Path, Edges)' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMAttackPath]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'Path'
            $props | Should -Contain 'Edges'
        }

        It 'CIEMAttackPath Path and Edges default to empty arrays' {
            $obj = InModuleScope Devolutions.CIEM {
                $a = [CIEMAttackPath]::new()
                @{ PathCount = @($a.Path).Count; EdgesCount = @($a.Edges).Count }
            }
            $obj.PathCount | Should -Be 0
            $obj.EdgesCount | Should -Be 0
        }

        It 'CIEMAttackPath accepts assigned values for all properties' {
            $obj = InModuleScope Devolutions.CIEM {
                $a = [CIEMAttackPath]::new()
                $a.PatternId = 'test-pattern'
                $a.PatternName = 'Test Pattern'
                $a.Severity = 'critical'
                $a.Category = 'identity'
                $a.Path = @([PSCustomObject]@{ id = 'node1'; kind = 'EntraUser' })
                $a.Edges = @([PSCustomObject]@{ id = 1; kind = 'HasRole' })
                @{
                    PatternId = $a.PatternId
                    PatternName = $a.PatternName
                    Severity = $a.Severity
                    Category = $a.Category
                    PathCount = $a.Path.Count
                    PathKind = $a.Path[0].kind
                    EdgeCount = $a.Edges.Count
                    EdgeKind = $a.Edges[0].kind
                }
            }
            $obj.PatternId | Should -Be 'test-pattern'
            $obj.PatternName | Should -Be 'Test Pattern'
            $obj.Severity | Should -Be 'critical'
            $obj.Category | Should -Be 'identity'
            $obj.PathCount | Should -Be 1
            $obj.PathKind | Should -Be 'EntraUser'
            $obj.EdgeCount | Should -Be 1
            $obj.EdgeKind | Should -Be 'HasRole'
        }
    }

    Context 'CIEMAttackPathRule class' {
        It 'CIEMAttackPathRule stores database-backed rule metadata and PSU script references' {
            $obj = InModuleScope Devolutions.CIEM { [CIEMAttackPathRule]::new() }
            $props = $obj.PSObject.Properties.Name
            $props | Should -Contain 'Id'
            $props | Should -Contain 'Name'
            $props | Should -Contain 'Severity'
            $props | Should -Contain 'Category'
            $props | Should -Contain 'Description'
            $props | Should -Contain 'Remediation'
            $props | Should -Contain 'RemediationScriptPath'
            $props | Should -Contain 'PsuScriptName'
            $props | Should -Contain 'Steps'
            $props | Should -Contain 'StepCount'
            $props | Should -Contain 'Disabled'
            $props | Should -Contain 'UpdatedAt'
        }

        It 'CIEMAttackPathRule Steps defaults to an empty array' {
            $obj = InModuleScope Devolutions.CIEM {
                $rule = [CIEMAttackPathRule]::new()
                @{ StepCount = @($rule.Steps).Count }
            }
            $obj.StepCount | Should -Be 0
        }
    }
}
