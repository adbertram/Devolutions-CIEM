BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Attack path remediation token registry' {

    Context 'Registry contract' {
        It 'loads a strict remediation token registry' {
            InModuleScope Devolutions.CIEM {
                TestCIEMAttackPathRemediationTokenRegistry | Should -BeTrue
                $registry = GetCIEMAttackPathRemediationTokenConfig
                $registry.Keys | Should -Contain 'PATTERN_NAME'
                $registry.Keys | Should -Contain 'PATH_CHAIN'
                $registry.Keys | Should -Contain 'ROLE_ASSIGNMENT_DELETE_COMMANDS'
                $registry.Keys | Should -Contain 'NSG_RULE_DELETE_COMMANDS'
                $registry.Keys | Should -Contain 'GROUP_MEMBER_REMOVE_COMMANDS'
            }
        }

        It 'declares resolver, required context, output type, and description for every token' {
            InModuleScope Devolutions.CIEM {
                $allowedFields = @(
                    'Name',
                    'Resolver',
                    'RequiredNodeKinds',
                    'RequiredEdgeKinds',
                    'RequiredEdgeKindMode',
                    'OutputType',
                    'Description'
                )

                $registry = GetCIEMAttackPathRemediationTokenConfig
                foreach ($token in $registry.Keys) {
                    $entry = $registry[$token]
                    @($entry.Keys) | Sort-Object | Should -Be (@($allowedFields) | Sort-Object)
                    $entry.Name | Should -Be $token
                    $entry.Resolver | Should -Not -BeNullOrEmpty
                    Get-Command -Name $entry.Resolver -CommandType Function -ErrorAction Stop | Should -Not -BeNullOrEmpty
                    $entry.ContainsKey('RequiredNodeKinds') | Should -BeTrue
                    $entry.ContainsKey('RequiredEdgeKinds') | Should -BeTrue
                    $entry.RequiredEdgeKindMode | Should -BeIn @('All', 'Any')
                    $entry.OutputType | Should -BeIn @('Text', 'PowerShell')
                    $entry.Description | Should -Not -BeNullOrEmpty
                }
            }
        }

        It 'contains every replacement token used by shipped remediation script templates' {
            InModuleScope Devolutions.CIEM {
                $registry = GetCIEMAttackPathRemediationTokenConfig
                $templateFiles = @(Get-ChildItem -Path (Join-Path $script:GraphRoot 'Data/attack_path_remediation_scripts') -Filter '*.ps1')
                $templateFiles | Should -Not -BeNullOrEmpty

                foreach ($file in $templateFiles) {
                    $content = Get-Content -Path $file.FullName -Raw
                    $tokens = @([regex]::Matches($content, '{{([A-Z0-9_]+)}}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
                    foreach ($token in $tokens) {
                        $registry.ContainsKey($token) | Should -BeTrue -Because "$($file.Name) uses token '$token'"
                    }
                }
            }
        }
    }

    Context 'Render validation' {
        It 'throws when script content contains an unknown remediation token' {
            InModuleScope Devolutions.CIEM {
                $pattern = [pscustomobject]@{ Name = 'Registry Test Pattern' }
                $attackPath = [pscustomobject]@{
                    PatternId     = 'registry-test'
                    PsuScriptName = 'registry-test'
                    Path          = @([pscustomobject]@{ id = 'node-1'; kind = 'EntraUser'; display_name = 'Node One' })
                    Edges         = @()
                }

                { ResolveCIEMAttackPathScriptContent -Pattern $pattern -AttackPath $attackPath -ScriptContent '{{UNKNOWN_TOKEN}}' } |
                    Should -Throw "*unknown token 'UNKNOWN_TOKEN'*"
            }
        }

        It 'throws before resolving a token when the attack path is missing required edge context' {
            InModuleScope Devolutions.CIEM {
                $pattern = [pscustomobject]@{ Name = 'Missing Edge Pattern' }
                $attackPath = [pscustomobject]@{
                    PatternId     = 'missing-edge'
                    PsuScriptName = 'missing-edge'
                    Path          = @([pscustomobject]@{ id = 'node-1'; kind = 'AzureVM'; display_name = 'VM One' })
                    Edges         = @()
                }

                { ResolveCIEMAttackPathScriptContent -Pattern $pattern -AttackPath $attackPath -ScriptContent '{{NSG_RULE_DELETE_COMMANDS}}' } |
                    Should -Throw "*requires edge kind 'AllowsInbound'*"
            }
        }
    }
}
