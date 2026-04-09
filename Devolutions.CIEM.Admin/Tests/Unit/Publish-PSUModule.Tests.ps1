BeforeAll {
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

    Context 'when rsync push succeeds and Restart-PSUApp fails' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { [PSCustomObject]@{ Url = 'https://mocked'; Status = 'Connected' } }
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { $null }
            Mock -ModuleName Devolutions.CIEM.Admin ssh { '' } -ParameterFilter { $args -match 'ls' }
            Mock -ModuleName Devolutions.CIEM.Admin ssh {} -ParameterFilter { $args -match 'rm -rf' }
            Mock -ModuleName Devolutions.CIEM.Admin rsync { $global:LASTEXITCODE = 0 }
            Mock -ModuleName Devolutions.CIEM.Admin Restart-PSUApp { throw 'Mocked restart failure: PSU connection stale' }
        }

        It 'rethrows the Restart-PSUApp failure instead of emitting a warning' {
            { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -EnvFilePath $script:envFile -Confirm:$false } |
                Should -Throw -ExpectedMessage '*Mocked restart failure*'
        }

        It 'invokes Restart-PSUApp with the CIEM app name' {
            try { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -EnvFilePath $script:envFile -Confirm:$false } catch {}
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Restart-PSUApp -Times 1 -ParameterFilter { $Name -eq 'Devolutions CIEM' }
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
            Mock -ModuleName Devolutions.CIEM.Admin Restart-PSUApp {}
        }

        It 'throws on rsync failure' {
            { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -EnvFilePath $script:envFile -Confirm:$false } |
                Should -Throw -ExpectedMessage '*rsync*failed*'
        }
    }
}

Describe 'Publish-PSUModule -> PSGallery + PSU update (remote path)' {
    BeforeAll {
        $script:remoteSrcDir = Join-Path $TestDrive 'remote-psu-app'
        New-Item -Path $script:remoteSrcDir -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:remoteSrcDir '.universal') -ItemType Directory -Force | Out-Null

        New-ModuleManifest `
            -Path (Join-Path $script:remoteSrcDir 'Devolutions.CIEM.psd1') `
            -ModuleVersion '0.0.1' `
            -RootModule 'Devolutions.CIEM.psm1'
        Set-Content -Path (Join-Path $script:remoteSrcDir 'Devolutions.CIEM.psm1') -Value ''
        Set-Content `
            -Path (Join-Path $script:remoteSrcDir '.universal/dashboards.ps1') `
            -Value "New-PSUApp -Name 'Devolutions CIEM' -BaseUrl '/ciem'"
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
            Mock -ModuleName Devolutions.CIEM.Admin Restart-PSUApp {}
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
            }

            Mock -ModuleName Devolutions.CIEM.Admin Find-Module {
                [PSCustomObject]@{ Version = '0.0.2' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {}
            Mock -ModuleName Devolutions.CIEM.Admin Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule { throw 'Mocked install failure: PSU rejected module upload' }
            Mock -ModuleName Devolutions.CIEM.Admin Restart-PSUApp {}
        }

        It 'rethrows the Install-PSUModule failure instead of writing an [ERROR] line and returning Published' {
            {
                Publish-PSUModule -ModulePath $script:remoteSrcDir `
                    -NuGetApiKey 'fake-key' `
                    -EnvFilePath 'NO_ENV_FILE' `
                    -Confirm:$false
            } | Should -Throw -ExpectedMessage '*Mocked install failure*'
        }

        It 'never calls Restart-PSUApp when Install-PSUModule fails' {
            try {
                Publish-PSUModule -ModulePath $script:remoteSrcDir `
                    -NuGetApiKey 'fake-key' `
                    -EnvFilePath 'NO_ENV_FILE' `
                    -Confirm:$false
            } catch {}
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Restart-PSUApp -Times 0 -Scope It
        }
    }

    Context 'when Restart-PSUApp fails after a successful Install-PSUModule' {
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
            Mock -ModuleName Devolutions.CIEM.Admin Restart-PSUApp { throw 'Mocked restart failure: remote PSU restart denied' }
        }

        It 'rethrows the Restart-PSUApp failure instead of emitting a warning' {
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
}
