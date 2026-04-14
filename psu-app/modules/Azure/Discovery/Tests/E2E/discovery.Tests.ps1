BeforeAll {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' '..')
    . (Join-Path $projectRoot 'psu-app' 'Tests' 'E2E' 'PesterE2EHelper.ps1')
    Initialize-PesterE2E -ProjectRoot $projectRoot

    # Verify PSU is reachable and discovery command exists
    $script:cmdCheck = Run-OnPSU 'Get-Command Start-CIEMAzureDiscovery -ErrorAction Stop | Select-Object -ExpandProperty Name'
    if ($script:cmdCheck -ne 'Start-CIEMAzureDiscovery') {
        throw "Local PSU not reachable or CIEM module not loaded. Start PSU on adam-server: ssh adam-server 'sudo launchctl kickstart -k system/com.psu.server'"
    }

    # Verify real Azure auth profile exists and is active, then connect
    $script:authReady = Run-OnPSU @'
        $profile = Get-CIEMAzureAuthenticationProfile -IsActive $true | Select-Object -First 1
        if (-not $profile) { throw 'No active Azure auth profile found. Configure one in PSU before running E2E tests.' }
        Connect-CIEMAzure | Out-Null
        'connected'
'@ -TimeoutSeconds 120

    if ($script:authReady -ne 'connected') {
        throw "Failed to connect to Azure. Ensure an active auth profile with valid credentials exists."
    }

    $script:testRunIds = @()
}

AfterAll {
    # Clean up only the discovery run records created by tests
    foreach ($runId in $script:testRunIds) {
        try { Run-OnPSU "Remove-CIEMAzureDiscoveryRun -Id $runId -Confirm:`$false; 'ok'" } catch {}
    }
}

Describe 'Azure Discovery E2E' {

    Context 'Full discovery run (Scope=All)' {
        BeforeAll {
            # Run full discovery — connect + discover in the same runspace (each Run-OnPSU is isolated)
            # Uses Run-OnPSU-LongRunning so the discovery job gets a full E2E timeout.
            $script:discoveryRun = Run-OnPSU-LongRunning @'
                Connect-CIEMAzure | Out-Null
                $run = Start-CIEMAzureDiscovery -Scope All
                $run | Select-Object Id, Scope, Status, StartedAt, CompletedAt, ArmTypeCount, ArmRowCount, EntraTypeCount, EntraRowCount, WarningCount, ErrorMessage
'@ -TimeoutSeconds 600

            if ($script:discoveryRun.Id) {
                $script:testRunIds += $script:discoveryRun.Id
            }

            # Query actual DB counts on PSU (accurate — avoids JSON serialization discrepancies)
            $script:dbCounts = Run-OnPSU @'
                $arm   = @(Get-CIEMAzureArmResource)
                $entra = @(Get-CIEMAzureEntraResource)
                $rels  = @(Get-CIEMAzureResourceRelationship)
                [PSCustomObject]@{
                    ArmRowCount    = $arm.Count
                    ArmTypeCount   = ($arm | Where-Object { $_.Type } | Group-Object Type).Count
                    EntraRowCount  = $entra.Count
                    EntraTypeCount = ($entra | Where-Object { $_.Type } | Group-Object Type).Count
                    RelCount       = $rels.Count
                }
'@

            # Query sample resources for property/shape assertions
            $script:armSample = Run-OnPSU '@(Get-CIEMAzureArmResource) | Where-Object { $_.Id } | Select-Object -First 1 Id, Type, Name, SubscriptionId'
            $script:armByType = Run-OnPSU @'
                $first = @(Get-CIEMAzureArmResource) | Where-Object { $_.Type } | Select-Object -First 1
                if ($first) {
                    $subset = @(Get-CIEMAzureArmResource -Type $first.Type)
                    [PSCustomObject]@{ FilterType = $first.Type; Count = $subset.Count; TotalArm = @(Get-CIEMAzureArmResource).Count }
                } else { $null }
'@
            $script:entraSample = Run-OnPSU '@(Get-CIEMAzureEntraResource) | Select-Object -First 1 Id, Type, DisplayName'
            $script:entraUsers = Run-OnPSU '@(Get-CIEMAzureEntraResource -Type "user") | Select-Object -First 3 Id, Type, DisplayName'
            $script:relSample = Run-OnPSU '@(Get-CIEMAzureResourceRelationship) | Select-Object -First 1 Id, SourceId, TargetId, Relationship'
            $runId = $script:discoveryRun.Id
            $script:runById = if ($runId) {
                Run-OnPSU "Get-CIEMAzureDiscoveryRun -Id $runId | Select-Object Id, Scope, Status"
            } else { $null }
            $script:lastRun = Run-OnPSU 'Get-CIEMAzureDiscoveryRun -Last 1 | Select-Object Id, Scope, Status'
        }

        # --- Run record assertions ---
        It 'Run has a positive Id' {
            $script:discoveryRun.Id | Should -BeGreaterThan 0
        }

        It 'Run Status is Completed or Partial' {
            $script:discoveryRun.Status | Should -BeIn @('Completed', 'Partial')
        }

        It 'Run Scope is All' {
            $script:discoveryRun.Scope | Should -Be 'All'
        }

        It 'Run CompletedAt is set' {
            $script:discoveryRun.CompletedAt | Should -Not -BeNullOrEmpty
        }

        # --- Run metrics match DB state ---
        # ArmRowCount is counted in-memory before DB write; INSERT OR REPLACE deduplicates
        # by primary key, so DB count can be slightly lower. We verify they're close.
        It 'ARM rows persisted to database match run ArmRowCount' {
            $script:discoveryRun.ArmRowCount | Should -BeGreaterThan 0
            $script:dbCounts.ArmRowCount | Should -BeGreaterOrEqual ([math]::Floor($script:discoveryRun.ArmRowCount * 0.95))
            $script:dbCounts.ArmRowCount | Should -BeLessOrEqual $script:discoveryRun.ArmRowCount
        }

        It 'Entra rows persisted to database match run EntraRowCount' {
            $script:discoveryRun.EntraRowCount | Should -BeGreaterThan 0
            $script:dbCounts.EntraRowCount | Should -Be $script:discoveryRun.EntraRowCount
        }

        It 'ARM resources span multiple distinct types in database' {
            $script:discoveryRun.ArmTypeCount | Should -BeGreaterThan 0
            $script:dbCounts.ArmTypeCount | Should -BeGreaterThan 0
        }

        It 'Entra type count in database matches run EntraTypeCount' {
            $script:discoveryRun.EntraTypeCount | Should -BeGreaterThan 0
            $script:dbCounts.EntraTypeCount | Should -Be $script:discoveryRun.EntraTypeCount
        }

        It 'Relationships were persisted to the database' {
            $script:dbCounts.RelCount | Should -BeGreaterThan 0
        }

        # --- ARM resource shape assertions ---
        It 'ARM resources have required properties (Id, Type, Name)' {
            $script:armSample | Should -Not -BeNullOrEmpty
            $script:armSample.Id | Should -Not -BeNullOrEmpty
            $script:armSample.Type | Should -Not -BeNullOrEmpty
            $script:armSample.Name | Should -Not -BeNullOrEmpty
        }

        It 'ARM Type filter returns a subset' {
            $script:armByType | Should -Not -BeNullOrEmpty
            $script:armByType.Count | Should -BeGreaterThan 0
            $script:armByType.Count | Should -BeLessOrEqual $script:armByType.TotalArm
        }

        # --- Entra resource shape assertions ---
        It 'Entra resources have required properties (Id, Type)' {
            $script:entraSample | Should -Not -BeNullOrEmpty
            $script:entraSample.Id | Should -Not -BeNullOrEmpty
            $script:entraSample.Type | Should -Not -BeNullOrEmpty
        }

        It 'Entra Type filter for user returns results' {
            @($script:entraUsers).Count | Should -BeGreaterThan 0
            ($script:entraUsers | Select-Object -First 1).Type | Should -Be 'user'
        }

        # --- Relationship shape assertions ---
        It 'Relationships have expected properties (SourceId, TargetId, Relationship)' {
            $script:relSample | Should -Not -BeNullOrEmpty
            $script:relSample.SourceId | Should -Not -BeNullOrEmpty
            $script:relSample.TargetId | Should -Not -BeNullOrEmpty
            $script:relSample.Relationship | Should -Not -BeNullOrEmpty
        }

        # --- Run query assertions ---
        It 'Get-CIEMAzureDiscoveryRun -Id returns the correct run' {
            $script:runById.Id | Should -Be $script:discoveryRun.Id
            $script:runById.Scope | Should -Be 'All'
        }

        It 'Get-CIEMAzureDiscoveryRun -Last 1 returns the most recent run' {
            $script:lastRun | Should -Not -BeNullOrEmpty
            $script:lastRun.Id | Should -BeGreaterOrEqual $script:discoveryRun.Id
        }
    }

    Context 'Concurrency guard' {
        BeforeAll {
            # Seed a fake Running discovery run to trigger the concurrency guard
            $script:fakeRunId = $null
            $script:fakeRun = Run-OnPSU @'
                New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt (Get-Date).ToString('o') |
                    Select-Object Id, Status
'@
            $script:fakeRunId = $script:fakeRun.Id
        }

        AfterAll {
            if ($script:fakeRunId) {
                try { Run-OnPSU "Remove-CIEMAzureDiscoveryRun -Id $($script:fakeRunId) -Confirm:`$false; 'ok'" } catch {}
            }
        }

        It 'Throws when a discovery run is already Running' {
            $errorThrown = $false
            try {
                Run-OnPSU 'Start-CIEMAzureDiscovery' -TimeoutSeconds 30
            }
            catch {
                if ($_ -match 'already in progress') { $errorThrown = $true }
            }
            $errorThrown | Should -BeTrue
        }
    }
}
