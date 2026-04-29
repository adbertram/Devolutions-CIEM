BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    $script:PhaseRegistryPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_phases.psd1'
}

Describe 'Azure Discovery Phase Registry' {
    It 'Declares one discovery phase registry file' {
        $script:PhaseRegistryPath | Should -Exist
    }

    It 'Defines ordered discovery phases with explicit failure modes' {
        $config = Import-PowerShellDataFile -Path $script:PhaseRegistryPath

        $config.Keys | Should -Contain 'ResourceGraphResources'
        $config.Keys | Should -Contain 'ResourceGraphResourceContainers'
        $config.Keys | Should -Contain 'ResourceGraphAuthorizationResources'
        $config.Keys | Should -Contain 'BuiltInRoleDefinitions'
        $config.Keys | Should -Contain 'EntraEntityCollection'
        $config.Keys | Should -Contain 'EntraPermissionCollection'
        $config.Keys | Should -Contain 'EntraRelationshipCollection'

        foreach ($phaseName in $config.Keys) {
            $phase = $config[$phaseName]
            $phase.Keys | Should -Contain 'Order'
            $phase.Keys | Should -Contain 'Name'
            $phase.Keys | Should -Contain 'Scope'
            $phase.Keys | Should -Contain 'Executor'
            $phase.Keys | Should -Contain 'FailureMode'
            $phase.Keys | Should -Contain 'DependsOn'
            $phase.FailureMode | Should -BeIn @('FailRun', 'RecordUnsupported')
        }
    }

    It 'Returns phases sorted by Order and filtered by discovery scope' {
        InModuleScope Devolutions.CIEM {
            $phases = GetCIEMAzureDiscoveryPhaseConfig -Scope 'ARM'

            $phases.Name | Should -Contain 'ResourceGraph/Resources'
            $phases.Name | Should -Contain 'ResourceGraph/ResourceContainers'
            $phases.Name | Should -Contain 'ResourceGraph/AuthorizationResources'
            $phases.Name | Should -Contain 'BuiltInRoleDefinitions'
            $phases.Name | Should -Not -Contain 'Entra entity collection'
            $phases.Order | Should -Be @(10, 20, 30, 40)
        }
    }

    It 'Rejects unknown phase registry fields' {
        InModuleScope Devolutions.CIEM {
            $config = @{
                BadPhase = @{
                    Order = 10
                    Name = 'Bad phase'
                    Scope = @('All')
                    Executor = 'Invoke-Bad'
                    FailureMode = 'FailRun'
                    DependsOn = @()
                    ExtraField = 'not allowed'
                }
            }

            { TestCIEMAzureDiscoveryPhaseRegistry -Config $config } | Should -Throw '*unknown field*'
        }
    }

    It 'Rejects missing phase dependencies' {
        InModuleScope Devolutions.CIEM {
            $config = @{
                BadPhase = @{
                    Order = 10
                    Name = 'Bad phase'
                    Scope = @('All')
                    Executor = 'Invoke-Bad'
                    FailureMode = 'FailRun'
                    DependsOn = @('MissingPhase')
                }
            }

            { TestCIEMAzureDiscoveryPhaseRegistry -Config $config } | Should -Throw '*missing dependency*'
        }
    }
}

Describe 'InvokeCIEMDiscoveryPhase failure modes' {
    It 'Throws immediately when a FailRun phase action fails' {
        InModuleScope Devolutions.CIEM {
            $errors = [System.Collections.Generic.List[string]]::new()
            $warnings = [ref]0

            {
                InvokeCIEMDiscoveryPhase `
                    -Name 'FailRunPhase' `
                    -FailureMode 'FailRun' `
                    -ErrorMessages $errors `
                    -WarningCounter $warnings `
                    -WarningAction SilentlyContinue `
                    -Action { throw 'hard failure' }
            } | Should -Throw '*FailRunPhase failed: hard failure*'

            $errors | Should -HaveCount 1
            $warnings.Value | Should -Be 1
        }
    }

    It 'Records unsupported phases without throwing when FailureMode is RecordUnsupported' {
        InModuleScope Devolutions.CIEM {
            $errors = [System.Collections.Generic.List[string]]::new()
            $warnings = [ref]0

            $result = InvokeCIEMDiscoveryPhase `
                -Name 'UnsupportedPhase' `
                -FailureMode 'RecordUnsupported' `
                -ErrorMessages $errors `
                -WarningCounter $warnings `
                -WarningAction SilentlyContinue `
                -Action { throw 'endpoint unavailable' }

            $result.Succeeded | Should -BeFalse
            $errors | Should -HaveCount 1
            $errors[0] | Should -Be 'UnsupportedPhase failed: endpoint unavailable'
            $warnings.Value | Should -Be 1
        }
    }
}
