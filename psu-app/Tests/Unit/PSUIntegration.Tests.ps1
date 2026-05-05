BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
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

    Context 'PSU script registration' {
        BeforeAll {
            $script:ScriptsPath = Join-Path $script:ModuleRoot '.universal' 'scripts.ps1'
            $script:InitializePath = Join-Path $script:ModuleRoot '.universal' 'initialize.ps1'
            $script:AuthenticationPath = Join-Path $script:ModuleRoot '.universal' 'authentication.ps1'
            $script:RolesPath = Join-Path $script:ModuleRoot '.universal' 'roles.ps1'
            $script:SettingsPath = Join-Path $script:ModuleRoot '.universal' 'settings.ps1'
            $script:AppContent = Get-Content (Join-Path $script:ModuleRoot 'modules' 'Devolutions.CIEM.PSU' 'Public' 'New-DevolutionsCIEMApp.ps1') -Raw
        }

        It 'Does not ship scripts.ps1 as a read-only module resource' {
            $script:ScriptsPath | Should -Not -Exist
        }

        It 'Does not register PSU scripts from the app startup path' {
            $script:AppContent | Should -Not -Match 'Import-CIEMScript'
        }

        It 'runs automatic CIEM setup from the PSU initialize hook' {
            $script:InitializePath | Should -Exist
            Get-Content -Path $script:InitializePath -Raw | Should -Match 'Initialize-CIEMPSUInstance\s+-Integrated'
        }

        It 'does not ship dev-only global PSU authentication, role, or setting resources' {
            $script:AuthenticationPath | Should -Not -Exist
            $script:RolesPath | Should -Not -Exist
            $script:SettingsPath | Should -Not -Exist
        }

    }
}
