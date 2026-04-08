BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
}

Describe 'InvokeCIEMBatchInsert shared helper' {
    BeforeEach {
        InModuleScope Devolutions.CIEM {
            $script:batchCallLog = [System.Collections.Generic.List[object]]::new()
        }
    }

    It 'Function exists and is private (not exported)' {
        InModuleScope Devolutions.CIEM {
            Get-Command -Name InvokeCIEMBatchInsert -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
        (Get-Command -Module Devolutions.CIEM -Name InvokeCIEMBatchInsert -ErrorAction SilentlyContinue) | Should -BeNullOrEmpty
    }

    It 'Computes chunk size from column count to stay under 999 SQLite parameter cap' {
        InModuleScope Devolutions.CIEM {
            Mock Invoke-CIEMQuery {
                $script:batchCallLog.Add([pscustomobject]@{
                    Query = $Query
                    Parameters = $Parameters
                })
            }

            # 17 columns (matches azure_arm_resources). Max chunk under 999 = floor(999/17) = 58.
            $columns = 1..17 | ForEach-Object { "col$_" }
            $items = 1..60 | ForEach-Object {
                $row = [ordered]@{}
                for ($i = 1; $i -le 17; $i++) { $row["col$i"] = "v${_}_$i" }
                [pscustomobject]$row
            }

            InvokeCIEMBatchInsert -Table 'test_table' -Columns $columns -Items $items

            @($script:batchCallLog).Count | Should -Be 2
            @($script:batchCallLog[0].Parameters.Keys).Count | Should -BeLessOrEqual 999
            @($script:batchCallLog[0].Parameters.Keys).Count | Should -Be (58 * 17)
            @($script:batchCallLog[1].Parameters.Keys).Count | Should -Be (2 * 17)
        }
    }

    It 'Uses a single INSERT when all items fit in one chunk' {
        InModuleScope Devolutions.CIEM {
            Mock Invoke-CIEMQuery {
                $script:batchCallLog.Add([pscustomobject]@{ Query = $Query; Parameters = $Parameters })
            }

            $columns = @('a', 'b', 'c')
            $items = 1..10 | ForEach-Object { [pscustomobject]@{ a = "a$_"; b = "b$_"; c = "c$_" } }

            InvokeCIEMBatchInsert -Table 'small_table' -Columns $columns -Items $items

            @($script:batchCallLog).Count | Should -Be 1
            @($script:batchCallLog[0].Parameters.Keys).Count | Should -Be 30
            $script:batchCallLog[0].Query | Should -Match 'INSERT OR REPLACE INTO small_table'
        }
    }

    It 'No-ops cleanly when items is empty' {
        InModuleScope Devolutions.CIEM {
            Mock Invoke-CIEMQuery {
                $script:batchCallLog.Add($Parameters)
            }

            InvokeCIEMBatchInsert -Table 'empty_table' -Columns @('a', 'b') -Items @()

            @($script:batchCallLog).Count | Should -Be 0
        }
    }

    It 'Respects an explicit Connection by routing to Invoke-PSUSQLiteQuery' {
        InModuleScope Devolutions.CIEM {
            Mock Invoke-PSUSQLiteQuery {
                $script:batchCallLog.Add([pscustomobject]@{ Target = 'PSUSQLite'; Parameters = $Parameters })
            }
            Mock Invoke-CIEMQuery {
                $script:batchCallLog.Add([pscustomobject]@{ Target = 'CIEMQuery'; Parameters = $Parameters })
            }

            $fakeConnection = [pscustomobject]@{ Marker = 'stub' }
            $items = 1..3 | ForEach-Object { [pscustomobject]@{ a = "a$_"; b = "b$_" } }

            InvokeCIEMBatchInsert -Table 'conn_table' -Columns @('a', 'b') -Items $items -Connection $fakeConnection

            @($script:batchCallLog).Count | Should -Be 1
            $script:batchCallLog[0].Target | Should -Be 'PSUSQLite'
        }
    }

    It 'Has ErrorActionPreference = Stop and throws on downstream failure' {
        InModuleScope Devolutions.CIEM {
            Mock Invoke-CIEMQuery { throw 'database boom' }
            $items = @([pscustomobject]@{ a = 1; b = 2 })
            { InvokeCIEMBatchInsert -Table 't' -Columns @('a', 'b') -Items $items } | Should -Throw '*database boom*'
        }
    }

    It 'Reads values from both hashtables and PSCustomObjects via a unified lookup' {
        InModuleScope Devolutions.CIEM {
            Mock Invoke-CIEMQuery {
                $script:batchCallLog.Add($Parameters)
            }

            $mixedItems = @(
                [pscustomobject]@{ Id = 'obj-1'; Name = 'alpha' }
                @{ Id = 'ht-2'; Name = 'beta' }
                [ordered]@{ Id = 'ord-3'; Name = 'gamma' }
            )

            InvokeCIEMBatchInsert -Table 'mixed_table' -Columns @('id', 'name') -Items $mixedItems

            @($script:batchCallLog).Count | Should -Be 1
            $capturedParams = $script:batchCallLog[0]
            $capturedParams['id_1'] | Should -Be 'obj-1'
            $capturedParams['name_1'] | Should -Be 'alpha'
            $capturedParams['id_2'] | Should -Be 'ht-2'
            $capturedParams['name_2'] | Should -Be 'beta'
            $capturedParams['id_3'] | Should -Be 'ord-3'
            $capturedParams['name_3'] | Should -Be 'gamma'
        }
    }

    It 'Throws fail-fast on items of unknown types (neither IDictionary nor PSObject-backed)' {
        InModuleScope Devolutions.CIEM {
            Mock Invoke-CIEMQuery {
                $script:batchCallLog.Add($Parameters)
            }

            # A raw int isn't a dictionary; BCL primitives expose a PSObject wrapper with
            # no Id/Name properties, so the lookup finds nothing. A fail-fast helper should
            # throw instead of silently inserting NULLs.
            $badItems = @([int]42)

            { InvokeCIEMBatchInsert -Table 'bad_table' -Columns @('id', 'name') -Items $badItems } |
                Should -Throw '*unsupported item type*'

            @($script:batchCallLog).Count | Should -Be 0
        }
    }
}
