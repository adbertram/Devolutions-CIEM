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
            $script:DashboardsPath = Join-Path $script:ModuleRoot '.universal' 'dashboards.ps1'
            $script:ScriptsPath = Join-Path $script:ModuleRoot '.universal' 'scripts.ps1'
            $script:InitializePath = Join-Path $script:ModuleRoot '.universal' 'initialize.ps1'
            $script:SetupPath = Join-Path $script:ModuleRoot 'setup.ps1'
            $script:AuthenticationPath = Join-Path $script:ModuleRoot '.universal' 'authentication.ps1'
            $script:RolesPath = Join-Path $script:ModuleRoot '.universal' 'roles.ps1'
            $script:SettingsPath = Join-Path $script:ModuleRoot '.universal' 'settings.ps1'
            $script:DashboardsContent = Get-Content -Path $script:DashboardsPath -Raw
            $script:AppContent = Get-Content (Join-Path $script:ModuleRoot 'modules' 'Devolutions.CIEM.PSU' 'Public' 'New-DevolutionsCIEMApp.ps1') -Raw
        }

        It 'Registers the CIEM app as authenticated for PSU users and administrators' {
            $script:DashboardsPath | Should -Exist
            $script:DashboardsContent | Should -Match "New-PSUApp[\s\S]*-Name\s+'Devolutions CIEM'"
            $script:DashboardsContent | Should -Match "New-PSUApp[\s\S]*-Authenticated"
            $script:DashboardsContent | Should -Match "New-PSUApp[\s\S]*-Role\s+@\('User',\s*'Administrator'\)"
        }

        It 'Ships scripts.ps1 as the install-time module resource for core CIEM commands' {
            $script:ScriptsPath | Should -Exist
            $content = Get-Content -Path $script:ScriptsPath -Raw
            $content | Should -Match 'Import-Module\s+Devolutions\.CIEM'
            $content | Should -Not -Match 'Initialize-CIEMPSUInstance'
            $content | Should -Match 'New-PSUScript'
            $content | Should -Match "-Module\s+'Devolutions\.CIEM'"
            $content | Should -Match "-Command\s+'New-CIEMScanRun'"
            $content | Should -Match "-Command\s+'Start-CIEMAzureDiscovery'"
            $content | Should -Match "-Command\s+'Invoke-CIEMAttackPathRemediation'"
            $content | Should -Not -Match 'ScriptBlock'
            $content | Should -Not -Match 'Get-CIEMPSUScriptDefinition'
            $content | Should -Match 'ManagedBy=Devolutions\.CIEM;Source=data/psu-scripts\.json'
        }

        It 'Does not register PSU scripts from the app startup path' {
            $script:AppContent | Should -Not -Match 'Import-CIEMScript'
        }

        It 'runs automatic CIEM setup from the module import setup script' {
            $script:SetupPath | Should -Exist
            $setupContent = Get-Content -Path $script:SetupPath -Raw
            $setupContent | Should -Match 'function\s+Invoke-CIEMPSUSetup'
            $setupContent | Should -Match 'Invoke-CIEMPSUSetup\s+\|\s+Out-Null'
            $setupContent | Should -Match 'New-CIEMDatabase\s+-PassThru'
            $script:InitializePath | Should -Not -Exist
        }

        It 'does not ship dev-only global PSU authentication, role, or setting resources' {
            $script:AuthenticationPath | Should -Not -Exist
            $script:RolesPath | Should -Not -Exist
            $script:SettingsPath | Should -Not -Exist
        }

    }
}
