BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Get-CIEMAttackPathPattern — catalog projection' {

    Context 'Command structure' {
        It 'is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAttackPathPattern -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'has no filter parameters (callers use Where-Object)' {
            $cmd = Get-Command -Module Devolutions.CIEM -Name Get-CIEMAttackPathPattern
            $cmd.Parameters.Keys | Where-Object { $_ -notin @('Verbose','Debug','ErrorAction','WarningAction','InformationAction','ErrorVariable','WarningVariable','InformationVariable','OutVariable','OutBuffer','PipelineVariable','ProgressAction') } | Should -BeNullOrEmpty
        }
    }

    Context 'Happy path — shipped catalog' {

        It 'returns all 6 known pattern IDs' {
            $results = @(Get-CIEMAttackPathPattern)
            $ids = @($results | ForEach-Object { $_.Id })
            $ids | Should -Contain 'disabled-account-with-roles'
            $ids | Should -Contain 'dormant-privileged-subscription-access'
            $ids | Should -Contain 'group-inherited-privilege-escalation'
            $ids | Should -Contain 'internet-exposed-privileged-mi'
            $ids | Should -Contain 'open-management-port'
            $ids | Should -Contain 'public-vm-to-keyvault'
        }

        It 'returns at least 6 patterns (resilient to future additions)' {
            @(Get-CIEMAttackPathPattern).Count | Should -BeGreaterOrEqual 6
        }

        $knownPatterns = @(
            @{ Id = 'disabled-account-with-roles';               StepCount = 2; Severity = 'high';     Category = 'identity-hygiene' }
            @{ Id = 'dormant-privileged-subscription-access';    StepCount = 3; Severity = 'critical'; Category = 'identity-hygiene' }
            @{ Id = 'group-inherited-privilege-escalation';      StepCount = 2; Severity = 'high';     Category = 'identity-privilege' }
            @{ Id = 'internet-exposed-privileged-mi';            StepCount = 8; Severity = 'critical'; Category = 'identity-network-compound' }
            @{ Id = 'open-management-port';                      StepCount = 3; Severity = 'high';     Category = 'network-exposure' }
            @{ Id = 'public-vm-to-keyvault';                     StepCount = 9; Severity = 'critical'; Category = 'identity-network-compound' }
        )

        It 'projects <Id> with StepCount=<StepCount>, Severity=<Severity>, Category=<Category>' -TestCases $knownPatterns {
            param($Id, $StepCount, $Severity, $Category)
            $p = Get-CIEMAttackPathPattern | Where-Object Id -eq $Id
            $p           | Should -Not -BeNullOrEmpty
            $p.StepCount | Should -Be $StepCount
            $p.Severity  | Should -Be $Severity
            $p.Category  | Should -Be $Category
            $p.Name      | Should -Not -BeNullOrEmpty
            $p.Description | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Return shape' {

        It 'applies PSTypeName CIEMAttackPathPattern' {
            $first = @(Get-CIEMAttackPathPattern)[0]
            $first.PSObject.TypeNames | Should -Contain 'CIEMAttackPathPattern'
        }

        It 'StepCount is [int], not [string]' {
            $first = @(Get-CIEMAttackPathPattern)[0]
            $first.StepCount | Should -BeOfType [int]
        }

        It 'always returns an array (full catalog)' {
            ,(Get-CIEMAttackPathPattern) | Should -BeOfType [array]
        }

        It 'all Severity values are lowercase (case-sensitive match)' {
            $results = @(Get-CIEMAttackPathPattern)
            foreach ($p in $results) {
                $p.Severity | Should -CMatch '^(critical|high|medium|low)$'
            }
        }
    }

    Context 'Caller-side filtering via Where-Object' {

        It 'filtering by Severity critical returns exactly 3 patterns' {
            $critical = @(Get-CIEMAttackPathPattern | Where-Object Severity -eq 'critical')
            $critical.Count | Should -Be 3
            $critical | ForEach-Object { $_.Severity | Should -Be 'critical' }
        }

        It 'filtering by Severity high returns exactly 3 patterns' {
            $high = @(Get-CIEMAttackPathPattern | Where-Object Severity -eq 'high')
            $high.Count | Should -Be 3
            $high | ForEach-Object { $_.Severity | Should -Be 'high' }
        }
    }

    Context 'Error handling — isolated module state' {

        BeforeEach {
            $script:testRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            New-Item -Path (Join-Path $script:testRoot 'Data' 'attack_paths') -ItemType Directory -Force | Out-Null
        }

        It 'tolerates a malformed JSON file and returns valid siblings' {
            $validPath = Join-Path $script:testRoot 'Data' 'attack_paths' 'valid.json'
            @'
{ "id": "valid-pattern", "name": "Valid", "severity": "low", "category": "test", "description": "test pattern", "steps": [{"kind":"EntraUser"}] }
'@ | Set-Content -Path $validPath -Encoding UTF8

            $badPath = Join-Path $script:testRoot 'Data' 'attack_paths' 'broken.json'
            '{ this is not valid json' | Set-Content -Path $badPath -Encoding UTF8

            $capturedRoot = $script:testRoot
            $results = InModuleScope Devolutions.CIEM -Parameters @{ capturedRoot = $capturedRoot } {
                param($capturedRoot)
                $originalRoot = $script:GraphRoot
                try {
                    $script:GraphRoot = $capturedRoot
                    @(Get-CIEMAttackPathPattern)
                } finally {
                    $script:GraphRoot = $originalRoot
                }
            }

            $results.Count | Should -Be 1
            $results[0].Id | Should -Be 'valid-pattern'
            Should -Invoke -ModuleName Devolutions.CIEM -CommandName Write-CIEMLog -ParameterFilter {
                $Severity -eq 'ERROR' -and $Message -match 'broken\.json'
            }
        }

        It 'null-guards StepCount when steps field is missing (returns 0, not 1)' {
            $noStepsPath = Join-Path $script:testRoot 'Data' 'attack_paths' 'no-steps.json'
            @'
{ "id": "no-steps-pattern", "name": "NoSteps", "severity": "low", "category": "test", "description": "pattern with no steps" }
'@ | Set-Content -Path $noStepsPath -Encoding UTF8

            $capturedRoot = $script:testRoot
            $results = InModuleScope Devolutions.CIEM -Parameters @{ capturedRoot = $capturedRoot } {
                param($capturedRoot)
                $originalRoot = $script:GraphRoot
                try {
                    $script:GraphRoot = $capturedRoot
                    @(Get-CIEMAttackPathPattern)
                } finally {
                    $script:GraphRoot = $originalRoot
                }
            }

            $results.Count | Should -Be 1
            $results[0].StepCount | Should -Be 0
            $results[0].StepCount | Should -BeOfType [int]
        }

        It 'throws when pattern directory does not exist (fail-fast)' {
            $missingRoot = Join-Path $TestDrive 'missing-graph-root'
            New-Item -Path $missingRoot -ItemType Directory -Force | Out-Null

            {
                InModuleScope Devolutions.CIEM -Parameters @{ missingRoot = $missingRoot } {
                    param($missingRoot)
                    $originalRoot = $script:GraphRoot
                    try {
                        $script:GraphRoot = $missingRoot
                        Get-CIEMAttackPathPattern
                    } finally {
                        $script:GraphRoot = $originalRoot
                    }
                }
            } | Should -Throw
        }
    }
}
