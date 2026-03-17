BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    $script:ModuleRoot = Join-Path $PSScriptRoot '..' '..'
}

Describe 'PSU Integration Changes' {

    Context 'CIEMProvider class has no IsDefault' {
        It 'CIEMProvider does not have an IsDefault property' {
            $provider = InModuleScope Devolutions.CIEM { [CIEMProvider]::new() }
            $provider.PSObject.Properties.Name | Should -Not -Contain 'IsDefault'
        }

        It 'CIEMProvider has Name, Enabled, Endpoints, ResourceFilter properties' {
            $provider = InModuleScope Devolutions.CIEM { [CIEMProvider]::new() }
            $props = $provider.PSObject.Properties.Name
            $props | Should -Contain 'Name'
            $props | Should -Contain 'Enabled'
            $props | Should -Contain 'Endpoints'
            $props | Should -Contain 'ResourceFilter'
        }
    }

    Context 'PSU scripts.ps1 registration' {
        BeforeAll {
            $script:ScriptsContent = Get-Content (Join-Path $script:ModuleRoot '.universal' 'scripts.ps1') -Raw
        }

        It 'Contains Start-CIEMAzureDiscovery registration' {
            $script:ScriptsContent | Should -Match 'Start-CIEMAzureDiscovery'
        }

        It 'Contains New-CIEMScanRun registration' {
            $script:ScriptsContent | Should -Match 'New-CIEMScanRun'
        }

    }
}
