BeforeAll {
    if (-not (Get-Module -Name Universal)) {
        New-Module -Name Universal -ScriptBlock {
            function Start-PSUApp { param([string]$Name) }
            function Stop-PSUApp { param([string]$Name) }
            function Sync-PSUConfiguration { param([switch]$Reset) }
        } | Import-Module
    }

    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $manifest = Join-Path $moduleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $manifest
}

Describe 'Publish-PSUModule -LocalOnly' {
    BeforeAll {
        # Build a minimal fake project layout:
        #   $TestDrive/
        #     psu-app/                       <-- $ModulePath
        #       Devolutions.CIEM.psd1
        #       Devolutions.CIEM.psm1
        #       .universal/dashboards.ps1
        #     .env                           <-- publish point config
        $script:srcDir = Join-Path $TestDrive 'psu-app'
        New-Item -Path $script:srcDir -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:srcDir '.universal') -ItemType Directory -Force | Out-Null

        New-ModuleManifest `
            -Path (Join-Path $script:srcDir 'Devolutions.CIEM.psd1') `
            -ModuleVersion '0.0.1' `
            -RootModule 'Devolutions.CIEM.psm1'
        Set-Content -Path (Join-Path $script:srcDir 'Devolutions.CIEM.psm1') -Value ''
        Set-Content `
            -Path (Join-Path $script:srcDir '.universal/dashboards.ps1') `
            -Value "New-PSUApp -Name 'Devolutions CIEM' -BaseUrl '/ciem'"

        # .env with publish point config
        $script:envFile = Join-Path $TestDrive '.env'
        Set-Content -Path $script:envFile -Value @'
PUBLISH_POINT_SSH=adam-server
PUBLISH_POINT_PSU_PATH=/Users/adam/psu
LOCAL_PSU_URL=http://192.168.86.30:5001
LOCAL_PSU_TOKEN=fake-token
'@
    }

    Context 'when rsync push succeeds and native app restart fails' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { [PSCustomObject]@{ Url = 'https://mocked'; Status = 'Connected' } }
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { $null }
            Mock -ModuleName Devolutions.CIEM.Admin ssh { '' } -ParameterFilter { $args -match 'ls' }
            Mock -ModuleName Devolutions.CIEM.Admin ssh {} -ParameterFilter { $args -match 'rm -rf' }
            Mock -ModuleName Devolutions.CIEM.Admin rsync {
                $script:rsyncArgs = @($args)
                $global:LASTEXITCODE = 0
            }
            Mock -ModuleName Devolutions.CIEM.Admin Sync-PSUConfiguration {}
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp { throw 'Mocked restart failure: PSU connection stale' }
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp {}
        }

        It 'rethrows the native restart failure instead of emitting a warning' {
            { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -EnvFilePath $script:envFile -Confirm:$false } |
                Should -Throw -ExpectedMessage '*Mocked restart failure*'
        }

        It 'invokes native Stop-PSUApp with the CIEM app name' {
            try { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -EnvFilePath $script:envFile -Confirm:$false } catch {}
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Stop-PSUApp -Times 1 -ParameterFilter { $Name -eq 'Devolutions CIEM' }
        }

        It 'excludes local test dependencies and Playwright artifacts from rsync' {
            try { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -EnvFilePath $script:envFile -Confirm:$false } catch {}

            $script:rsyncArgs | Should -Contain '--exclude=node_modules/'
            $script:rsyncArgs | Should -Contain '--exclude=playwright-report/'
            $script:rsyncArgs | Should -Contain '--exclude=test-results/'
            $script:rsyncArgs | Should -Contain '--exclude=*.log'
            $script:rsyncArgs | Should -Contain '--exclude=modules/Devolutions.CIEM.PSU/Data/icons/source-packs/'
            $script:rsyncArgs | Should -Contain '--exclude=Tests/'
            $script:rsyncArgs | Should -Contain '--exclude=ui/e2e/'
        }
    }

    Context 'when PUBLISH_POINT_SSH is missing from .env' {
        BeforeAll {
            $script:noSshEnv = Join-Path $TestDrive '.env-no-ssh'
            Set-Content -Path $script:noSshEnv -Value @'
PUBLISH_POINT_PSU_PATH=/Users/adam/psu
LOCAL_PSU_URL=http://192.168.86.30:5001
LOCAL_PSU_TOKEN=fake-token
'@
        }

        It 'throws requiring PUBLISH_POINT_SSH' {
            { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -EnvFilePath $script:noSshEnv -Confirm:$false } |
                Should -Throw -ExpectedMessage '*PUBLISH_POINT_SSH*'
        }
    }

    Context 'when rsync fails' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { [PSCustomObject]@{ Url = 'https://mocked'; Status = 'Connected' } }
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { $null }
            Mock -ModuleName Devolutions.CIEM.Admin ssh { '' }
            Mock -ModuleName Devolutions.CIEM.Admin rsync { $global:LASTEXITCODE = 1 }
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp {}
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp {}
        }

        It 'throws on rsync failure' {
            { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -EnvFilePath $script:envFile -Confirm:$false } |
                Should -Throw -ExpectedMessage '*rsync*failed*'
        }
    }

    Context 'when PowerShell Gallery version lookup fails' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { [PSCustomObject]@{ Url = 'https://mocked'; Status = 'Connected' } }
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { throw 'mock gallery unavailable' }
            Mock -ModuleName Devolutions.CIEM.Admin ssh { '' }
            Mock -ModuleName Devolutions.CIEM.Admin rsync { $global:LASTEXITCODE = 0 }
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp {}
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp {}
        }

        It 'throws instead of silently using only the local version baseline' {
            { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -EnvFilePath $script:envFile -Confirm:$false } |
                Should -Throw -ExpectedMessage '*mock gallery unavailable*'
        }
    }

    Context 'when the caller will create and restart the app after publishing' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { [PSCustomObject]@{ Url = 'https://mocked'; Status = 'Connected' } }
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { $null }
            Mock -ModuleName Devolutions.CIEM.Admin ssh { '' }
            Mock -ModuleName Devolutions.CIEM.Admin rsync { $global:LASTEXITCODE = 0 }
            Mock -ModuleName Devolutions.CIEM.Admin Sync-PSUConfiguration {}
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp { throw 'Stop-PSUApp should not run when -SkipAppRestart is set' }
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp { throw 'Start-PSUApp should not run when -SkipAppRestart is set' }
        }

        It 'skips the local app restart' {
            $result = Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -SkipAppRestart -EnvFilePath $script:envFile -Confirm:$false

            $result.Status | Should -Be 'LocalImport'
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Stop-PSUApp -Times 0 -Scope It
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Start-PSUApp -Times 0 -Scope It
        }

        It 'syncs PSU configuration after replacing local module files' {
            Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -SkipAppRestart -EnvFilePath $script:envFile -Confirm:$false | Out-Null

            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Sync-PSUConfiguration -Times 1 -Scope It -ParameterFilter { $Reset }
        }
    }
}

Describe 'Publish-PSUModule -> PSGallery + PSU update (remote path)' {
    BeforeAll {
        $script:remoteSrcDir = Join-Path $TestDrive 'remote-psu-app'
        New-Item -Path $script:remoteSrcDir -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:remoteSrcDir '.universal') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:remoteSrcDir 'modules/PSUSQLite') -ItemType Directory -Force | Out-Null

        New-ModuleManifest `
            -Path (Join-Path $script:remoteSrcDir 'Devolutions.CIEM.psd1') `
            -ModuleVersion '0.0.1' `
            -RootModule 'Devolutions.CIEM.psm1'
        Set-Content -Path (Join-Path $script:remoteSrcDir 'Devolutions.CIEM.psm1') -Value ''
        Set-Content `
            -Path (Join-Path $script:remoteSrcDir '.universal/dashboards.ps1') `
            -Value "New-PSUApp -Name 'Devolutions CIEM' -BaseUrl '/ciem'"
        Set-Content `
            -Path (Join-Path $script:remoteSrcDir 'setup.ps1') `
            -Value "Initialize-CIEMPSUInstance | Out-Null"
        Set-Content `
            -Path (Join-Path $script:remoteSrcDir '.universal/scripts.ps1') `
            -Value "Import-Module Devolutions.CIEM`nNew-PSUScript -Module 'Devolutions.CIEM' -Command 'New-CIEMScanRun'"
        New-ModuleManifest `
            -Path (Join-Path $script:remoteSrcDir 'modules/PSUSQLite/PSUSQLite.psd1') `
            -ModuleVersion '0.0.1' `
            -RootModule 'PSUSQLite.psm1'
        Set-Content -Path (Join-Path $script:remoteSrcDir 'modules/PSUSQLite/PSUSQLite.psm1') -Value ''
    }

    Context 'when auto-connect to PSU throws because PSUConnection.Url is empty' {
        BeforeAll {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = $null
                $script:PSUConnection.Token = $null
            }

            Mock -ModuleName Devolutions.CIEM.Admin Find-Module {
                [PSCustomObject]@{ Version = '0.0.2' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {}
            Mock -ModuleName Devolutions.CIEM.Admin Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { throw 'Mocked connect failure: AZURE_PSU_URL missing' }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule {}
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp {}
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp {}
        }

        It 'rethrows the Connect-PSU failure instead of warning and returning Published' {
            {
                Publish-PSUModule -ModulePath $script:remoteSrcDir `
                    -NuGetApiKey 'fake-key' `
                    -EnvFilePath 'NO_ENV_FILE' `
                    -Confirm:$false
            } | Should -Throw -ExpectedMessage '*Mocked connect failure*'
        }

        It 'never calls Install-PSUModule when auto-connect fails' {
            try {
                Publish-PSUModule -ModulePath $script:remoteSrcDir `
                    -NuGetApiKey 'fake-key' `
                    -EnvFilePath 'NO_ENV_FILE' `
                    -Confirm:$false
            } catch {}
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Install-PSUModule -Times 0 -Scope It
        }
    }

    Context 'when Install-PSUModule fails after a successful publish' {
        BeforeAll {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'https://fake.psu'
                $script:PSUConnection.Token = 'fake-token'
                $script:PSUConnection.IsAzure = $false
            }

            Mock -ModuleName Devolutions.CIEM.Admin Find-Module {
                [PSCustomObject]@{ Version = '0.0.2' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {}
            Mock -ModuleName Devolutions.CIEM.Admin Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule { throw 'Mocked install failure: PSU rejected module upload' }
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp {}
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp {}
        }

        It 'rethrows the Install-PSUModule failure instead of writing an [ERROR] line and returning Published' {
            {
                Publish-PSUModule -ModulePath $script:remoteSrcDir `
                    -NuGetApiKey 'fake-key' `
                    -EnvFilePath 'NO_ENV_FILE' `
                    -Confirm:$false
            } | Should -Throw -ExpectedMessage '*Mocked install failure*'
        }

        It 'never calls native Stop-PSUApp when Install-PSUModule fails' {
            try {
                Publish-PSUModule -ModulePath $script:remoteSrcDir `
                    -NuGetApiKey 'fake-key' `
                    -EnvFilePath 'NO_ENV_FILE' `
                    -Confirm:$false
            } catch {}
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Stop-PSUApp -Times 0 -Scope It
        }
    }

    Context 'when native app restart fails after a successful Install-PSUModule' {
        BeforeAll {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'https://fake.psu'
                $script:PSUConnection.Token = 'fake-token'
            }

            Mock -ModuleName Devolutions.CIEM.Admin Find-Module {
                [PSCustomObject]@{ Version = '0.0.2' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {}
            Mock -ModuleName Devolutions.CIEM.Admin Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule {}
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp { throw 'Mocked restart failure: remote PSU restart denied' }
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp {}
        }

        It 'rethrows the native app restart failure instead of emitting a warning' {
            {
                Publish-PSUModule -ModulePath $script:remoteSrcDir `
                    -NuGetApiKey 'fake-key' `
                    -EnvFilePath 'NO_ENV_FILE' `
                    -Confirm:$false
            } | Should -Throw -ExpectedMessage '*Mocked restart failure: remote PSU restart denied*'
        }

        It 'still invoked Install-PSUModule once before the restart failed' {
            try {
                Publish-PSUModule -ModulePath $script:remoteSrcDir `
                    -NuGetApiKey 'fake-key' `
                    -EnvFilePath 'NO_ENV_FILE' `
                    -Confirm:$false
            } catch {}
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Install-PSUModule -Times 1 -Scope It
        }
    }

    Context 'when the caller will create and restart the app after remote import' {
        BeforeAll {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'https://fake.psu'
                $script:PSUConnection.Token = 'fake-token'
            }

            $script:installCalls = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module {
                [PSCustomObject]@{ Version = '0.0.2' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {}
            Mock -ModuleName Devolutions.CIEM.Admin Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule {
                $script:installCalls.Add([pscustomobject]@{
                        Name       = $Name
                        Version    = $Version
                        Repository = $Repository
                        NoSync     = [bool]$NoSync
                    })
            }
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp { throw 'Stop-PSUApp should not run when -SkipAppRestart is set' }
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp { throw 'Start-PSUApp should not run when -SkipAppRestart is set' }
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod { throw 'Health check should not run when -SkipAppRestart is set' }
        }

        It 'skips remote app restart and health check after importing the module' {
            $result = Publish-PSUModule -ModulePath $script:remoteSrcDir `
                -NuGetApiKey 'fake-key' `
                -EnvFilePath 'NO_ENV_FILE' `
                -SkipAppRestart `
                -Confirm:$false

            $result.Status | Should -Be 'Published'
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Install-PSUModule -Times 1 -Scope It
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Stop-PSUApp -Times 0 -Scope It
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Start-PSUApp -Times 0 -Scope It
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Invoke-RestMethod -Times 0 -Scope It
        }

        It 'imports the Gallery module with configuration sync enabled so PSU loads CIEM resources' {
            Publish-PSUModule -ModulePath $script:remoteSrcDir `
                -NuGetApiKey 'fake-key' `
                -EnvFilePath 'NO_ENV_FILE' `
                -SkipAppRestart `
                -Confirm:$false | Out-Null

            $installCall = $script:installCalls[-1]
            $installCall.Name | Should -Be 'Devolutions.CIEM'
            $installCall.NoSync | Should -BeFalse
        }
    }

    Context 'when installing the existing published Gallery version' {
        BeforeAll {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'https://fake.psu'
                $script:PSUConnection.Token = 'fake-token'
            }

            $script:installCalls = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { throw 'Find-Module should not run when installing the existing published version' }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource { throw 'Publish-PSResource should not run when installing the existing published version' }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule {
                $script:installCalls.Add([pscustomobject]@{
                        Name    = $Name
                        Version = $Version
                    })
                [pscustomobject]@{
                    Name       = $Name
                    Version    = '0.4.12'
                    Repository = 'PSGallery'
                    Status     = 'Installed'
                }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp { throw 'Stop-PSUApp should not run when -SkipAppRestart is set' }
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp { throw 'Start-PSUApp should not run when -SkipAppRestart is set' }
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod { throw 'Health check should not run when -SkipAppRestart is set' }
        }

        It 'imports the latest version PSU finds in PowerShell Gallery without publishing or requiring a NuGet API key' {
            $result = Publish-PSUModule -ModulePath $script:remoteSrcDir `
                -InstallPublishedVersion `
                -EnvFilePath 'NO_ENV_FILE' `
                -SkipAppRestart `
                -Confirm:$false

            $result.Status | Should -Be 'InstalledPublishedVersion'
            $result.Version | Should -Be '0.4.12'
            $script:installCalls.Count | Should -Be 1
            $script:installCalls[0].Name | Should -Be 'Devolutions.CIEM'
            $script:installCalls[0].Version | Should -BeNullOrEmpty
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Publish-PSResource -Times 0 -Scope It
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Find-Module -Times 0 -Scope It
        }

        It 'rejects LocalOnly because the existing Gallery install path requires a connected PSU target' {
            {
                Publish-PSUModule -ModulePath $script:remoteSrcDir `
                    -LocalOnly `
                    -InstallPublishedVersion `
                    -EnvFilePath 'NO_ENV_FILE' `
                    -Confirm:$false
            } | Should -Throw -ExpectedMessage '*LocalOnly*InstallPublishedVersion*'
        }
    }

    Context 'when the caller wants CIEM deployment validation after remote import' {
        BeforeAll {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'https://fake.psu'
                $script:PSUConnection.Token = 'fake-token'
            }

            $script:events = [System.Collections.Generic.List[string]]::new()
            $script:testDeploymentCalls = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module {
                [PSCustomObject]@{ Version = '0.0.2' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {}
            Mock -ModuleName Devolutions.CIEM.Admin Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule {
                $script:events.Add('install')
            }
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-TestCommand {
                $script:events.Add('register')
                [pscustomobject]@{ Status = 'Completed' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp { $script:events.Add('stop') }
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp { $script:events.Add('start') }
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
                [pscustomobject]@{ loading = $false; hasError = $false; loadingInfo = '' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Test-CIEMPSUDeployment {
                $script:events.Add('validate')
                $script:testDeploymentCalls.Add([pscustomobject]@{
                        Environment = $Environment
                        EnvFilePath = $EnvFilePath
                    })
                [pscustomobject]@{ Status = 'Healthy' }
            }
        }

        It 'publishes and validates the PSU-registered module state without deployment-only setup or restart steps' {
            $result = Publish-PSUModule -ModulePath $script:remoteSrcDir `
                -NuGetApiKey 'fake-key' `
                -EnvFilePath '/tmp/custom-ciem.env' `
                -BumpVersion Minor `
                -ValidateDeployment `
                -Confirm:$false

            $result.Status | Should -Be 'Deployed'
            $result.PublishResult.Status | Should -Be 'Published'
            $result.ValidationResult.Status | Should -Be 'Healthy'
            $result.PSObject.Properties.Name | Should -Not -Contain 'BootstrapResult'
            $result.PSObject.Properties.Name | Should -Not -Contain 'ScriptRegistration'
            $script:events | Should -Be @('install', 'validate')
            $script:testDeploymentCalls[0].Environment | Should -Be 'local'
            $script:testDeploymentCalls[0].EnvFilePath | Should -Be '/tmp/custom-ciem.env'
        }

        It 'does not return bootstrap or script registration job details from validation' {
            $result = Publish-PSUModule -ModulePath $script:remoteSrcDir `
                -NuGetApiKey 'fake-key' `
                -EnvFilePath 'NO_ENV_FILE' `
                -ValidateDeployment `
                -Confirm:$false

            $result.PSObject.Properties.Name | Should -Not -Contain 'BootstrapResult'
            $result.PSObject.Properties.Name | Should -Not -Contain 'ScriptRegistration'
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Invoke-TestCommand -Times 0 -Scope It
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Stop-PSUApp -Times 0 -Scope It
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Start-PSUApp -Times 0 -Scope It
        }
    }

    Context 'when CIEM deployment validation fails after local import' {
        BeforeAll {
            $script:localValidateSrcDir = Join-Path $TestDrive 'local-validate-psu-app'
            New-Item -Path $script:localValidateSrcDir -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:localValidateSrcDir '.universal') -ItemType Directory -Force | Out-Null
            New-ModuleManifest `
                -Path (Join-Path $script:localValidateSrcDir 'Devolutions.CIEM.psd1') `
                -ModuleVersion '0.0.1' `
                -RootModule 'Devolutions.CIEM.psm1'
            Set-Content -Path (Join-Path $script:localValidateSrcDir 'Devolutions.CIEM.psm1') -Value ''
            Set-Content `
                -Path (Join-Path $script:localValidateSrcDir '.universal/dashboards.ps1') `
                -Value "New-PSUApp -Name 'Devolutions CIEM' -BaseUrl '/ciem'"
            $script:localValidateEnvFile = Join-Path $TestDrive '.env-local-validate'
            Set-Content -Path $script:localValidateEnvFile -Value @'
PUBLISH_POINT_SSH=adam-server
PUBLISH_POINT_PSU_PATH=/Users/adam/psu
LOCAL_PSU_URL=http://192.168.86.30:5001
LOCAL_PSU_TOKEN=fake-token
'@

            $script:events = [System.Collections.Generic.List[string]]::new()
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { [PSCustomObject]@{ Url = 'https://mocked'; Status = 'Connected' } }
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { $null }
            Mock -ModuleName Devolutions.CIEM.Admin ssh { '' }
            Mock -ModuleName Devolutions.CIEM.Admin rsync { $global:LASTEXITCODE = 0 }
            Mock -ModuleName Devolutions.CIEM.Admin Sync-PSUConfiguration { $script:events.Add('sync') }
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-TestCommand {
                $script:events.Add('register')
                [pscustomobject]@{ Status = 'Completed' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUApp { $script:events.Add('stop') }
            Mock -ModuleName Devolutions.CIEM.Admin Start-PSUApp { $script:events.Add('start') }
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
                [pscustomobject]@{ loading = $false; hasError = $false; loadingInfo = '' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Test-CIEMPSUDeployment {
                $script:events.Add('validate')
                throw 'CIEM deployment validation failed: CIEM database is not initialized on local.'
            }
        }

        It 'throws after validating the installed module state without deployment-only setup or restart steps' {
            { Publish-PSUModule -ModulePath $script:localValidateSrcDir -LocalOnly -ValidateDeployment -EnvFilePath $script:localValidateEnvFile -Confirm:$false } |
                Should -Throw -ExpectedMessage '*CIEM database is not initialized*'

            $script:events | Should -Be @('sync', 'validate')
        }
    }
}
