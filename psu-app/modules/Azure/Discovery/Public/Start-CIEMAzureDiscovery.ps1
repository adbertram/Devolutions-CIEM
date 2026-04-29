function Start-CIEMAzureDiscovery {
    <#
    .SYNOPSIS
        Runs a full Azure discovery scan collecting ARM resources, Entra entities, permissions, and relationships.

    .DESCRIPTION
        Orchestrates the discovery pipeline as a linear sequence of named phases.
        Each phase is wrapped by InvokeCIEMDiscoveryPhase which handles the
        stopwatch, try/catch, error accumulation, and log emission uniformly.

        Per-phase success flags ($armDiscoverySucceeded / $entraDiscoverySucceeded /
        $relationshipsSucceeded) drive the Completed / Partial / Failed decision
        at the end of the run.
    #>
    [CmdletBinding()]
    [OutputType('CIEMAzureDiscoveryRun')]
    param(
        [Parameter()]
        [ValidateSet('All', 'ARM', 'Entra')]
        [string]$Scope = 'All'
    )

    $ErrorActionPreference = 'Stop'

    $saveResourceTypesFromList = {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [object[]]$Resources,
            [Parameter(Mandatory)]
            [Microsoft.Data.Sqlite.SqliteConnection]$Connection,
            [Parameter(Mandatory)]
            [string]$DiscoveredAt
        )

        $ErrorActionPreference = 'Stop'

        foreach ($typeGroup in @($Resources | Group-Object Type)) {
            if (-not $typeGroup.Name) { continue }

            $metadata = ResolveCIEMResourceTypeMetadata -Type $typeGroup.Name
            SaveCIEMAzureResourceType `
                -Type $typeGroup.Name `
                -ApiSource $metadata.ApiSource `
                -GraphTable $metadata.GraphTable `
                -ResourceCount $typeGroup.Count `
                -DiscoveredAt $DiscoveredAt `
                -Connection $Connection
        }
    }

    $runningRuns = @(Get-CIEMAzureDiscoveryRun -Status 'Running')
    if ($runningRuns.Count -gt 0) {
        throw "A discovery run is already in progress (Id=$($runningRuns[0].Id)). Wait for it to complete or clear stale runs."
    }

    if (-not $script:AzureAuthContext -or -not $script:AzureAuthContext.IsConnected) {
        Write-CIEMLog 'Start-CIEMAzureDiscovery: No auth context, calling Connect-CIEMAzure...' -Severity INFO -Component 'Discovery'
        Connect-CIEMAzure | Out-Null
    }

    $run = New-CIEMAzureDiscoveryRun -Scope $Scope -Status 'Running' -StartedAt (Get-Date).ToString('o')
    Write-CIEMLog "Start-CIEMAzureDiscovery: run #$($run.Id) started, Scope=$Scope" -Severity INFO -Component 'Discovery'

    $warningCount = 0
    $errorMessages = [System.Collections.Generic.List[string]]::new()
    $runStart = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $subscriptionIds = @($script:AzureAuthContext.SubscriptionIds)

    # Per-phase success flags. Scope=ARM means Entra is "successful" by virtue of
    # not running, and vice versa — this matches the pre-refactor semantics.
    $armDiscoverySucceeded = $Scope -eq 'Entra'
    $entraDiscoverySucceeded = $Scope -eq 'ARM'
    $relationshipsSucceeded = $true

    $armRowCount = 0
    $entraRowCount = 0
    $armTypeCount = 0
    $entraTypeCount = 0
    $relationshipCount = 0
    $warningCounter = [ref]$warningCount
    $discoveryPhaseConfig = @(GetCIEMAzureDiscoveryPhaseConfig -Scope $Scope)
    $phaseById = @{}
    foreach ($phase in $discoveryPhaseConfig) {
        $phaseById[$phase.Id] = $phase
    }

    try {
        # =================================================================
        # ARM phase (collection + persistence)
        # =================================================================
        if ($Scope -eq 'All' -or $Scope -eq 'ARM') {
            if ($subscriptionIds.Count -eq 0) {
                throw 'Start-CIEMAzureDiscovery requires at least one subscription ID for ARM discovery.'
            }

            $armDiscoverySucceeded = $true
            $armResources = [System.Collections.Generic.List[object]]::new()
            Write-Progress -Activity 'Azure Discovery' -Status 'Collecting ARM resources' -PercentComplete 10

            # Resource Graph tables — one phase per table so each failure is isolated.
            foreach ($phase in @($discoveryPhaseConfig | Where-Object { $_.Executor -eq 'InvokeCIEMResourceGraphQuery' })) {
                $table = $phase.Query
                $phaseOutcome = InvokeCIEMDiscoveryPhase `
                    -Name $phase.Name `
                    -FailureMode $phase.FailureMode `
                    -ErrorMessages $errorMessages `
                    -WarningCounter $warningCounter `
                    -Action {
                        $results = @(InvokeCIEMResourceGraphQuery -Query $table -SubscriptionId $subscriptionIds)
                        Write-CIEMLog "ResourceGraph/${table}: $($results.Count) rows" -Component 'Discovery'
                        , $results
                    }
                if (-not $phaseOutcome.Succeeded) {
                    $armDiscoverySucceeded = $false
                }
                elseif ($phaseOutcome.Result) {
                    $armResources.AddRange([object[]]$phaseOutcome.Result)
                }
            }

            $builtInPhaseConfig = $phaseById['BuiltInRoleDefinitions']
            if (-not $builtInPhaseConfig) {
                throw 'Start-CIEMAzureDiscovery: BuiltInRoleDefinitions phase is not registered.'
            }
            $builtInPhase = InvokeCIEMDiscoveryPhase `
                -Name $builtInPhaseConfig.Name `
                -FailureMode $builtInPhaseConfig.FailureMode `
                -ErrorMessages $errorMessages `
                -WarningCounter $warningCounter `
                -Action {
                    $builtInRoles = @(GetCIEMBuiltInRoleDefinitions)
                    Write-CIEMLog "BuiltInRoleDefinitions: $($builtInRoles.Count) rows" -Component 'Discovery'
                    , $builtInRoles
                }
            if (-not $builtInPhase.Succeeded) {
                $armDiscoverySucceeded = $false
            }
            elseif ($builtInPhase.Result) {
                $armResources.AddRange([object[]]$builtInPhase.Result)
            }

            $armRowCount = $armResources.Count
            $armTypeCount = (@($armResources | Group-Object Type)).Count

            $null = InvokeCIEMDiscoveryPhase `
                -Name 'ARM persistence' `
                -FailureMode 'FailRun' `
                -ErrorMessages $errorMessages `
                -WarningCounter $warningCounter `
                -DetailBuilder { param($r) "$armRowCount rows" } `
                -Action {
                    InvokeCIEMTransaction {
                        param($conn)

                        if ($armResources.Count -gt 0) {
                            foreach ($resource in $armResources) {
                                $resource.LastSeenAt = $runStart
                            }
                            Save-CIEMAzureArmResource -InputObject $armResources -Connection $conn
                            & $saveResourceTypesFromList -Resources $armResources -Connection $conn -DiscoveredAt (Get-Date).ToString('o')
                        }

                        if ($armDiscoverySucceeded) {
                            Invoke-PSUSQLiteQuery -Connection $conn -Query 'DELETE FROM azure_arm_resources WHERE last_seen_at < @last_seen_at' -Parameters @{ last_seen_at = $runStart } -AsNonQuery | Out-Null
                        }
                    }
                }
        }

        # =================================================================
        # Entra phase (entities + permissions + persistence + relationships)
        # =================================================================
        $entraResources = [System.Collections.Generic.List[object]]::new()
        $entraPermissions = [System.Collections.Generic.List[object]]::new()
        $relationships = [System.Collections.Generic.List[object]]::new()

        if ($Scope -eq 'All' -or $Scope -eq 'Entra') {
            $entraDiscoverySucceeded = $true

            Write-Progress -Activity 'Azure Discovery' -Status 'Collecting Entra entities' -PercentComplete 55
            $entityPhaseConfig = $phaseById['EntraEntityCollection']
            if (-not $entityPhaseConfig) {
                throw 'Start-CIEMAzureDiscovery: EntraEntityCollection phase is not registered.'
            }
            $entityPhase = InvokeCIEMDiscoveryPhase `
                -Name $entityPhaseConfig.Name `
                -FailureMode $entityPhaseConfig.FailureMode `
                -ErrorMessages $errorMessages `
                -WarningCounter $warningCounter `
                -DetailBuilder { param($r) "$(@($r).Count) rows" } `
                -Action {
                    $entities = @(InvokeCIEMEntraEntityCollection)
                    Write-CIEMLog "Entra entities: $($entities.Count) rows" -Component 'Discovery'
                    , $entities
                }
            if (-not $entityPhase.Succeeded) {
                $entraDiscoverySucceeded = $false
            }
            elseif ($entityPhase.Result) {
                $entraResources.AddRange([object[]]$entityPhase.Result)
            }

            $collectedServicePrincipals = @($entraResources | Where-Object { $_.Type -eq 'servicePrincipal' })
            if ($collectedServicePrincipals.Count -gt 0) {
                $permissionPhaseConfig = $phaseById['EntraPermissionCollection']
                if (-not $permissionPhaseConfig) {
                    throw 'Start-CIEMAzureDiscovery: EntraPermissionCollection phase is not registered.'
                }
                $permissionPhase = InvokeCIEMDiscoveryPhase `
                    -Name $permissionPhaseConfig.Name `
                    -FailureMode $permissionPhaseConfig.FailureMode `
                    -ErrorMessages $errorMessages `
                    -WarningCounter $warningCounter `
                    -DetailBuilder { param($r) "$(@($r).Count) rows" } `
                    -Action {
                        $permissions = @(InvokeCIEMEntraPermissionCollection -ServicePrincipals $collectedServicePrincipals)
                        Write-CIEMLog "Entra permissions: $($permissions.Count) rows" -Component 'Discovery'
                        , $permissions
                    }
                if (-not $permissionPhase.Succeeded) {
                    $entraDiscoverySucceeded = $false
                }
                elseif ($permissionPhase.Result) {
                    $entraPermissions.AddRange([object[]]$permissionPhase.Result)
                }
            }

            $entraRowCount = $entraResources.Count + $entraPermissions.Count
            $entraTypeCount = (@((@($entraResources) + @($entraPermissions)) | Group-Object Type)).Count

            $null = InvokeCIEMDiscoveryPhase `
                -Name 'Entra persistence' `
                -FailureMode 'FailRun' `
                -ErrorMessages $errorMessages `
                -WarningCounter $warningCounter `
                -DetailBuilder { param($r) "$entraRowCount rows" } `
                -Action {
                    InvokeCIEMTransaction {
                        param($conn)

                        if ($entraResources.Count -gt 0) {
                            foreach ($resource in $entraResources) {
                                $resource.LastSeenAt = $runStart
                            }
                            Save-CIEMAzureEntraResource -InputObject $entraResources -Connection $conn
                        }

                        if ($entraPermissions.Count -gt 0) {
                            foreach ($resource in $entraPermissions) {
                                $resource.LastSeenAt = $runStart
                            }
                            Save-CIEMAzureEntraResource -InputObject $entraPermissions -Connection $conn
                        }

                        & $saveResourceTypesFromList -Resources (@($entraResources) + @($entraPermissions)) -Connection $conn -DiscoveredAt (Get-Date).ToString('o')

                        if ($entraDiscoverySucceeded) {
                            Invoke-PSUSQLiteQuery -Connection $conn -Query 'DELETE FROM azure_entra_resources WHERE last_seen_at < @last_seen_at' -Parameters @{ last_seen_at = $runStart } -AsNonQuery | Out-Null
                        }
                    }
                }

            $collectedGroups = @($entraResources | Where-Object { $_.Type -eq 'group' })
            $collectedRoles = @($entraResources | Where-Object { $_.Type -eq 'directoryRole' })
            $collectedUsers = @($entraResources | Where-Object { $_.Type -eq 'user' })

            if ($collectedGroups.Count -gt 0 -or $collectedRoles.Count -gt 0 -or $collectedUsers.Count -gt 0) {
                $relationshipPhaseConfig = $phaseById['EntraRelationshipCollection']
                if (-not $relationshipPhaseConfig) {
                    throw 'Start-CIEMAzureDiscovery: EntraRelationshipCollection phase is not registered.'
                }
                $relationshipPhase = InvokeCIEMDiscoveryPhase `
                    -Name $relationshipPhaseConfig.Name `
                    -FailureMode $relationshipPhaseConfig.FailureMode `
                    -ErrorMessages $errorMessages `
                    -WarningCounter $warningCounter `
                    -DetailBuilder { param($r) "$(@($r).Count) rows" } `
                    -Action {
                        $rels = @(InvokeCIEMEntraRelationshipCollection -Groups $collectedGroups -DirectoryRoles $collectedRoles -Users $collectedUsers)
                        Write-CIEMLog "Entra relationships: $($rels.Count) rows" -Component 'Discovery'
                        , $rels
                    }
                if (-not $relationshipPhase.Succeeded) {
                    $relationshipsSucceeded = $false
                }
                elseif ($relationshipPhase.Result) {
                    $relationships.AddRange([object[]]$relationshipPhase.Result)
                    $relationshipCount = $relationships.Count
                }
            }
        }

        # =================================================================
        # Relationship persistence (only if the collection phase succeeded)
        # =================================================================
        if ($relationshipsSucceeded -and $relationships.Count -gt 0) {
            $null = InvokeCIEMDiscoveryPhase `
                -Name 'Relationship persistence' `
                -FailureMode 'FailRun' `
                -ErrorMessages $errorMessages `
                -WarningCounter $warningCounter `
                -DetailBuilder { param($r) "$relationshipCount rows" } `
                -Action {
                    InvokeCIEMTransaction {
                        param($conn)
                        Remove-CIEMAzureResourceRelationship -All -Connection $conn -Confirm:$false
                        Save-CIEMAzureResourceRelationship -InputObject $relationships -Connection $conn
                    }
                }
        }

        # =================================================================
        # Derived build phases (ERA + graph). These read from the DB, so they
        # run even when individual collection phases degraded to Partial.
        # =================================================================
        $allArmResources = $null
        $allEntraResources = $null
        $allRelationships = $null

        $null = InvokeCIEMDiscoveryPhase `
            -Name 'Build data load' `
            -FailureMode 'FailRun' `
            -ErrorMessages $errorMessages `
            -WarningCounter $warningCounter `
            -DetailBuilder { param($r) "$($r.ArmCount) ARM, $($r.EntraCount) Entra, $($r.RelCount) relationships" } `
            -Action {
                $script:discoveryLoadedArm = @(Get-CIEMAzureArmResource)
                $script:discoveryLoadedEntra = @(Get-CIEMAzureEntraResource)
                $script:discoveryLoadedRel = @(Get-CIEMAzureResourceRelationship)
                [pscustomobject]@{
                    ArmCount = $script:discoveryLoadedArm.Count
                    EntraCount = $script:discoveryLoadedEntra.Count
                    RelCount = $script:discoveryLoadedRel.Count
                }
            }
        $allArmResources = $script:discoveryLoadedArm
        $allEntraResources = $script:discoveryLoadedEntra
        $allRelationships = $script:discoveryLoadedRel
        $script:discoveryLoadedArm = $null
        $script:discoveryLoadedEntra = $null
        $script:discoveryLoadedRel = $null

        $null = InvokeCIEMDiscoveryPhase `
            -Name 'ERA build' `
            -FailureMode 'FailRun' `
            -ErrorMessages $errorMessages `
            -WarningCounter $warningCounter `
            -Action {
                InvokeCIEMTransaction {
                    param($conn)
                    Remove-CIEMAzureEffectiveRoleAssignment -All -Confirm:$false -Connection $conn
                    $eraCount = InvokeCIEMAzureEffectiveRoleAssignmentBuild -ArmResources $allArmResources -EntraResources $allEntraResources -Relationships $allRelationships -Connection $conn -ComputedAt (Get-Date).ToString('o')
                    Write-CIEMLog "EffectiveRoleAssignments: $eraCount rows inserted" -Component 'Discovery'
                }
            }

        $null = InvokeCIEMDiscoveryPhase `
            -Name 'Graph build' `
            -FailureMode 'FailRun' `
            -ErrorMessages $errorMessages `
            -WarningCounter $warningCounter `
            -Action {
                InvokeCIEMTransaction {
                    param($conn)
                    Remove-CIEMGraphEdge -All -Confirm:$false -Connection $conn
                    Remove-CIEMGraphNode -All -Confirm:$false -Connection $conn

                    $collectedAt = (Get-Date).ToString('o')
                    $nodeCount = InvokeCIEMGraphNodeBuild -ArmResources $allArmResources -EntraResources $allEntraResources -Connection $conn -CollectedAt $collectedAt
                    Write-CIEMLog "GraphNodes: $nodeCount nodes created" -Component 'Discovery'

                    $collectedEdgeCount = InvokeCIEMGraphEdgeBuild -Relationships $allRelationships -Connection $conn -CollectedAt $collectedAt
                    Write-CIEMLog "GraphEdges: $collectedEdgeCount collected edges created" -Component 'Discovery'

                    $computedEdgeCount = InvokeCIEMGraphComputedEdgeBuild -ArmResources $allArmResources -EntraResources $allEntraResources -Relationships $allRelationships -Connection $conn -CollectedAt $collectedAt
                    Write-CIEMLog "GraphEdges: $computedEdgeCount computed edges created" -Component 'Discovery'
                }
            }

        $null = InvokeCIEMDiscoveryPhase `
            -Name 'Attack path materialization' `
            -FailureMode 'FailRun' `
            -ErrorMessages $errorMessages `
            -WarningCounter $warningCounter `
            -Action {
                Sync-CIEMAttackPathRuleCatalog | Out-Null
                $attackPathCount = @(Update-CIEMAttackPath -PassThru).Count
                Write-CIEMLog "AttackPaths: $attackPathCount findings materialized" -Component 'Discovery'
            }

        $allArmResources = $null
        $allEntraResources = $null
        $allRelationships = $null

        # Re-read the warning count from the ref after all phases are done
        $warningCount = $warningCounter.Value

        $totalCollected = $armRowCount + $entraRowCount
        $finalStatus = if ($warningCount -gt 0 -and $totalCollected -gt 0) {
            'Partial'
        }
        elseif ($totalCollected -eq 0) {
            'Failed'
        }
        else {
            'Completed'
        }

        $run = Update-CIEMAzureDiscoveryRun -Id $run.Id `
            -Status $finalStatus `
            -CompletedAt (Get-Date).ToString('o') `
            -ArmTypeCount $armTypeCount `
            -ArmRowCount $armRowCount `
            -EntraTypeCount $entraTypeCount `
            -EntraRowCount $entraRowCount `
            -WarningCount $warningCount `
            -ErrorMessage ($errorMessages -join '; ') `
            -PassThru

        Write-CIEMLog "Discovery run #$($run.Id) finished: Status=$finalStatus, ARM=$armRowCount, Entra=$entraRowCount, Relationships=$relationshipCount, Warnings=$warningCount" -Severity INFO -Component 'Discovery'
        Write-Progress -Activity 'Azure Discovery' -Completed
        $run
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-CIEMLog "Discovery run #$($run.Id) FAILED: $errorMessage" -Severity ERROR -Component 'Discovery'
        # Do not overwrite 'Cancelled' status if the run was cancelled by the user
        $currentRun = Get-CIEMAzureDiscoveryRun -Id $run.Id
        if ($currentRun.Status -ne 'Cancelled') {
            Update-CIEMAzureDiscoveryRun -Id $run.Id -Status 'Failed' -CompletedAt (Get-Date).ToString('o') -ErrorMessage $errorMessage | Out-Null
        }
        throw
    }
}
