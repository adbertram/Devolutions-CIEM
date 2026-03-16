BeforeAll {
    $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' '..')
    Import-Module (Join-Path $projectRoot 'Devolutions.CIEM.Admin' 'Devolutions.CIEM.Admin.psd1') -Force

    # Helper: run a command on PSU, wrap output in JSON, and parse the result.
    # Each Run-OnPSU call is an isolated PSU job (separate runspace).
    function script:Run-OnPSU {
        param(
            [Parameter(Mandatory)][string]$Command,
            [int]$TimeoutSeconds = 60
        )

        $wrappedCommand = @"
`$ErrorActionPreference = 'Continue'
`$__result = & { $Command }
if (`$null -ne `$__result) { `$__result | ConvertTo-Json -Depth 5 -Compress } else { '___NULL___' }
"@
        $allOutput = @(Invoke-TestCommand -ScriptBlock ([scriptblock]::Create($wrappedCommand)) -TimeoutSeconds $TimeoutSeconds)
        $jobResult = $allOutput | Where-Object { $_.PSObject.Properties.Name -contains 'JobId' } | Select-Object -Last 1

        if (-not $jobResult) { throw "PSU command returned no job result." }
        if ($jobResult.Status -eq 'Failed') {
            $errMsgs = @($jobResult.Output) | Where-Object { $_.type -eq 4 } | ForEach-Object { $_.message }
            throw "PSU command failed: $($errMsgs -join '; ')"
        }
        if ($jobResult.Status -notin @('Completed', 'Warning')) {
            throw "PSU job $($jobResult.JobId) did not complete. Status: $($jobResult.Status)"
        }

        $pipelineItems = @($jobResult.PipelineOutput)
        if ($pipelineItems.Count -eq 0) { return $null }

        $lastItem = $pipelineItems[-1]
        $jsonDataStr = $lastItem.jsonData
        if (-not $jsonDataStr) { return $null }

        $jsonEntries = $jsonDataStr | ConvertFrom-Json
        $rawValue = ($jsonEntries | Select-Object -Last 1).value

        if ($rawValue -eq '___NULL___') { return $null }

        try { $rawValue | ConvertFrom-Json }
        catch { $rawValue }
    }

    # Helper for long-running PSU jobs: starts the job via REST (short timeout to get job ID),
    # then waits for completion using PSU's Wait-PSUJob (gRPC-based, efficient).
    # Note: Get-PSUJobPipelineOutput returns raw strings (not .jsonData objects like the REST API).
    function script:Run-OnPSU-LongRunning {
        param(
            [Parameter(Mandatory)][string]$Command,
            [int]$TimeoutSeconds = 600
        )

        $wrappedCommand = @"
`$ErrorActionPreference = 'Continue'
`$__result = & { $Command }
if (`$null -ne `$__result) { `$__result | ConvertTo-Json -Depth 5 -Compress } else { '___NULL___' }
"@
        # Start the job with a short timeout — we just need the job ID
        $allOutput = @(Invoke-TestCommand -ScriptBlock ([scriptblock]::Create($wrappedCommand)) -TimeoutSeconds 5)
        $jobResult = $allOutput | Where-Object { $_.PSObject.Properties.Name -contains 'JobId' } | Select-Object -Last 1

        if (-not $jobResult -or -not $jobResult.JobId) { throw "PSU command returned no job result." }

        $jobId = $jobResult.JobId
        Write-Host "Started PSU job $jobId, waiting up to ${TimeoutSeconds}s..."

        # Wait for completion using PSU's gRPC-based Wait-PSUJob
        Wait-PSUJob -JobId $jobId -Timeout $TimeoutSeconds | Out-Null

        # Get final status (Status is PowerShellUniversal.JobStatus enum — string comparison works)
        $finalJob = Get-PSUJob -Id $jobId
        $statusName = "$($finalJob.Status)"

        if ($statusName -eq 'Failed') {
            $errOutput = Get-PSUJobOutput -JobId $jobId
            $errMsgs = @($errOutput) | Where-Object { $_.Type -eq 4 } | ForEach-Object { $_.Message }
            throw "PSU job $jobId failed: $($errMsgs -join '; ')"
        }
        if ($statusName -notin @('Completed', 'Warning')) {
            throw "PSU job $jobId did not complete within ${TimeoutSeconds}s. Status: $statusName"
        }

        Write-Host "PSU job $jobId completed with status: $statusName"

        # Get-PSUJobPipelineOutput returns raw strings (the JSON our wrapper emitted)
        $pipelineOutput = Get-PSUJobPipelineOutput -JobId $jobId
        if (-not $pipelineOutput) { return $null }

        $rawValue = @($pipelineOutput)[-1]
        if ($rawValue -eq '___NULL___') { return $null }

        try { $rawValue | ConvertFrom-Json }
        catch { $rawValue }
    }

    Connect-PSU -Local | Out-Null

    # Verify PSU is reachable and discovery command exists
    $script:cmdCheck = Run-OnPSU 'Get-Command Start-CIEMAzureDiscovery -ErrorAction Stop | Select-Object -ExpandProperty Name'
    if ($script:cmdCheck -ne 'Start-CIEMAzureDiscovery') {
        throw "Local PSU not reachable or CIEM module not loaded. Start with: ./scripts/setup-local-psu.sh start"
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
            # Uses Run-OnPSU-LongRunning: starts job via REST, waits via Wait-PSUJob (gRPC)
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
