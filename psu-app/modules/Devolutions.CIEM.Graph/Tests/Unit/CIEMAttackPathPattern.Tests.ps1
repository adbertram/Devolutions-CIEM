BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Discovery' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    $graphSchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'graph_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $graphSchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    Sync-CIEMAttackPathRuleCatalog | Out-Null
}

Describe 'Get-CIEMAttackPathPattern — catalog projection' {

    BeforeEach {
        Invoke-CIEMQuery -Query 'DELETE FROM attack_paths'
        Invoke-CIEMQuery -Query 'DELETE FROM attack_path_rules'
        Sync-CIEMAttackPathRuleCatalog | Out-Null
    }

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
            $scriptRoot = InModuleScope Devolutions.CIEM { $script:ModuleRoot }
            $results = @(Get-CIEMAttackPathPattern)
            foreach ($p in $results) {
                $slug = InModuleScope Devolutions.CIEM -Parameters @{ name = $p.Name } {
                    param($name)
                    ConvertToCIEMAttackPathRuleSlug -Name $name
                }
                $p.RemediationScriptPath | Should -Be "modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/$slug.ps1"
                Join-Path $scriptRoot $p.RemediationScriptPath | Should -Exist
            }
        }
    }

    Context 'Return shape' {

        It 'returns typed CIEMAttackPathRule objects' {
            $first = @(Get-CIEMAttackPathPattern)[0]
            $first.GetType().Name | Should -Be 'CIEMAttackPathRule'
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
            $scriptRoot = InModuleScope Devolutions.CIEM { $script:ModuleRoot }
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
                        'GROUP_MEMBER_REMOVE_COMMANDS',
                        'AUTH_PROFILE_ID',
                        'AUTH_PROFILE_NAME',
                        'AUTH_PROFILE_METHOD',
                        'TENANT_ID',
                        'CLIENT_ID',
                        'MANAGED_IDENTITY_CLIENT_ID',
                        'PSU_ENVIRONMENT',
                        'PSU_WEBSITE_NAME'
                    ) -Because "pattern '$($raw.id)' template uses unknown token '$token'"
                }
            }
        }
    }

    Context 'Database-backed rule handling' {

        It 'returns caller-created active database rules as typed objects' {
            Invoke-CIEMQuery -Query @'
INSERT INTO attack_path_rules (
    id, name, severity, category, description, remediation,
    remediation_script_path, psu_script_name, steps_json, disabled, updated_at
) VALUES (
    @id, @name, @severity, @category, @description, @remediation,
    @remediation_script_path, @psu_script_name, @steps_json, 0, @updated_at
)
'@ -Parameters @{
                id                      = 'custom-db-rule'
                name                    = 'Custom DB Rule'
                severity                = 'low'
                category                = 'custom'
                description             = 'Custom rule from database'
                remediation             = 'Fix the custom rule and rerun Azure discovery.'
                remediation_script_path = 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/management-port-open-to-the-internet.ps1'
                psu_script_name         = 'management-port-open-to-the-internet'
                steps_json              = '[{"kind":"Internet"},{"edge":"AllowsInbound","direction":"outbound"},{"kind":"AzureNSG"}]'
                updated_at              = '2026-04-17T00:00:00.0000000Z'
            } -AsNonQuery | Out-Null

            $rule = @(Get-CIEMAttackPathPattern | Where-Object Id -eq 'custom-db-rule')[0]

            $rule.GetType().Name | Should -Be 'CIEMAttackPathRule'
            $rule.Id | Should -Be 'custom-db-rule'
            $rule.StepCount | Should -Be 3
            $rule.PsuScriptName | Should -Be 'management-port-open-to-the-internet'
        }

        It 'excludes disabled database rules' {
            Invoke-CIEMQuery -Query @'
INSERT INTO attack_path_rules (
    id, name, severity, category, description, remediation,
    remediation_script_path, psu_script_name, steps_json, disabled, updated_at
) VALUES (
    @id, @name, @severity, @category, @description, @remediation,
    @remediation_script_path, @psu_script_name, @steps_json, 1, @updated_at
)
'@ -Parameters @{
                id                      = 'disabled-db-rule'
                name                    = 'Disabled DB Rule'
                severity                = 'low'
                category                = 'custom'
                description             = 'Disabled rule from database'
                remediation             = 'Fix the custom rule and rerun Azure discovery.'
                remediation_script_path = 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/management-port-open-to-the-internet.ps1'
                psu_script_name         = 'management-port-open-to-the-internet'
                steps_json              = '[{"kind":"Internet"},{"edge":"AllowsInbound","direction":"outbound"},{"kind":"AzureNSG"}]'
                updated_at              = '2026-04-17T00:00:00.0000000Z'
            } -AsNonQuery | Out-Null

            @(Get-CIEMAttackPathPattern | Where-Object Id -eq 'disabled-db-rule') | Should -HaveCount 0
        }

        It 'throws when an active database rule has no PSU script reference' {
            Invoke-CIEMQuery -Query @'
INSERT INTO attack_path_rules (
    id, name, severity, category, description, remediation,
    remediation_script_path, psu_script_name, steps_json, disabled, updated_at
) VALUES (
    @id, @name, @severity, @category, @description, @remediation,
    @remediation_script_path, @psu_script_name, @steps_json, 0, @updated_at
)
'@ -Parameters @{
                id                      = 'missing-script-rule'
                name                    = 'Missing Script Rule'
                severity                = 'low'
                category                = 'custom'
                description             = 'Invalid active rule'
                remediation             = 'Fix the custom rule and rerun Azure discovery.'
                remediation_script_path = 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/management-port-open-to-the-internet.ps1'
                psu_script_name         = ''
                steps_json              = '[{"kind":"Internet"},{"edge":"AllowsInbound","direction":"outbound"},{"kind":"AzureNSG"}]'
                updated_at              = '2026-04-17T00:00:00.0000000Z'
            } -AsNonQuery | Out-Null

            { Get-CIEMAttackPathPattern } | Should -Throw '*PSU script reference*'
        }
    }
}
