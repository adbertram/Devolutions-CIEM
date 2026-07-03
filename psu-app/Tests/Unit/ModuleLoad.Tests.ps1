BeforeAll {
    if (Get-Module Devolutions.CIEM) {
        Remove-Module Devolutions.CIEM -Force
    }
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' '..'
}

Describe 'Module Load — Post-Discovery-Schema' {

    Context 'Module imports without errors' {
        It 'Imports Devolutions.CIEM without throwing' {
            Get-Module Devolutions.CIEM | Should -Not -BeNullOrEmpty
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

    Context 'Report functions are exported' {
        It 'Get-CIEMReport is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMReport -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Invoke-CIEMReport is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Invoke-CIEMReport -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'GetCIEMEnvironmentalProgressReportData remains private' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'GetCIEMEnvironmentalProgressReportData'
        }
    }

    Context 'Validation helpers are exported' {
        It 'Use-CIEMTemporaryDatabase is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Use-CIEMTemporaryDatabase -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Check functions are exported' {
        It 'Get-CIEMCheck is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMCheck -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'New-CIEMCheck is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name New-CIEMCheck -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Update-CIEMCheck is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Update-CIEMCheck -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Get-CIEMCheckMetadata is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMCheckMetadata -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Get-CIEMRequiredPermission is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMRequiredPermission -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Devolutions.CIEM\Get-CIEMCheck resolves via module-qualified call' {
            { Devolutions.CIEM\Get-CIEMCheck } | Should -Not -Throw
        }
    }

    Context 'Old functions are NOT exported' {
        It 'Module does not expose Get-CIEMAzureEntraData' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Get-CIEMAzureEntraData'
        }

        It 'Module does not expose Save-CIEMAzureEntraData' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Save-CIEMAzureEntraData'
        }

        It 'Module does not expose Get-CIEMAzureIAMData' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Get-CIEMAzureIAMData'
        }

        It 'Module does not expose Save-CIEMAzureIAMData' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Save-CIEMAzureIAMData'
        }

        It 'Module does not expose Save-CIEMCollectedData' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Save-CIEMCollectedData'
        }

        It 'Module does not expose Get-CIEMCollectedData' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Get-CIEMCollectedData'
        }

        It 'Module does not expose Test-CIEMCollectedDataExists' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Test-CIEMCollectedDataExists'
        }

        It 'Module does not expose Get-CIEMAzureServiceData' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Get-CIEMAzureServiceData'
        }

        It 'Module does not expose Save-CIEMAzureServiceData' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Save-CIEMAzureServiceData'
        }

        It 'Module does not expose Remove-CIEMAzureServiceData' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Remove-CIEMAzureServiceData'
        }

        It 'Module does not expose Get-CIEMAzureResourceTypeEntity' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Get-CIEMAzureResourceTypeEntity'
        }

        It 'Module does not expose Get-CIEMAzureDiscoveryCoverageReport' {
            (Get-Module Devolutions.CIEM).ExportedCommands.Keys | Should -Not -Contain 'Get-CIEMAzureDiscoveryCoverageReport'
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
        It 'TestEntraAuthorizationPolicyBooleanSetting.ps1 exists in Checks/Private' {
            Join-Path $script:ModuleRoot 'modules' 'Devolutions.CIEM.Checks' 'Private' 'TestEntraAuthorizationPolicyBooleanSetting.ps1' | Should -Exist
        }
    }
}
