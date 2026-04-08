BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSetup.ps1')
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
}

Describe 'BuildCIEMEntraTransitiveMembership' {
    BeforeEach {
        Initialize-DiscoveryTestDatabase
        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    }

    It 'Builds transitive group membership from direct member_of relationships' {
        InModuleScope Devolutions.CIEM {
            $relationships = @(
                [pscustomobject]@{ SourceId = 'user-1'; SourceType = 'user'; TargetId = 'group-a'; TargetType = 'group'; Relationship = 'member_of'; CollectedAt = '2026-01-01T00:00:00Z' }
                [pscustomobject]@{ SourceId = 'group-a'; SourceType = 'group'; TargetId = 'group-b'; TargetType = 'group'; Relationship = 'member_of'; CollectedAt = '2026-01-01T00:00:00Z' }
                [pscustomobject]@{ SourceId = 'group-b'; SourceType = 'group'; TargetId = 'group-c'; TargetType = 'group'; Relationship = 'member_of'; CollectedAt = '2026-01-01T00:00:00Z' }
            )

            $results = @(BuildCIEMEntraTransitiveMembership -Relationships $relationships -CollectedAt '2026-01-02T00:00:00Z')

            $results | Should -HaveCount 6
            ($results | Where-Object { $_.SourceId -eq 'user-1' }).TargetId | Sort-Object | Should -Be @('group-a', 'group-b', 'group-c')
            ($results | Where-Object { $_.SourceId -eq 'group-a' }).TargetId | Sort-Object | Should -Be @('group-b', 'group-c')
            ($results | Where-Object { $_.SourceId -eq 'group-b' }).TargetId | Should -Be 'group-c'
        }
    }

    It 'Terminates when there is a self-reference cycle' {
        InModuleScope Devolutions.CIEM {
            $relationships = @(
                [pscustomobject]@{ SourceId = 'user-1'; SourceType = 'user'; TargetId = 'group-a'; TargetType = 'group'; Relationship = 'member_of'; CollectedAt = '2026-01-01T00:00:00Z' }
                [pscustomobject]@{ SourceId = 'group-a'; SourceType = 'group'; TargetId = 'group-a'; TargetType = 'group'; Relationship = 'member_of'; CollectedAt = '2026-01-01T00:00:00Z' }
            )

            $results = @(BuildCIEMEntraTransitiveMembership -Relationships $relationships -CollectedAt '2026-01-02T00:00:00Z')

            $results | Should -HaveCount 2
            ($results | Where-Object { $_.SourceId -eq 'user-1' }).TargetId | Should -Be 'group-a'
            ($results | Where-Object { $_.SourceId -eq 'group-a' }).TargetId | Should -Be 'group-a'
        }
    }

    It 'Returns an empty set for orphan users' {
        InModuleScope Devolutions.CIEM {
            $results = @(BuildCIEMEntraTransitiveMembership -Relationships @() -CollectedAt '2026-01-02T00:00:00Z')
            $results | Should -HaveCount 0
        }
    }

    It 'Deduplicates users reachable through two paths' {
        InModuleScope Devolutions.CIEM {
            $relationships = @(
                [pscustomobject]@{ SourceId = 'user-1'; SourceType = 'user'; TargetId = 'group-a'; TargetType = 'group'; Relationship = 'member_of'; CollectedAt = '2026-01-01T00:00:00Z' }
                [pscustomobject]@{ SourceId = 'user-1'; SourceType = 'user'; TargetId = 'group-b'; TargetType = 'group'; Relationship = 'member_of'; CollectedAt = '2026-01-01T00:00:00Z' }
                [pscustomobject]@{ SourceId = 'group-a'; SourceType = 'group'; TargetId = 'group-c'; TargetType = 'group'; Relationship = 'member_of'; CollectedAt = '2026-01-01T00:00:00Z' }
                [pscustomobject]@{ SourceId = 'group-b'; SourceType = 'group'; TargetId = 'group-c'; TargetType = 'group'; Relationship = 'member_of'; CollectedAt = '2026-01-01T00:00:00Z' }
            )

            $results = @(BuildCIEMEntraTransitiveMembership -Relationships $relationships -CollectedAt '2026-01-02T00:00:00Z')

            ($results | Where-Object { $_.TargetId -eq 'group-c' -and $_.SourceId -eq 'user-1' }) | Should -HaveCount 1
        }
    }
}
