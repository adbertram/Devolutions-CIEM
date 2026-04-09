BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    # Create isolated test DB with base + azure + discovery schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    foreach ($schemaPath in @(
        (Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'),
        (Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql')
    )) {
        foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            Invoke-CIEMQuery -Query $statement.Trim() -AsNonQuery | Out-Null
        }
    }
}

Describe 'Entra Resource CRUD' {

    Context 'New-CIEMAzureEntraResource' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
        }

        It 'Creates a resource and returns CIEMAzureEntraResource object' {
            $result = New-CIEMAzureEntraResource -Id 'aaaabbbb-cccc-dddd-eeee-ffffffffffff' `
                -Type 'User' `
                -DisplayName 'Test User' `
                -Properties '{"userPrincipalName":"test@contoso.com"}'
            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'CIEMAzureEntraResource'
            $result.Id | Should -Be 'aaaabbbb-cccc-dddd-eeee-ffffffffffff'
            $result.DisplayName | Should -Be 'Test User'
        }

        It 'Throws when resource with same Id already exists' {
            New-CIEMAzureEntraResource -Id 'dup-entra-id' -Type 'User' -DisplayName 'Original'
            { New-CIEMAzureEntraResource -Id 'dup-entra-id' -Type 'Group' -DisplayName 'Duplicate' } | Should -Throw
        }

        It 'Accepts -InputObject parameter set' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureEntraResource]::new()
                $o.Id = 'input-entra-id'
                $o.Type = 'ServicePrincipal'
                $o.DisplayName = 'Test SP'
                $o
            }
            $result = New-CIEMAzureEntraResource -InputObject $obj
            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be 'input-entra-id'
        }
    }

    Context 'Get-CIEMAzureEntraResource' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            # Seed test data
            New-CIEMAzureEntraResource -Id 'user-get1' -Type 'User' -DisplayName 'Alice'
            New-CIEMAzureEntraResource -Id 'user-get2' -Type 'User' -DisplayName 'Bob'
            New-CIEMAzureEntraResource -Id 'group-get1' -Type 'Group' -DisplayName 'Engineering' -ParentId 'tenant-root'
            New-CIEMAzureEntraResource -Id 'sp-get1' -Type 'ServicePrincipal' -DisplayName 'Alice' -ParentId 'app-reg-1'
        }

        It 'Returns all resources when no filter' {
            $results = Get-CIEMAzureEntraResource
            $results | Should -HaveCount 4
        }

        It 'Returns CIEMAzureEntraResource typed objects (.GetType().Name -eq CIEMAzureEntraResource)' {
            $results = Get-CIEMAzureEntraResource
            $results | ForEach-Object { $_.GetType().Name | Should -Be 'CIEMAzureEntraResource' }
        }

        It 'Filters by -Id' {
            $result = Get-CIEMAzureEntraResource -Id 'user-get1'
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be 'Alice'
            $result.Type | Should -Be 'User'
        }

        It 'Filters by -Type' {
            $results = Get-CIEMAzureEntraResource -Type 'User'
            $results | Should -HaveCount 2
        }

        It 'Filters by -ParentId' {
            $results = Get-CIEMAzureEntraResource -ParentId 'tenant-root'
            $results | Should -HaveCount 1
            $results[0].DisplayName | Should -Be 'Engineering'
        }

        It 'Filters by -DisplayName' {
            $results = Get-CIEMAzureEntraResource -DisplayName 'Alice'
            $results | Should -HaveCount 2  # User Alice + SP Alice
        }

        It 'Returns empty array when no match' {
            $results = Get-CIEMAzureEntraResource -Id 'nonexistent-id'
            $results | Should -BeNullOrEmpty
        }
    }

    Context 'Update-CIEMAzureEntraResource' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            New-CIEMAzureEntraResource -Id 'entra-upd' -Type 'User' -DisplayName 'Original Name' -Properties '{"mail":"old@contoso.com"}'
        }

        It 'Updates Properties field' {
            Update-CIEMAzureEntraResource -Id 'entra-upd' -Properties '{"mail":"new@contoso.com"}'
            $result = Get-CIEMAzureEntraResource -Id 'entra-upd'
            $result.Properties | Should -Be '{"mail":"new@contoso.com"}'
        }

        It 'Partial update does not overwrite unspecified fields' {
            Update-CIEMAzureEntraResource -Id 'entra-upd' -Properties '{"updated":true}'
            $result = Get-CIEMAzureEntraResource -Id 'entra-upd'
            $result.DisplayName | Should -Be 'Original Name'
            $result.Type | Should -Be 'User'
        }

        It 'Returns nothing without -PassThru' {
            $result = Update-CIEMAzureEntraResource -Id 'entra-upd' -Properties '{"x":1}'
            $result | Should -BeNullOrEmpty
        }

        It 'Returns updated object with -PassThru' {
            $result = Update-CIEMAzureEntraResource -Id 'entra-upd' -Properties '{"passthru":true}' -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'CIEMAzureEntraResource'
            $result.Properties | Should -Be '{"passthru":true}'
        }

        It 'Accepts -InputObject for full object update' {
            $obj = Get-CIEMAzureEntraResource -Id 'entra-upd'
            $obj.DisplayName = 'Updated Name'
            $obj.ParentId = 'new-parent'
            Update-CIEMAzureEntraResource -InputObject $obj
            $result = Get-CIEMAzureEntraResource -Id 'entra-upd'
            $result.DisplayName | Should -Be 'Updated Name'
            $result.ParentId | Should -Be 'new-parent'
        }
    }

    Context 'Save-CIEMAzureEntraResource' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
        }

        It 'Inserts new record (upsert)' {
            Save-CIEMAzureEntraResource -Id 'entra-save-new' -Type 'Group' -DisplayName 'New Group'
            $result = Get-CIEMAzureEntraResource -Id 'entra-save-new'
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be 'New Group'
        }

        It 'Updates existing record (upsert)' {
            Save-CIEMAzureEntraResource -Id 'entra-save-up' -Type 'User' -DisplayName 'Original'
            Save-CIEMAzureEntraResource -Id 'entra-save-up' -Type 'User' -DisplayName 'Updated'
            $result = Get-CIEMAzureEntraResource -Id 'entra-save-up'
            $result.DisplayName | Should -Be 'Updated'
            # Only 1 row, not 2
            $all = Get-CIEMAzureEntraResource
            $all | Should -HaveCount 1
        }

        It 'Accepts -InputObject via pipeline' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureEntraResource]::new()
                $o.Id = 'entra-pipe'
                $o.Type = 'ServicePrincipal'
                $o.DisplayName = 'Piped SP'
                $o.CollectedAt = (Get-Date).ToString('o')
                $o
            }
            $obj | Save-CIEMAzureEntraResource
            $result = Get-CIEMAzureEntraResource -Id 'entra-pipe'
            $result | Should -Not -BeNullOrEmpty
            $result.DisplayName | Should -Be 'Piped SP'
        }
    }

    Context 'Remove-CIEMAzureEntraResource' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_entra_resources"
            New-CIEMAzureEntraResource -Id 'entra-rm1' -Type 'User' -DisplayName 'User RM1'
            New-CIEMAzureEntraResource -Id 'entra-rm2' -Type 'User' -DisplayName 'User RM2'
            New-CIEMAzureEntraResource -Id 'entra-rm3' -Type 'Group' -DisplayName 'Group RM1'
        }

        It 'Removes by -Id' {
            Remove-CIEMAzureEntraResource -Id 'entra-rm1' -Confirm:$false
            $result = Get-CIEMAzureEntraResource -Id 'entra-rm1'
            $result | Should -BeNullOrEmpty
            # Other resources still exist
            Get-CIEMAzureEntraResource | Should -HaveCount 2
        }

        It 'Bulk removes by -Type' {
            Remove-CIEMAzureEntraResource -Type 'User' -Confirm:$false
            $users = Get-CIEMAzureEntraResource -Type 'User'
            $users | Should -BeNullOrEmpty
            # Group still exists
            $groups = Get-CIEMAzureEntraResource -Type 'Group'
            $groups | Should -HaveCount 1
        }

        It 'Removes all records with -All switch' {
            Remove-CIEMAzureEntraResource -All -Confirm:$false
            $results = Get-CIEMAzureEntraResource
            $results | Should -BeNullOrEmpty
        }

        It 'Removes via -InputObject' {
            $obj = Get-CIEMAzureEntraResource -Id 'entra-rm3'
            Remove-CIEMAzureEntraResource -InputObject $obj -Confirm:$false
            $result = Get-CIEMAzureEntraResource -Id 'entra-rm3'
            $result | Should -BeNullOrEmpty
        }

        It 'No-ops when Id does not exist' {
            { Remove-CIEMAzureEntraResource -Id 'nonexistent-entra' -Confirm:$false } | Should -Not -Throw
        }
    }
}
