function Start-CIEMAzureDiscovery {
    [CmdletBinding()]
    [OutputType('CIEMAzureDiscoveryRun')]
    param(
        [Parameter()]
        [ValidateSet('All', 'ARM', 'Entra')]
        [string]$Scope = 'All'
    )

    $ErrorActionPreference = 'Stop'

    # --- Ensure Azure auth context is established (required for PSU job runspaces) ---
    if (-not $script:AzureAuthContext -or -not $script:AzureAuthContext.IsConnected) {
        Write-CIEMLog "Start-CIEMAzureDiscovery: No auth context, calling Connect-CIEMAzure..." -Severity INFO -Component 'Discovery'
        Connect-CIEMAzure | Out-Null
    }

    # --- Concurrency guard ---
    $runningRuns = @(Get-CIEMAzureDiscoveryRun -Status 'Running')
    if ($runningRuns.Count -gt 0) {
        throw "A discovery run is already in progress (Id=$($runningRuns[0].Id)). Wait for it to complete or clear stale runs."
    }

    # --- Create run record ---
    $run = New-CIEMAzureDiscoveryRun -Scope $Scope -Status 'Running' -StartedAt (Get-Date).ToString('o')
    Write-CIEMLog "Start-CIEMAzureDiscovery: run #$($run.Id) started, Scope=$Scope" -Severity INFO -Component 'Discovery'

    $warningCount = 0
    $errorMessages = [System.Collections.Generic.List[string]]::new()

    # In-memory accumulators
    $armResources    = [System.Collections.Generic.List[object]]::new()
    $entraResources  = [System.Collections.Generic.List[object]]::new()
    $entraPermissions = [System.Collections.Generic.List[object]]::new()
    $relationships   = [System.Collections.Generic.List[object]]::new()

    try {
        # ===== PHASE 1: Collect to memory =====

        if ($Scope -eq 'All' -or $Scope -eq 'ARM') {
            Write-Progress -Activity 'Azure Discovery' -Status 'Collecting ARM resources' -PercentComplete 10 -CurrentOperation 'Querying Resource Graph tables'
            Write-CIEMLog "Collecting ARM resources (Resource Graph)..." -Component 'Discovery'

            foreach ($table in @('Resources', 'ResourceContainers', 'AuthorizationResources')) {
                try {
                    $results = @(InvokeCIEMResourceGraphQuery -Query $table)
                    $armResources.AddRange($results)
                    Write-CIEMLog "ResourceGraph/${table}: $($results.Count) rows" -Component 'Discovery'
                }
                catch {
                    $warningCount++
                    $msg = "ResourceGraph/${table} failed: $($_.Exception.Message)"
                    $errorMessages.Add($msg)
                    Write-Warning $msg
                }
            }

            Write-Progress -Activity 'Azure Discovery' -Status 'Collecting built-in role definitions' -PercentComplete 40 -CurrentOperation 'Enumerating Azure RBAC roles'
            try {
                $builtInRoles = @(GetCIEMBuiltInRoleDefinitions)
                $armResources.AddRange($builtInRoles)
                Write-CIEMLog "BuiltInRoleDefinitions: $($builtInRoles.Count) rows" -Component 'Discovery'
            }
            catch {
                $warningCount++
                $msg = "BuiltInRoleDefinitions failed: $($_.Exception.Message)"
                $errorMessages.Add($msg)
                Write-Warning $msg
            }
        }

        if ($Scope -eq 'All' -or $Scope -eq 'Entra') {
            Write-Progress -Activity 'Azure Discovery' -Status 'Collecting Entra entities' -PercentComplete 55 -CurrentOperation 'Querying Microsoft Graph API'
            Write-CIEMLog "Collecting Entra entities (Graph API)..." -Component 'Discovery'

            try {
                $entities = @(InvokeCIEMEntraEntityCollection)
                $entraResources.AddRange($entities)
                Write-CIEMLog "Entra entities: $($entities.Count) rows" -Component 'Discovery'
            }
            catch {
                $warningCount++
                $msg = "EntraEntityCollection failed: $($_.Exception.Message)"
                $errorMessages.Add($msg)
                Write-Warning $msg
            }

            # Extract SPs from collected entities for per-SP calls
            $collectedSPs = @($entraResources | Where-Object { $_.Type -eq 'servicePrincipal' })

            if ($collectedSPs.Count -gt 0) {
                Write-Progress -Activity 'Azure Discovery' -Status 'Collecting Entra permissions' -PercentComplete 70 -CurrentOperation "Processing $($collectedSPs.Count) service principals"
                try {
                    $permissions = @(InvokeCIEMEntraPermissionCollection -ServicePrincipals $collectedSPs)
                    $entraPermissions.AddRange($permissions)
                    Write-CIEMLog "Entra permissions: $($permissions.Count) rows" -Component 'Discovery'
                }
                catch {
                    $warningCount++
                    $msg = "EntraPermissionCollection failed: $($_.Exception.Message)"
                    $errorMessages.Add($msg)
                    Write-Warning $msg
                }
            }

            $collectedGroups = @($entraResources | Where-Object { $_.Type -eq 'group' })
            $collectedRoles  = @($entraResources | Where-Object { $_.Type -eq 'directoryRole' })
            $collectedUsers  = @($entraResources | Where-Object { $_.Type -eq 'user' })

            if ($collectedGroups.Count -gt 0 -or $collectedRoles.Count -gt 0 -or $collectedUsers.Count -gt 0) {
                Write-Progress -Activity 'Azure Discovery' -Status 'Collecting Entra relationships' -PercentComplete 80 -CurrentOperation "$($collectedGroups.Count) groups, $($collectedRoles.Count) roles, $($collectedUsers.Count) users"
                try {
                    $rels = @(InvokeCIEMEntraRelationshipCollection `
                        -Groups         $collectedGroups `
                        -DirectoryRoles $collectedRoles `
                        -Users          $collectedUsers)
                    $relationships.AddRange($rels)
                    Write-CIEMLog "Entra relationships: $($rels.Count) rows" -Component 'Discovery'
                }
                catch {
                    $warningCount++
                    $msg = "EntraRelationshipCollection failed: $($_.Exception.Message)"
                    $errorMessages.Add($msg)
                    Write-Warning $msg
                }
            }
        }

        # ===== PHASE 2: Atomic DB write =====
        Write-Progress -Activity 'Azure Discovery' -Status 'Writing to database' -PercentComplete 90 -CurrentOperation 'Atomic transaction'
        Write-CIEMLog "Writing $($armResources.Count) ARM + $($entraResources.Count + $entraPermissions.Count) Entra + $($relationships.Count) relationships to DB..." -Component 'Discovery'

        InvokeCIEMTransaction {
            param($conn)

            # Clear old data
            Remove-CIEMAzureArmResource -All -Connection $conn -Confirm:$false
            Remove-CIEMAzureEntraResource -All -Connection $conn -Confirm:$false
            Remove-CIEMAzureResourceRelationship -All -Connection $conn -Confirm:$false

            # Insert new data
            if ($armResources.Count -gt 0) {
                Save-CIEMAzureArmResource -InputObject $armResources -Connection $conn
            }
            if ($entraResources.Count -gt 0) {
                Save-CIEMAzureEntraResource -InputObject $entraResources -Connection $conn
            }
            if ($entraPermissions.Count -gt 0) {
                Save-CIEMAzureEntraResource -InputObject $entraPermissions -Connection $conn
            }
            if ($relationships.Count -gt 0) {
                Save-CIEMAzureResourceRelationship -InputObject $relationships -Connection $conn
            }

            # Auto-populate azure_resource_types
            $allResources = @($armResources) + @($entraResources) + @($entraPermissions)
            $typeGroups = $allResources | Group-Object -Property Type
            $discoveredAt = (Get-Date).ToString('o')

            foreach ($tg in $typeGroups) {
                if (-not $tg.Name) { continue }
                $apiSource = if ($tg.Name -match '^microsoft\.') {
                    'ResourceGraph'
                } else {
                    'Graph'
                }
                $graphTable = if ($tg.Name -match '^microsoft\.resources/') { 'ResourceContainers' }
                              elseif ($tg.Name -match '^microsoft\.authorization/') { 'AuthorizationResources' }
                              elseif ($apiSource -eq 'Graph') { $null }
                              else { 'Resources' }

                SaveCIEMAzureResourceType `
                    -Type          $tg.Name `
                    -ApiSource     $apiSource `
                    -GraphTable    $graphTable `
                    -ResourceCount $tg.Count `
                    -DiscoveredAt  $discoveredAt `
                    -Connection    $conn
            }

            # Populate effective role assignments (pre-resolved identity-to-resource mappings)
            Remove-CIEMAzureEffectiveRoleAssignment -All -Confirm:$false -Connection $conn
            $allEntra = @($entraResources) + @($entraPermissions)
            $eraCount = InvokeCIEMAzureEffectiveRoleAssignmentBuild `
                -ArmResources    $armResources `
                -EntraResources  $allEntra `
                -Relationships   $relationships `
                -Connection      $conn `
                -ComputedAt      (Get-Date).ToString('o')
            Write-CIEMLog "EffectiveRoleAssignments: $eraCount rows inserted" -Component 'Discovery'
        }

        # ===== Determine final status =====
        $totalCollected = $armResources.Count + $entraResources.Count + $entraPermissions.Count
        $finalStatus = if ($warningCount -gt 0 -and $totalCollected -gt 0) {
            'Partial'
        } elseif ($totalCollected -eq 0) {
            'Failed'
        } else {
            'Completed'
        }

        $armTypes   = ($armResources   | Group-Object Type).Count
        $entraTypes = ((@($entraResources) + @($entraPermissions)) | Group-Object Type).Count

        $run = Update-CIEMAzureDiscoveryRun -Id $run.Id `
            -Status      $finalStatus `
            -CompletedAt (Get-Date).ToString('o') `
            -ArmTypeCount   $armTypes `
            -ArmRowCount    $armResources.Count `
            -EntraTypeCount $entraTypes `
            -EntraRowCount  ($entraResources.Count + $entraPermissions.Count) `
            -WarningCount   $warningCount `
            -ErrorMessage   ($errorMessages -join '; ') `
            -PassThru

        Write-CIEMLog "Discovery run #$($run.Id) finished: Status=$finalStatus, ARM=$($armResources.Count), Entra=$($entraResources.Count + $entraPermissions.Count), Relationships=$($relationships.Count), Warnings=$warningCount" -Severity INFO -Component 'Discovery'
        Write-Progress -Activity 'Azure Discovery' -Completed

        $run
    }
    catch {
        # Unhandled exception — mark run as Failed
        $errMsg = $_.Exception.Message
        Write-CIEMLog "Discovery run #$($run.Id) FAILED: $errMsg" -Severity ERROR -Component 'Discovery'
        Update-CIEMAzureDiscoveryRun -Id $run.Id `
            -Status       'Failed' `
            -CompletedAt  (Get-Date).ToString('o') `
            -ErrorMessage $errMsg | Out-Null
        throw
    }
}
