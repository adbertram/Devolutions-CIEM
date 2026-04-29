BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $manifest = Join-Path $moduleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $manifest
}

Describe 'CIEM admin runtime target registry' {
    It 'resolves the local PSU target from registry variables' {
        $envFile = Join-Path $TestDrive '.env.local'
        Set-Content -Path $envFile -Value @'
LOCAL_PSU_URL=http://192.168.86.36:5001/
LOCAL_PSU_TOKEN=local-token
'@

        $target = InModuleScope Devolutions.CIEM.Admin -Parameters @{ EnvFile = $envFile } {
            GetCIEMRuntimeTarget -Name local -EnvFilePath $EnvFile
        }

        $target.Name | Should -Be 'local'
        $target.Url | Should -Be 'http://192.168.86.36:5001'
        $target.Token | Should -Be 'local-token'
        $target.IsAzure | Should -BeFalse
        $target.UrlVariable | Should -Be 'LOCAL_PSU_URL'
        $target.TokenVariable | Should -Be 'LOCAL_PSU_TOKEN'
        $target.UsesPublishPoint | Should -BeTrue
    }

    It 'resolves the Azure PSU target with default resource group and web app name' {
        $envFile = Join-Path $TestDrive '.env.azure'
        Set-Content -Path $envFile -Value @'
AZURE_PSU_URL=https://devolutions-ciem-psu.azurewebsites.net/
AZURE_PSU_TOKEN=azure-token
'@

        $target = InModuleScope Devolutions.CIEM.Admin -Parameters @{ EnvFile = $envFile } {
            GetCIEMRuntimeTarget -Name azure -EnvFilePath $EnvFile
        }

        $target.Name | Should -Be 'azure'
        $target.Url | Should -Be 'https://devolutions-ciem-psu.azurewebsites.net'
        $target.Token | Should -Be 'azure-token'
        $target.IsAzure | Should -BeTrue
        $target.ResourceGroup | Should -Be 'devolutions-ciem-rg'
        $target.WebAppName | Should -Be 'devolutions-ciem-psu'
        $target.UrlVariable | Should -Be 'AZURE_PSU_URL'
        $target.TokenVariable | Should -Be 'AZURE_PSU_TOKEN'
        $target.UsesPublishPoint | Should -BeFalse
    }

    It 'throws a target-specific error when the URL variable is missing' {
        $envFile = Join-Path $TestDrive '.env-missing-url'
        Set-Content -Path $envFile -Value 'LOCAL_PSU_TOKEN=local-token'

        {
            InModuleScope Devolutions.CIEM.Admin -Parameters @{ EnvFile = $envFile } {
                GetCIEMRuntimeTarget -Name local -EnvFilePath $EnvFile
            }
        } | Should -Throw -ExpectedMessage '*LOCAL_PSU_URL*'
    }

    It 'rejects unsupported target names' {
        {
            InModuleScope Devolutions.CIEM.Admin {
                GetCIEMRuntimeTarget -Name staging -EnvFilePath 'NO_ENV_FILE'
            }
        } | Should -Throw -ExpectedMessage "*Unsupported CIEM runtime target 'staging'*"
    }
}
