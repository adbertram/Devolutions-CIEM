BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSetup.ps1')
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    $script:LegacyRelationshipFixture = Get-Content (Join-Path $PSScriptRoot '..' 'Fixtures' 'legacy-relationship-output.json') -Raw | ConvertFrom-Json
}

Describe 'InvokeCIEMEntraRelationshipCollection' {
    BeforeEach {
        Initialize-DiscoveryTestDatabase
        $script:relationshipBatchCallSizes = @()
        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
        Mock -ModuleName Devolutions.CIEM Write-Progress {}
    }

    It 'Uses Graph batch requests for group memberships, owners, and directory role members' {
        $groups = foreach ($index in 1..60) {
            [pscustomobject]@{ Id = "group-$index"; DisplayName = "Group $index"; Type = 'group' }
        }
        $roles = @(
            [pscustomobject]@{ Id = 'role-1'; DisplayName = 'Role 1'; Type = 'directoryRole' }
            [pscustomobject]@{ Id = 'role-2'; DisplayName = 'Role 2'; Type = 'directoryRole' }
        )

        Mock -ModuleName Devolutions.CIEM Invoke-AzureApi {
            $script:relationshipBatchCallSizes += @($Requests).Count
            $results = @{}
            foreach ($request in @($Requests)) {
                $results[$request.Id] = [pscustomobject]@{
                    Success = $true
                    StatusCode = 200
                    Items = @()
                }
            }
            $results
        }

        $result = InModuleScope Devolutions.CIEM -Parameters @{ groups = $groups; roles = $roles } {
            @(InvokeCIEMEntraRelationshipCollection -Groups $groups -DirectoryRoles $roles -Users @())
        }

        $result | Should -HaveCount 0
        $script:relationshipBatchCallSizes | Should -HaveCount 2
        $script:relationshipBatchCallSizes[0] | Should -Be 120
        $script:relationshipBatchCallSizes[1] | Should -Be 2
    }

    It 'Builds direct and transitive membership relationships without per-user transitiveMemberOf calls' {
        $groups = @(
            [pscustomobject]@{ Id = 'group-a'; DisplayName = 'Group A'; Type = 'group' }
            [pscustomobject]@{ Id = 'group-b'; DisplayName = 'Group B'; Type = 'group' }
        )
        $users = @(
            [pscustomobject]@{ Id = 'user-1'; DisplayName = 'User 1'; Type = 'user' }
        )
        $script:relationshipRequestPaths = @()

        Mock -ModuleName Devolutions.CIEM Invoke-AzureApi {
            $script:relationshipRequestPaths += @($Requests | ForEach-Object { $_.Path })
            $results = @{}
            foreach ($request in @($Requests)) {
                switch -Wildcard ($request.Path) {
                    '/groups/group-a/members*' {
                        $results[$request.Id] = [pscustomobject]@{
                            Success = $true
                            StatusCode = 200
                            Items = @(
                                [pscustomobject]@{ id = 'user-1'; '@odata.type' = '#microsoft.graph.user' }
                            )
                        }
                    }
                    '/groups/group-a/owners*' {
                        $results[$request.Id] = [pscustomobject]@{
                            Success = $true
                            StatusCode = 200
                            Items = @([pscustomobject]@{ id = 'user-1'; '@odata.type' = '#microsoft.graph.user' })
                        }
                    }
                    '/groups/group-b/members*' {
                        $results[$request.Id] = [pscustomobject]@{
                            Success = $true
                            StatusCode = 200
                            Items = @(
                                [pscustomobject]@{ id = 'group-a'; '@odata.type' = '#microsoft.graph.group' }
                            )
                        }
                    }
                    '/groups/group-b/owners*' {
                        $results[$request.Id] = [pscustomobject]@{
                            Success = $true
                            StatusCode = 200
                            Items = @()
                        }
                    }
                    default {
                        $results[$request.Id] = [pscustomobject]@{
                            Success = $true
                            StatusCode = 200
                            Items = @()
                        }
                    }
                }
            }
            $results
        }

        $relationships = InModuleScope Devolutions.CIEM -Parameters @{ groups = $groups; users = $users } {
            @(InvokeCIEMEntraRelationshipCollection -Groups $groups -DirectoryRoles @() -Users $users)
        }

        ($relationships | Where-Object { $_.Relationship -eq 'member_of' }) | Should -HaveCount 2
        ($relationships | Where-Object { $_.Relationship -eq 'owner_of' }) | Should -HaveCount 1
        ($relationships | Where-Object { $_.Relationship -eq 'transitive_member_of' -and $_.SourceId -eq 'user-1' }).TargetId | Sort-Object | Should -Be @('group-a', 'group-b')
        @($script:relationshipRequestPaths | Where-Object { $_ -like '/users/*/transitiveMemberOf*' }) | Should -BeNullOrEmpty

        $normalizedRelationships = @(
            $relationships |
                Sort-Object SourceId, SourceType, TargetId, TargetType, Relationship |
                ForEach-Object {
                    [pscustomobject]@{
                        SourceId = $_.SourceId
                        SourceType = $_.SourceType
                        TargetId = $_.TargetId
                        TargetType = $_.TargetType
                        Relationship = $_.Relationship
                    }
                }
        )
        $normalizedFixture = @(
            $script:LegacyRelationshipFixture |
                Sort-Object SourceId, SourceType, TargetId, TargetType, Relationship
        )

        ($normalizedRelationships | ConvertTo-Json -Depth 5) | Should -Be ($normalizedFixture | ConvertTo-Json -Depth 5)
    }
}
