BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    $script:ParallelHelperPath = Join-Path $PSScriptRoot '..' '..' 'Private' 'InvokeCIEMParallelForEach.ps1'
    $script:ParallelHelperSource = if (Test-Path $script:ParallelHelperPath) {
        Get-Content -Path $script:ParallelHelperPath -Raw
    }
    else {
        ''
    }
}

Describe 'InvokeCIEMParallelForEach private helper' {
    It 'Function exists with the no-dash name' {
        InModuleScope Devolutions.CIEM {
            Get-Command -Name InvokeCIEMParallelForEach -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    It 'Old dashed name no longer exists in the module' {
        InModuleScope Devolutions.CIEM {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Invoke-CIEMParallelForEach'
        }
    }

    It 'Source file declares ErrorActionPreference = Stop' {
        $script:ParallelHelperSource | Should -Match "\`$ErrorActionPreference\s*=\s*'Stop'"
    }

    It 'Source file does NOT use Import-Module -Force inside the parallel block' {
        $script:ParallelHelperSource | Should -Not -Match 'Import-Module\s+\$using:modulePath\s+-Force'
    }

    It 'Source file uses a Get-Module guard before importing the module in the runspace' {
        $script:ParallelHelperSource | Should -Match 'Get-Module\s+Devolutions\.CIEM'
        $script:ParallelHelperSource | Should -Match 'CIEMRunspaceInitialized'
    }

    It 'Returns Success records for each item with structured Result/Error fields' {
        $script:result = InModuleScope Devolutions.CIEM {
            $items = 1..3 | ForEach-Object { [pscustomobject]@{ Index = $_ } }
            InvokeCIEMParallelForEach -InputObject $items -ThrottleLimit 2 -ScriptBlock {
                param($workItem)
                [pscustomobject]@{ Doubled = $workItem.Index * 2 }
            }
        }

        @($script:result) | Should -HaveCount 3
        @($script:result | Where-Object { $_.Success }) | Should -HaveCount 3
    }

    It 'Resolves module-defined class types inside the parallel scriptblock' {
        $script:result = InModuleScope Devolutions.CIEM {
            InvokeCIEMParallelForEach -InputObject @([pscustomobject]@{ Id = 'test-1' }) -ThrottleLimit 1 -ScriptBlock {
                param($workItem)
                $check = [CIEMCheck]::new()
                $check.Id = $workItem.Id
                $check.Provider = 'Azure'
                $check.Service = 'Entra'
                $check.Title = 'Test'
                $check.Severity = [CIEMCheckSeverity]'medium'
                [pscustomobject]@{ CheckId = $check.Id; TypeName = $check.GetType().Name }
            }
        }

        $script:result | Should -HaveCount 1
        $script:result[0].Success | Should -BeTrue
        $script:result[0].Result[0].CheckId | Should -Be 'test-1'
        $script:result[0].Result[0].TypeName | Should -Be 'CIEMCheck'
    }

    It 'Captures exceptions inside the parallel block as Success=$false records' {
        $script:result = InModuleScope Devolutions.CIEM {
            InvokeCIEMParallelForEach -InputObject @([pscustomobject]@{ Bad = $true }) -ThrottleLimit 1 -ScriptBlock {
                param($workItem)
                throw 'parallel-failure'
            }
        }

        $script:result | Should -HaveCount 1
        $script:result[0].Success | Should -BeFalse
        $script:result[0].Error | Should -Match 'parallel-failure'
    }
}
