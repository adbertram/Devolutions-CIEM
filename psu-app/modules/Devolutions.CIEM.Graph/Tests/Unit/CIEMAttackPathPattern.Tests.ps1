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

        It 'returns all 10 known pattern IDs' {
            $results = @(Get-CIEMAttackPathPattern)
            $ids = @($results | ForEach-Object { $_.Id })
            $ids | Should -Contain 'disabled-account-with-roles'
            $ids | Should -Contain 'dormant-privileged-subscription-access'
            $ids | Should -Contain 'group-inherited-privilege-escalation'
            $ids | Should -Contain 'internet-exposed-privileged-mi'
            $ids | Should -Contain 'open-management-port'
            $ids | Should -Contain 'public-vm-to-keyvault'
            $ids | Should -Contain 'guest-user-with-privileged-role'
            $ids | Should -Contain 'privileged-managed-identity-broad-scope'
            $ids | Should -Contain 'service-principal-owner-on-subscription'
            $ids | Should -Contain 'guest-in-privileged-group'
        }

        It 'returns at least 10 patterns (resilient to future additions)' {
            @(Get-CIEMAttackPathPattern).Count | Should -BeGreaterOrEqual 10
        }

        $knownPatterns = @(
            @{ Id = 'disabled-account-with-roles';                   StepCount = 2; Severity = 'high';     Category = 'identity-hygiene' }
            @{ Id = 'dormant-privileged-subscription-access';        StepCount = 3; Severity = 'critical'; Category = 'identity-hygiene' }
            @{ Id = 'group-inherited-privilege-escalation';          StepCount = 2; Severity = 'high';     Category = 'identity-privilege' }
            @{ Id = 'internet-exposed-privileged-mi';                StepCount = 8; Severity = 'critical'; Category = 'identity-network-compound' }
            @{ Id = 'open-management-port';                          StepCount = 3; Severity = 'high';     Category = 'network-exposure' }
            @{ Id = 'public-vm-to-keyvault';                         StepCount = 9; Severity = 'critical'; Category = 'identity-network-compound' }
            @{ Id = 'guest-user-with-privileged-role';               StepCount = 2; Severity = 'critical'; Category = 'identity-privilege' }
            @{ Id = 'privileged-managed-identity-broad-scope';       StepCount = 5; Severity = 'critical'; Category = 'identity-privilege' }
            @{ Id = 'service-principal-owner-on-subscription';       StepCount = 3; Severity = 'high';     Category = 'identity-privilege' }
            @{ Id = 'guest-in-privileged-group';                     StepCount = 4; Severity = 'high';     Category = 'identity-privilege' }
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
            $p.Remediation | Should -Not -BeNullOrEmpty
            $p.RemediationScriptPath | Should -Not -BeNullOrEmpty
        }

        It 'returns remediation guidance for every shipped pattern' {
            $results = @(Get-CIEMAttackPathPattern)
            foreach ($p in $results) {
                $p.Remediation | Should -Not -BeNullOrEmpty -Because "pattern '$($p.Id)' must provide remediation guidance"
                $p.Remediation | Should -Match 'rerun Azure discovery' -Because "pattern '$($p.Id)' remediation must include validation guidance"
            }
        }

        It 'maps every shipped pattern to a rule-name slug remediation script folder' {
            $scriptRoot = InModuleScope Devolutions.CIEM { Join-Path $script:GraphRoot 'Data' }
            $results = @(Get-CIEMAttackPathPattern)
            foreach ($p in $results) {
                $slug = InModuleScope Devolutions.CIEM -Parameters @{ name = $p.Name } {
                    param($name)
                    ConvertToCIEMAttackPathRuleSlug -Name $name
                }
                $p.RemediationScriptPath | Should -Be "attack_path_remediation_scripts/$slug/remediate.ps1"
                Join-Path $scriptRoot $p.RemediationScriptPath | Should -Exist
            }
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

        It 'Remediation is [string], not an object or array' {
            $first = @(Get-CIEMAttackPathPattern)[0]
            $first.Remediation | Should -BeOfType [string]
        }

        It 'RemediationScriptPath is [string], not an object or array' {
            $first = @(Get-CIEMAttackPathPattern)[0]
            $first.RemediationScriptPath | Should -BeOfType [string]
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

        It 'filtering by Severity critical returns exactly 5 patterns' {
            $critical = @(Get-CIEMAttackPathPattern | Where-Object Severity -eq 'critical')
            $critical.Count | Should -Be 5
            $critical | ForEach-Object { $_.Severity | Should -Be 'critical' }
        }

        It 'filtering by Severity high returns exactly 5 patterns' {
            $high = @(Get-CIEMAttackPathPattern | Where-Object Severity -eq 'high')
            $high.Count | Should -Be 5
            $high | ForEach-Object { $_.Severity | Should -Be 'high' }
        }
    }

    Context 'Schema guardrails — shipped patterns only use known primitives' {

        BeforeAll {
            $script:ValidNodeKinds = @(
                'EntraUser', 'EntraServicePrincipal', 'EntraGroup', 'EntraManagedIdentity', 'EntraDirectoryRole',
                'AzureTenant', 'AzureSubscription', 'AzureResourceGroup', 'AzureVM', 'AzureNIC', 'AzureNSG',
                'AzureVNet', 'AzurePublicIP', 'AzureKeyVault', 'AzureRoleAssignment',
                'Internet'
            )
            $script:ValidEdgeKinds = @(
                'HasRole', 'InheritedRole', 'MemberOf', 'TransitiveMemberOf', 'OwnerOf',
                'HasRoleMember', 'HasManagedIdentity', 'AttachedTo', 'HasPublicIP',
                'InSubnet', 'AllowsInbound', 'ContainedIn'
            )
            $script:ValidFilterOps = @('eq', 'neq', 'gt', 'lt', 'gt_or_null', 'in', 'contains_port')

            $script:PatternDir = InModuleScope Devolutions.CIEM { Join-Path $script:GraphRoot 'Data' 'attack_paths' }
            $script:PatternFiles = @(Get-ChildItem -Path $script:PatternDir -Filter '*.json' -File)
        }

        It 'every step with a kind uses a known node kind' {
            foreach ($file in $script:PatternFiles) {
                $raw = Get-Content $file.FullName -Raw | ConvertFrom-Json
                foreach ($step in $raw.steps) {
                    if ($step.kind) {
                        $kinds = @($step.kind)
                        foreach ($k in $kinds) {
                            $k | Should -BeIn $script:ValidNodeKinds -Because "pattern '$($raw.id)' in $($file.Name) uses unknown kind '$k'"
                        }
                    }
                }
            }
        }

        It 'every step with an edge uses a known edge kind' {
            foreach ($file in $script:PatternFiles) {
                $raw = Get-Content $file.FullName -Raw | ConvertFrom-Json
                foreach ($step in $raw.steps) {
                    if ($step.edge) {
                        $step.edge | Should -BeIn $script:ValidEdgeKinds -Because "pattern '$($raw.id)' in $($file.Name) uses unknown edge '$($step.edge)'"
                    }
                }
            }
        }

        It 'every filter op is a known operator' {
            foreach ($file in $script:PatternFiles) {
                $raw = Get-Content $file.FullName -Raw | ConvertFrom-Json
                foreach ($step in $raw.steps) {
                    if ($step.node_filter) {
                        $step.node_filter.op | Should -BeIn $script:ValidFilterOps -Because "pattern '$($raw.id)' node_filter op '$($step.node_filter.op)' is unknown"
                    }
                    if ($step.filter) {
                        $step.filter.op | Should -BeIn $script:ValidFilterOps -Because "pattern '$($raw.id)' edge filter op '$($step.filter.op)' is unknown"
                    }
                }
            }
        }

        It 'every pattern has required top-level fields' {
            foreach ($file in $script:PatternFiles) {
                $raw = Get-Content $file.FullName -Raw | ConvertFrom-Json
                $raw.id          | Should -Not -BeNullOrEmpty -Because "pattern in $($file.Name) missing id"
                $raw.name        | Should -Not -BeNullOrEmpty -Because "pattern '$($raw.id)' missing name"
                $raw.severity    | Should -Not -BeNullOrEmpty -Because "pattern '$($raw.id)' missing severity"
                $raw.category    | Should -Not -BeNullOrEmpty -Because "pattern '$($raw.id)' missing category"
                $raw.description | Should -Not -BeNullOrEmpty -Because "pattern '$($raw.id)' missing description"
                $raw.remediation | Should -Not -BeNullOrEmpty -Because "pattern '$($raw.id)' missing remediation"
                $raw.remediation_script | Should -Not -BeNullOrEmpty -Because "pattern '$($raw.id)' missing remediation_script"
                @($raw.steps).Count | Should -BeGreaterThan 0 -Because "pattern '$($raw.id)' has no steps"
            }
        }

        It 'every remediation script template has no unknown replacement token format' {
            $scriptRoot = InModuleScope Devolutions.CIEM { Join-Path $script:GraphRoot 'Data' }
            foreach ($file in $script:PatternFiles) {
                $raw = Get-Content $file.FullName -Raw | ConvertFrom-Json
                $scriptPath = Join-Path $scriptRoot $raw.remediation_script
                $scriptPath | Should -Exist -Because "pattern '$($raw.id)' references a missing remediation script template"
                $content = Get-Content $scriptPath -Raw
                $tokens = @([regex]::Matches($content, '{{([A-Z0-9_]+)}}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
                foreach ($token in $tokens) {
                    $token | Should -BeIn @(
                        'PATTERN_NAME',
                        'PATH_CHAIN',
                        'ROLE_ASSIGNMENT_DELETE_COMMANDS',
                        'NSG_RULE_DELETE_COMMANDS',
                        'GROUP_MEMBER_REMOVE_COMMANDS'
                    ) -Because "pattern '$($raw.id)' template uses unknown token '$token'"
                }
            }
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
