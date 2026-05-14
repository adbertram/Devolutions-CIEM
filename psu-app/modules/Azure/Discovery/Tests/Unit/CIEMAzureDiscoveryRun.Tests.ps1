BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

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

Describe 'Discovery Run CRUD' {

    Context 'New-CIEMAzureDiscoveryRun' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
        }

        It 'Creates a run with auto-generated integer Id' {
            $result = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt (Get-Date).ToString('o')
            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -BeOfType [int]
        }

        It 'Returns CIEMAzureDiscoveryRun with Id > 0' {
            $result = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt (Get-Date).ToString('o')
            $result.Id | Should -BeGreaterThan 0
        }

        It 'Consecutive creates return incrementing Ids' {
            $r1 = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt (Get-Date).ToString('o')
            $r2 = New-CIEMAzureDiscoveryRun -Scope 'ARM' -Status 'Running' -StartedAt (Get-Date).ToString('o')
            $r2.Id | Should -BeGreaterThan $r1.Id
        }

        It 'Accepts optional -PsuJobId' {
            $result = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt (Get-Date).ToString('o') -PsuJobId 42
            $result.PsuJobId | Should -Be 42
        }

        It 'Accepts -InputObject parameter set' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureDiscoveryRun]::new()
                $o.Scope = 'Entra'
                $o.Status = 'Running'
                $o.StartedAt = (Get-Date).ToString('o')
                $o
            }
            $result = New-CIEMAzureDiscoveryRun -InputObject $obj
            $result | Should -Not -BeNullOrEmpty
            $result.Scope | Should -Be 'Entra'
        }

        It 'Resolves the database path when module-scope DatabasePath is empty' {
            $env:CIEM_TEST_DISCOVERY_DATA_ROOT = Split-Path "$TestDrive/ciem.db" -Parent

            $result = InModuleScope Devolutions.CIEM {
                $oldDatabasePath = $script:DatabasePath
                $oldDataRoot = $script:DataRoot
                try {
                    $script:DatabasePath = $null
                    $script:DataRoot = $env:CIEM_TEST_DISCOVERY_DATA_ROOT
                    New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt (Get-Date).ToString('o')
                }
                finally {
                    $script:DatabasePath = $oldDatabasePath
                    $script:DataRoot = $oldDataRoot
                }
            }

            $result.Id | Should -BeGreaterThan 0
            if (Test-Path Env:\CIEM_TEST_DISCOVERY_DATA_ROOT) {
                Remove-Item Env:\CIEM_TEST_DISCOVERY_DATA_ROOT -ErrorAction Stop
            }
        }

        It 'Mandatory params: -Scope, -Status, -StartedAt' {
            { New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt (Get-Date).ToString('o') } | Should -Not -Throw

            $parameterSet = Get-Command New-CIEMAzureDiscoveryRun |
                Select-Object -ExpandProperty ParameterSets |
                Where-Object { $_.Name -eq 'ByProperties' }

            $mandatoryParameters = @(
                $parameterSet.Parameters |
                    Where-Object { $_.IsMandatory } |
                    Select-Object -ExpandProperty Name
            )

            $mandatoryParameters | Should -Contain 'Scope'
            $mandatoryParameters | Should -Contain 'Status'
            $mandatoryParameters | Should -Contain 'StartedAt'
        }
    }

    Context 'Get-CIEMAzureDiscoveryRun' {
        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
            # Seed 3 runs with distinct timestamps for ordering
            New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-01-01T00:00:00Z'
            New-CIEMAzureDiscoveryRun -Scope 'ARM' -Status 'Failed' -StartedAt '2026-01-02T00:00:00Z'
            New-CIEMAzureDiscoveryRun -Scope 'Entra' -Status 'Completed' -StartedAt '2026-01-03T00:00:00Z'
        }

        It 'Returns CIEMAzureDiscoveryRun typed objects (.GetType().Name -eq CIEMAzureDiscoveryRun)' {
            $results = Get-CIEMAzureDiscoveryRun
            $results | ForEach-Object { $_.GetType().Name | Should -Be 'CIEMAzureDiscoveryRun' }
        }

        It 'Gets by -Id' {
            $all = Get-CIEMAzureDiscoveryRun
            $first = $all | Select-Object -First 1
            $result = Get-CIEMAzureDiscoveryRun -Id $first.Id
            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be $first.Id
        }

        It 'Filters by -Status' {
            $results = Get-CIEMAzureDiscoveryRun -Status 'Completed'
            $results | Should -HaveCount 2
        }

        It 'Returns last N runs with -Last parameter' {
            $results = Get-CIEMAzureDiscoveryRun -Last 2
            $results | Should -HaveCount 2
        }

        It '-Last returns newest first by normalized started_at timestamp' {
            $results = Get-CIEMAzureDiscoveryRun -Last 3
            $results[0].StartedAt | Should -Be '2026-01-03T00:00:00Z'
            $results[2].StartedAt | Should -Be '2026-01-01T00:00:00Z'
        }

        It '-Last orders mixed UTC and offset timestamps by actual instant' {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
            New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-14T17:44:58.106Z' | Out-Null
            New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-14T12:59:51.1161110-05:00' | Out-Null

            $result = Get-CIEMAzureDiscoveryRun -Last 1

            $result.StartedAt | Should -Be '2026-05-14T12:59:51.1161110-05:00'
        }

        It 'Applies -Status before -Last so running runs do not replace the latest completed run' {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
            New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-01-01T00:00:00Z' -CompletedAt '2026-01-01T00:30:00Z'
            New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt '2026-01-02T00:00:00Z'

            $results = @(Get-CIEMAzureDiscoveryRun -Status 'Completed' -Last 1)

            $results | Should -HaveCount 1
            $results[0].Status | Should -Be 'Completed'
            $results[0].CompletedAt | Should -Be '2026-01-01T00:30:00Z'
        }
    }

    Context 'Update-CIEMAzureDiscoveryRun' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
            $script:testRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt '2026-03-01T00:00:00Z'
        }

        It 'Updates Status and CompletedAt' {
            Update-CIEMAzureDiscoveryRun -Id $script:testRun.Id -Status 'Completed' -CompletedAt '2026-03-01T01:00:00Z'
            $result = Get-CIEMAzureDiscoveryRun -Id $script:testRun.Id
            $result.Status | Should -Be 'Completed'
            $result.CompletedAt | Should -Be '2026-03-01T01:00:00Z'
        }

        It 'Updates count fields (ArmTypeCount, ArmRowCount, etc.)' {
            Update-CIEMAzureDiscoveryRun -Id $script:testRun.Id -ArmTypeCount 15 -ArmRowCount 1200 -EntraTypeCount 8 -EntraRowCount 500
            $result = Get-CIEMAzureDiscoveryRun -Id $script:testRun.Id
            $result.ArmTypeCount | Should -Be 15
            $result.ArmRowCount | Should -Be 1200
            $result.EntraTypeCount | Should -Be 8
            $result.EntraRowCount | Should -Be 500
        }

        It 'Partial update preserves unspecified fields' {
            Update-CIEMAzureDiscoveryRun -Id $script:testRun.Id -Status 'Completed'
            $result = Get-CIEMAzureDiscoveryRun -Id $script:testRun.Id
            $result.Scope | Should -Be 'All'
            $result.StartedAt | Should -Be '2026-03-01T00:00:00Z'
        }

        It '-PassThru returns updated object' {
            $result = Update-CIEMAzureDiscoveryRun -Id $script:testRun.Id -Status 'Failed' -ErrorMessage 'Timeout' -PassThru
            $result | Should -Not -BeNullOrEmpty
            $result.GetType().Name | Should -Be 'CIEMAzureDiscoveryRun'
            $result.Status | Should -Be 'Failed'
            $result.ErrorMessage | Should -Be 'Timeout'
        }
    }

    Context 'Save-CIEMAzureDiscoveryRun' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
        }

        It 'Inserts new run when Id is 0 (no id yet)' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureDiscoveryRun]::new()
                $o.Scope = 'All'
                $o.Status = 'Running'
                $o.StartedAt = (Get-Date).ToString('o')
                $o
            }
            Save-CIEMAzureDiscoveryRun -InputObject $obj
            $results = Get-CIEMAzureDiscoveryRun
            $results | Should -HaveCount 1
        }

        It 'Updates existing run when Id > 0' {
            $run = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt (Get-Date).ToString('o')
            $run.Status = 'Completed'
            Save-CIEMAzureDiscoveryRun -InputObject $run
            $result = Get-CIEMAzureDiscoveryRun -Id $run.Id
            $result.Status | Should -Be 'Completed'
        }

        It 'Accepts -InputObject via pipeline' {
            $obj = InModuleScope Devolutions.CIEM {
                $o = [CIEMAzureDiscoveryRun]::new()
                $o.Scope = 'ARM'
                $o.Status = 'Running'
                $o.StartedAt = (Get-Date).ToString('o')
                $o
            }
            $obj | Save-CIEMAzureDiscoveryRun
            $results = Get-CIEMAzureDiscoveryRun
            $results | Should -HaveCount 1
        }
    }

    Context 'Remove-CIEMAzureDiscoveryRun' {
        BeforeEach {
            Invoke-CIEMQuery -Query "DELETE FROM azure_discovery_runs"
            $script:rmRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt (Get-Date).ToString('o')
        }

        It 'Removes by -Id' {
            Remove-CIEMAzureDiscoveryRun -Id $script:rmRun.Id -Confirm:$false
            $result = Get-CIEMAzureDiscoveryRun -Id $script:rmRun.Id
            $result | Should -BeNullOrEmpty
        }

        It 'Removes via -InputObject' {
            $obj = Get-CIEMAzureDiscoveryRun -Id $script:rmRun.Id
            Remove-CIEMAzureDiscoveryRun -InputObject $obj -Confirm:$false
            $result = Get-CIEMAzureDiscoveryRun -Id $script:rmRun.Id
            $result | Should -BeNullOrEmpty
        }

        It 'Throws when -All switch is used (safety constraint — discovery runs are audit records)' {
            { Remove-CIEMAzureDiscoveryRun -All -Confirm:$false } | Should -Throw
        }
    }
}
