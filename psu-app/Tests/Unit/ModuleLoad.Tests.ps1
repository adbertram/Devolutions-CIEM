BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' '..'
}

Describe 'Module Load — Post-Discovery-Schema' {

    Context 'Module imports without errors' {
        It 'Imports Devolutions.CIEM without throwing' {
            Get-Module Devolutions.CIEM | Should -Not -BeNullOrEmpty
        }

        It 'Boot log (ciem.log) has zero FAILED entries from last import' {
            $logPath = Join-Path $script:ModuleRoot 'data' 'ciem.log'
            $logPath | Should -Exist
            $content = Get-Content $logPath -Tail 50
            # Find the last "Module loading from:" line — that's the start of the most recent import
            $lastLoadIdx = ($content.Count - 1)..0 | Where-Object { $content[$_] -match 'Module loading from:' } | Select-Object -First 1
            $lastLoadIdx | Should -Not -BeNullOrEmpty
            $recentLines = $content[$lastLoadIdx..($content.Count - 1)]
            $recentLines | Where-Object { $_ -cmatch '\[ERROR\].*\bFAILED\b' } | Should -BeNullOrEmpty
        }
    }

    Context 'New Discovery functions are exported' {
        It 'Get-CIEMAzureArmResource is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureArmResource -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'New-CIEMAzureArmResource is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name New-CIEMAzureArmResource -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Update-CIEMAzureArmResource is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Update-CIEMAzureArmResource -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureArmResource is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Save-CIEMAzureArmResource -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Remove-CIEMAzureArmResource is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Remove-CIEMAzureArmResource -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Get-CIEMAzureEntraResource is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureEntraResource -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'New-CIEMAzureEntraResource is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name New-CIEMAzureEntraResource -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Update-CIEMAzureEntraResource is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Update-CIEMAzureEntraResource -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureEntraResource is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Save-CIEMAzureEntraResource -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Remove-CIEMAzureEntraResource is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Remove-CIEMAzureEntraResource -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Get-CIEMAzureDiscoveryRun is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureDiscoveryRun -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'New-CIEMAzureDiscoveryRun is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name New-CIEMAzureDiscoveryRun -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Update-CIEMAzureDiscoveryRun is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Update-CIEMAzureDiscoveryRun -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureDiscoveryRun is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Save-CIEMAzureDiscoveryRun -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Remove-CIEMAzureDiscoveryRun is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Remove-CIEMAzureDiscoveryRun -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Get-CIEMAzureResourceType is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureResourceType -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Get-CIEMAzureResourceRelationship is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureResourceRelationship -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'New-CIEMAzureResourceRelationship is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name New-CIEMAzureResourceRelationship -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Update-CIEMAzureResourceRelationship is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Update-CIEMAzureResourceRelationship -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Save-CIEMAzureResourceRelationship is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Save-CIEMAzureResourceRelationship -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Remove-CIEMAzureResourceRelationship is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Remove-CIEMAzureResourceRelationship -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Start-CIEMAzureDiscovery is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Start-CIEMAzureDiscovery -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Old functions are NOT exported' {
        It 'Module does not expose Invoke-CIEMIdentityGraphBuild' {
            Get-Command -Module Devolutions.CIEM -Name Invoke-CIEMIdentityGraphBuild -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose New-CIEMGraph' {
            Get-Command -Module Devolutions.CIEM -Name New-CIEMGraph -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Get-CIEMAzureEntraData' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureEntraData -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Save-CIEMAzureEntraData' {
            Get-Command -Module Devolutions.CIEM -Name Save-CIEMAzureEntraData -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Get-CIEMAzureIAMData' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureIAMData -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Save-CIEMAzureIAMData' {
            Get-Command -Module Devolutions.CIEM -Name Save-CIEMAzureIAMData -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Save-CIEMCollectedData' {
            Get-Command -Module Devolutions.CIEM -Name Save-CIEMCollectedData -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Get-CIEMCollectedData' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMCollectedData -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Test-CIEMCollectedDataExists' {
            Get-Command -Module Devolutions.CIEM -Name Test-CIEMCollectedDataExists -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Get-CIEMAzureServiceData' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureServiceData -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Save-CIEMAzureServiceData' {
            Get-Command -Module Devolutions.CIEM -Name Save-CIEMAzureServiceData -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Remove-CIEMAzureServiceData' {
            Get-Command -Module Devolutions.CIEM -Name Remove-CIEMAzureServiceData -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Get-CIEMGraphSummary' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMGraphSummary -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }

        It 'Module does not expose Get-CIEMAzureResourceTypeEntity' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMAzureResourceTypeEntity -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        }
    }

    Context 'Old directories are deleted' {
        It 'psu-app/modules/Devolutions.CIEM.Identities/ does not exist' {
            Join-Path $script:ModuleRoot 'modules' 'Devolutions.CIEM.Identities' | Should -Not -Exist
        }

        It 'psu-app/modules/Azure/Permissions/ does not exist' {
            Join-Path $script:ModuleRoot 'modules' 'Azure' 'Permissions' | Should -Not -Exist
        }
    }

    Context 'Old class files are deleted' {
        It 'psu-app/Classes/CIEMIdentity.ps1 does not exist' {
            Join-Path $script:ModuleRoot 'Classes' 'CIEMIdentity.ps1' | Should -Not -Exist
        }

        It 'psu-app/Classes/CIEMResourceType.ps1 does not exist' {
            Join-Path $script:ModuleRoot 'Classes' 'CIEMResourceType.ps1' | Should -Not -Exist
        }
    }

    Context 'Old Infrastructure CRUD files are deleted' {
        It 'CIEMAzureResource.ps1 class does not exist in Infrastructure/Classes' {
            Join-Path $script:ModuleRoot 'modules' 'Azure' 'Infrastructure' 'Classes' 'CIEMAzureResource.ps1' | Should -Not -Exist
        }

        It 'CIEMAzureResourceProperty.ps1 class does not exist' {
            Join-Path $script:ModuleRoot 'modules' 'Azure' 'Infrastructure' 'Classes' 'CIEMAzureResourceProperty.ps1' | Should -Not -Exist
        }

        It 'CIEMAzureResourceRelationship.ps1 class does not exist in Infrastructure/Classes' {
            Join-Path $script:ModuleRoot 'modules' 'Azure' 'Infrastructure' 'Classes' 'CIEMAzureResourceRelationship.ps1' | Should -Not -Exist
        }

        It 'CIEMAzureServiceData.ps1 class does not exist' {
            Join-Path $script:ModuleRoot 'modules' 'Azure' 'Infrastructure' 'Classes' 'CIEMAzureServiceData.ps1' | Should -Not -Exist
        }

        It 'CIEMAzureResourceTypeEntity.ps1 class does not exist' {
            Join-Path $script:ModuleRoot 'modules' 'Azure' 'Infrastructure' 'Classes' 'CIEMAzureResourceTypeEntity.ps1' | Should -Not -Exist
        }
    }

    Context 'File moves completed' {
        It 'Test-EntraAuthorizationPolicyBooleanSetting.ps1 exists in Checks/Private' {
            Join-Path $script:ModuleRoot 'modules' 'Devolutions.CIEM.Checks' 'Private' 'Test-EntraAuthorizationPolicyBooleanSetting.ps1' | Should -Exist
        }
    }
}
