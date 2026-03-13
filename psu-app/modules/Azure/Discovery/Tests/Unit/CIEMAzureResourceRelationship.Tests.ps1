BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    # Create isolated test DB with base + azure + discovery schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'
    if (Test-Path $azureSchema) {
        Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)
    }

    $discoverySchema = Join-Path $PSScriptRoot '..' 'Data' 'discovery_schema.sql'
    if (Test-Path $discoverySchema) {
        Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)
    }

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Resource Relationship CRUD' {

    Context 'New-CIEMAzureResourceRelationship' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships"
        }

        It 'Creates a relationship with auto-generated Id' {
            $result = New-CIEMAzureResourceRelationship `
                -SourceId 'user-1' -SourceType 'User' `
                -TargetId 'group-1' -TargetType 'Group' `
                -Relationship 'MemberOf' `
                -CollectedAt (Get-Date).ToString('o')
            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -BeOfType [int]
            $result.Id | Should -BeGreaterThan 0
        }

        It 'Consecutive creates return incrementing Ids' {
            $r1 = New-CIEMAzureResourceRelationship -SourceId 'a' -SourceType 'User' -TargetId 'b' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt (Get-Date).ToString('o')
            $r2 = New-CIEMAzureResourceRelationship -SourceId 'c' -SourceType 'User' -TargetId 'd' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt (Get-Date).ToString('o')
            $r2.Id | Should -BeGreaterThan $r1.Id
        }

        It 'Accepts -InputObject parameter set' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureResourceRelationship]::new()
                $o.SourceId = 'sp-1'
                $o.SourceType = 'ServicePrincipal'
                $o.TargetId = 'role-1'
                $o.TargetType = 'DirectoryRole'
                $o.Relationship = 'HasRole'
                $o.CollectedAt = (Get-Date).ToString('o')
                $o
            }
            $result = New-CIEMAzureResourceRelationship -InputObject $obj
            $result | Should -Not -BeNullOrEmpty
            $result.SourceId | Should -Be 'sp-1'
        }

        It 'Mandatory: SourceId, SourceType, TargetId, TargetType, Relationship, CollectedAt' {
            { New-CIEMAzureResourceRelationship -SourceId 'x' -SourceType 'User' -TargetId 'y' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt (Get-Date).ToString('o') } | Should -Not -Throw
            # Missing mandatory should throw
            { New-CIEMAzureResourceRelationship -SourceId 'x' } | Should -Throw
        }

        It 'Throws on duplicate (source_id, target_id, relationship) UNIQUE violation' {
            $ts = (Get-Date).ToString('o')
            New-CIEMAzureResourceRelationship -SourceId 'dup-s' -SourceType 'User' -TargetId 'dup-t' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt $ts
            { New-CIEMAzureResourceRelationship -SourceId 'dup-s' -SourceType 'User' -TargetId 'dup-t' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt $ts } | Should -Throw
        }
    }

    Context 'Get-CIEMAzureResourceRelationship' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships"
            $ts = (Get-Date).ToString('o')
            # Seed test relationships
            New-CIEMAzureResourceRelationship -SourceId 'user-1' -SourceType 'User' -TargetId 'group-1' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt $ts
            New-CIEMAzureResourceRelationship -SourceId 'user-1' -SourceType 'User' -TargetId 'role-1' -TargetType 'DirectoryRole' -Relationship 'HasRole' -CollectedAt $ts
            New-CIEMAzureResourceRelationship -SourceId 'sp-1' -SourceType 'ServicePrincipal' -TargetId 'group-1' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt $ts
            New-CIEMAzureResourceRelationship -SourceId 'vm-1' -SourceType 'VirtualMachine' -TargetId 'nsg-1' -TargetType 'NetworkSecurityGroup' -Relationship 'AttachedTo' -CollectedAt $ts
        }

        It 'Returns all when no filter' {
            $results = Get-CIEMAzureResourceRelationship
            $results.Count | Should -Be 4
        }

        It 'Returns CIEMAzureResourceRelationship typed objects (.GetType().Name -eq CIEMAzureResourceRelationship)' {
            $results = Get-CIEMAzureResourceRelationship
            $results | ForEach-Object { $_.GetType().Name | Should -Be 'CIEMAzureResourceRelationship' }
        }

        It 'Filters by -SourceId' {
            $results = Get-CIEMAzureResourceRelationship -SourceId 'user-1'
            $results.Count | Should -Be 2
        }

        It 'Filters by -TargetId' {
            $results = Get-CIEMAzureResourceRelationship -TargetId 'group-1'
            $results.Count | Should -Be 2
        }

        It 'Filters by -Relationship' {
            $results = Get-CIEMAzureResourceRelationship -Relationship 'MemberOf'
            $results.Count | Should -Be 2
        }

        It 'Filters by -SourceType and -TargetType' {
            $results = Get-CIEMAzureResourceRelationship -SourceType 'User' -TargetType 'DirectoryRole'
            $results.Count | Should -Be 1
            $results[0].Relationship | Should -Be 'HasRole'
        }
    }

    Context 'Update-CIEMAzureResourceRelationship' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships"
            $script:testRel = New-CIEMAzureResourceRelationship -SourceId 'upd-s' -SourceType 'User' -TargetId 'upd-t' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt '2026-01-01T00:00:00Z'
        }

        It 'Updates Relationship field via partial update' {
            Update-CIEMAzureResourceRelationship -Id $script:testRel.Id -Relationship 'OwnerOf'
            $result = Get-CIEMAzureResourceRelationship -SourceId 'upd-s'
            $result.Relationship | Should -Be 'OwnerOf'
        }

        It 'Updates CollectedAt without overwriting other fields' {
            Update-CIEMAzureResourceRelationship -Id $script:testRel.Id -CollectedAt '2026-03-01T00:00:00Z'
            $result = Get-CIEMAzureResourceRelationship -SourceId 'upd-s'
            $result.CollectedAt | Should -Be '2026-03-01T00:00:00Z'
            $result.SourceType | Should -Be 'User'
            $result.TargetId | Should -Be 'upd-t'
        }

        It 'Returns nothing without -PassThru' {
            $result = Update-CIEMAzureResourceRelationship -Id $script:testRel.Id -Relationship 'Changed'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns updated object with -PassThru' {
            $result = Update-CIEMAzureResourceRelationship -Id $script:testRel.Id -Relationship 'OwnerOf' -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'CIEMAzureResourceRelationship'
            $result.Relationship | Should -Be 'OwnerOf'
        }

        It 'Accepts -InputObject for full object update' {
            $obj = Get-CIEMAzureResourceRelationship -SourceId 'upd-s'
            $obj = $obj | Select-Object -First 1
            $obj.Relationship = 'AdminOf'
            $obj.TargetType = 'Application'
            Update-CIEMAzureResourceRelationship -InputObject $obj
            $result = Get-CIEMAzureResourceRelationship -SourceId 'upd-s'
            $result.Relationship | Should -Be 'AdminOf'
            $result.TargetType | Should -Be 'Application'
        }
    }

    Context 'Save-CIEMAzureResourceRelationship' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships"
        }

        It 'INSERT OR REPLACE honors UNIQUE constraint (updates on conflict)' {
            $ts = (Get-Date).ToString('o')
            Save-CIEMAzureResourceRelationship -SourceId 'save-s' -SourceType 'User' -TargetId 'save-t' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt $ts
            Save-CIEMAzureResourceRelationship -SourceId 'save-s' -SourceType 'UserV2' -TargetId 'save-t' -TargetType 'GroupV2' -Relationship 'MemberOf' -CollectedAt $ts
            # UNIQUE(source_id, target_id, relationship) — should be 1 row, not 2
            $results = Get-CIEMAzureResourceRelationship
            $results.Count | Should -Be 1
            $results[0].SourceType | Should -Be 'UserV2'
        }

        It 'Accepts -InputObject via pipeline' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureResourceRelationship]::new()
                $o.SourceId = 'pipe-s'
                $o.SourceType = 'ServicePrincipal'
                $o.TargetId = 'pipe-t'
                $o.TargetType = 'DirectoryRole'
                $o.Relationship = 'HasRole'
                $o.CollectedAt = (Get-Date).ToString('o')
                $o
            }
            $obj | Save-CIEMAzureResourceRelationship
            $result = Get-CIEMAzureResourceRelationship -SourceId 'pipe-s'
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Remove-CIEMAzureResourceRelationship' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_resource_relationships"
            $ts = (Get-Date).ToString('o')
            $script:rmRel1 = New-CIEMAzureResourceRelationship -SourceId 'rm-s1' -SourceType 'User' -TargetId 'rm-t1' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt $ts
            New-CIEMAzureResourceRelationship -SourceId 'rm-s2' -SourceType 'User' -TargetId 'rm-t2' -TargetType 'Group' -Relationship 'MemberOf' -CollectedAt $ts
            New-CIEMAzureResourceRelationship -SourceId 'rm-s3' -SourceType 'ServicePrincipal' -TargetId 'rm-t3' -TargetType 'DirectoryRole' -Relationship 'HasRole' -CollectedAt $ts
        }

        It 'Removes by -Id (integer)' {
            Remove-CIEMAzureResourceRelationship -Id $script:rmRel1.Id -Confirm:$false
            $result = Get-CIEMAzureResourceRelationship -SourceId 'rm-s1'
            $result | Should -BeNullOrEmpty
            (Get-CIEMAzureResourceRelationship).Count | Should -Be 2
        }

        It 'Removes by combo: -SourceId + -TargetId + -Relationship' {
            Remove-CIEMAzureResourceRelationship -SourceId 'rm-s2' -TargetId 'rm-t2' -Relationship 'MemberOf' -Confirm:$false
            $result = Get-CIEMAzureResourceRelationship -SourceId 'rm-s2'
            $result | Should -BeNullOrEmpty
        }

        It 'Removes all records with -All switch' {
            Remove-CIEMAzureResourceRelationship -All -Confirm:$false
            $results = Get-CIEMAzureResourceRelationship
            $results | Should -BeNullOrEmpty
        }

        It 'Removes via -InputObject' {
            $obj = Get-CIEMAzureResourceRelationship -SourceId 'rm-s3'
            Remove-CIEMAzureResourceRelationship -InputObject $obj -Confirm:$false
            $result = Get-CIEMAzureResourceRelationship -SourceId 'rm-s3'
            $result | Should -BeNullOrEmpty
        }

        It 'No-ops when Id does not exist' {
            { Remove-CIEMAzureResourceRelationship -Id 99999 -Confirm:$false } | Should -Not -Throw
        }
    }
}
