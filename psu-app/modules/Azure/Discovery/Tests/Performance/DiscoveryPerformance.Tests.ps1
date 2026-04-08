BeforeAll {
    . (Join-Path $PSScriptRoot '..' 'Unit' 'TestSetup.ps1')
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
}

Describe 'Discovery performance harness' -Tag 'Performance' {
    BeforeEach {
        Initialize-DiscoveryTestDatabase

        $script:PerformanceMetrics = [ordered]@{
            PermissionBatchCallSizes = @()
            RelationshipBatchCallSizes = @()
            RelationshipRequestPaths = @()
            ResourceGraphChunkSizes = @()
            OAuthGrantCalls = 0
        }

        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
        Mock -ModuleName Devolutions.CIEM Write-Progress {}

        InModuleScope Devolutions.CIEM {
            $script:AuthContext = @{
                Azure = [pscustomobject]@{
                    AccountId = 'perf-account'
                    AccountType = 'ServicePrincipal'
                    SubscriptionIds = @(1..1500 | ForEach-Object { "sub-$_" })
                }
            }
            $script:AzureAuthContext = [pscustomobject]@{
                IsConnected = $true
                TenantId = 'tenant-1'
                SubscriptionIds = @(1..1500 | ForEach-Object { "sub-$_" })
                ARMToken = 'arm-token'
                GraphToken = 'graph-token'
                KeyVaultToken = 'kv-token'
            }
        }
    }

    It 'Exercises batched discovery hot paths and writes baseline metrics JSON' {
        $servicePrincipals = @(1..100 | ForEach-Object {
            [pscustomobject]@{ Id = "sp-$_"; DisplayName = "SP $_"; Type = 'servicePrincipal' }
        })
        $groups = @(1..60 | ForEach-Object {
            [pscustomobject]@{ Id = "group-$_"; DisplayName = "Group $_"; Type = 'group' }
        })
        $directoryRoles = @(
            [pscustomobject]@{ Id = 'role-1'; DisplayName = 'Role 1'; Type = 'directoryRole' }
            [pscustomobject]@{ Id = 'role-2'; DisplayName = 'Role 2'; Type = 'directoryRole' }
        )
        $users = @(
            [pscustomobject]@{ Id = 'user-1'; DisplayName = 'User 1'; Type = 'user' }
        )
        $subscriptionIds = @(1..1500 | ForEach-Object { "sub-$_" })

        Mock -ModuleName Devolutions.CIEM Invoke-AzureApi {
            param($Uri, $Path, $Requests, $Api, $ResourceName, $Method, $Body)

            Start-Sleep -Milliseconds 50

            if ($null -ne $Requests) {
                switch ($ResourceName) {
                    'AppRoleAssignmentBatch' {
                        $script:PerformanceMetrics.PermissionBatchCallSizes += @($Requests).Count
                        $results = @{}
                        foreach ($request in @($Requests)) {
                            $results[$request.Id] = [pscustomobject]@{
                                Success = $true
                                StatusCode = 200
                                Items = @(
                                    [pscustomobject]@{
                                        id = "assignment-$($request.Id)"
                                        resourceId = "resource-$($request.Id)"
                                    }
                                )
                            }
                        }
                        return $results
                    }
                    'GroupRelationshipBatch' {
                        $script:PerformanceMetrics.RelationshipBatchCallSizes += @($Requests).Count
                        $script:PerformanceMetrics.RelationshipRequestPaths += @($Requests | ForEach-Object { $_.Path })
                        $results = @{}
                        foreach ($request in @($Requests)) {
                            switch -Wildcard ($request.Path) {
                                '/groups/group-1/members*' {
                                    $results[$request.Id] = [pscustomobject]@{
                                        Success = $true
                                        StatusCode = 200
                                        Items = @([pscustomobject]@{ id = 'user-1'; '@odata.type' = '#microsoft.graph.user' })
                                    }
                                }
                                '/groups/group-1/owners*' {
                                    $results[$request.Id] = [pscustomobject]@{
                                        Success = $true
                                        StatusCode = 200
                                        Items = @([pscustomobject]@{ id = 'user-1'; '@odata.type' = '#microsoft.graph.user' })
                                    }
                                }
                                '/groups/group-2/members*' {
                                    $results[$request.Id] = [pscustomobject]@{
                                        Success = $true
                                        StatusCode = 200
                                        Items = @([pscustomobject]@{ id = 'group-1'; '@odata.type' = '#microsoft.graph.group' })
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
                        return $results
                    }
                    'DirectoryRoleRelationshipBatch' {
                        $script:PerformanceMetrics.RelationshipBatchCallSizes += @($Requests).Count
                        $script:PerformanceMetrics.RelationshipRequestPaths += @($Requests | ForEach-Object { $_.Path })
                        $results = @{}
                        foreach ($request in @($Requests)) {
                            $results[$request.Id] = [pscustomobject]@{
                                Success = $true
                                StatusCode = 200
                                Items = @([pscustomobject]@{ id = 'user-1'; '@odata.type' = '#microsoft.graph.user' })
                            }
                        }
                        return $results
                    }
                    default {
                        throw "Unexpected batch resource '$ResourceName'."
                    }
                }
            }

            if ($ResourceName -eq 'OAuth2PermissionGrants') {
                $script:PerformanceMetrics.OAuthGrantCalls++
                return @(
                    [pscustomobject]@{
                        id = 'grant-1'
                        clientId = 'sp-1'
                        scope = 'User.Read'
                    }
                )
            }

            if ($ResourceName -like 'ResourceGraph/*') {
                $script:PerformanceMetrics.ResourceGraphChunkSizes += @($Body.subscriptions).Count
                return @(
                    foreach ($subscriptionId in @($Body.subscriptions | Select-Object -First 2)) {
                        [pscustomobject]@{
                            id = "/subscriptions/$subscriptionId/resourceGroups/rg-1/providers/Microsoft.Compute/virtualMachines/vm-$subscriptionId"
                            type = 'microsoft.compute/virtualmachines'
                            name = "vm-$subscriptionId"
                            location = 'westus2'
                            resourceGroup = 'rg-1'
                            subscriptionId = $subscriptionId
                            tenantId = 'tenant-1'
                            kind = $null
                            sku = $null
                            identity = $null
                            managedBy = $null
                            plan = $null
                            zones = $null
                            tags = $null
                            properties = @{ hardwareProfile = @{ vmSize = 'Standard_D2s_v5' } }
                        }
                    }
                )
            }

            throw "Unexpected Invoke-AzureApi call for '$ResourceName'."
        }

        $permissionTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $permissionOutput = InModuleScope Devolutions.CIEM -Parameters @{ servicePrincipals = $servicePrincipals } {
            @(InvokeCIEMEntraPermissionCollection -ServicePrincipals $servicePrincipals)
        }
        $permissionTimer.Stop()

        $relationshipTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $relationshipOutput = InModuleScope Devolutions.CIEM -Parameters @{ groups = $groups; directoryRoles = $directoryRoles; users = $users } {
            @(InvokeCIEMEntraRelationshipCollection -Groups $groups -DirectoryRoles $directoryRoles -Users $users)
        }
        $relationshipTimer.Stop()

        $resourceGraphTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $resourceGraphOutput = InModuleScope Devolutions.CIEM -Parameters @{ subscriptionIds = $subscriptionIds } {
            @(InvokeCIEMResourceGraphQuery -Query 'Resources' -SubscriptionId $subscriptionIds)
        }
        $resourceGraphTimer.Stop()

        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..\..')).Path
        $tempRoot = Join-Path $repoRoot '_temp'
        if (-not (Test-Path $tempRoot)) {
            New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
        }

        $baselinePath = Join-Path $tempRoot 'discovery-perf-baseline.json'
        $metrics = [ordered]@{
            generatedAt = (Get-Date).ToString('o')
            permissionBatchCallSizes = @($script:PerformanceMetrics.PermissionBatchCallSizes)
            relationshipBatchCallSizes = @($script:PerformanceMetrics.RelationshipBatchCallSizes)
            resourceGraphChunkSizes = @($script:PerformanceMetrics.ResourceGraphChunkSizes)
            transitiveMemberOfCallCount = @($script:PerformanceMetrics.RelationshipRequestPaths | Where-Object { $_ -like '/users/*/transitiveMemberOf*' }).Count
            oauthGrantCalls = $script:PerformanceMetrics.OAuthGrantCalls
            outputCounts = [ordered]@{
                permissions = @($permissionOutput).Count
                relationships = @($relationshipOutput).Count
                resourceGraph = @($resourceGraphOutput).Count
            }
            timingsMs = [ordered]@{
                permissions = $permissionTimer.ElapsedMilliseconds
                relationships = $relationshipTimer.ElapsedMilliseconds
                resourceGraph = $resourceGraphTimer.ElapsedMilliseconds
            }
        }

        $metrics | ConvertTo-Json -Depth 10 | Set-Content -Path $baselinePath

        $script:PerformanceMetrics.PermissionBatchCallSizes | Should -Be @(100)
        $script:PerformanceMetrics.RelationshipBatchCallSizes | Should -Be @(120, 2)
        $script:PerformanceMetrics.ResourceGraphChunkSizes | Should -Be @(1000, 500)
        @($script:PerformanceMetrics.RelationshipRequestPaths | Where-Object { $_ -like '/users/*/transitiveMemberOf*' }).Count | Should -Be 0
        @($permissionOutput).Count | Should -Be 101
        @($relationshipOutput).Count | Should -Be 8
        @($resourceGraphOutput).Count | Should -Be 4
        Test-Path $baselinePath | Should -BeTrue
        (Get-Content -Path $baselinePath -Raw | ConvertFrom-Json).PSObject.Properties.Name | Should -Contain 'timingsMs'
    }
}
