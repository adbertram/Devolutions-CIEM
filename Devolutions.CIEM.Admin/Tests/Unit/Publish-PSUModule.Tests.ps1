BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $manifest = Join-Path $moduleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $manifest
}

Describe 'Publish-PSUModule -LocalOnly' {
    Context 'when Restart-PSUApp fails after the module is copied to local PSU' {
        BeforeAll {
            # Build a minimal fake project layout that Publish-PSUModule can consume:
            #   $TestDrive/
            #     psu-app/                       <-- $ModulePath
            #       Devolutions.CIEM.psd1
            #       Devolutions.CIEM.psm1
            #       .universal/dashboards.ps1
            #     local-psu/Repository/Modules/  <-- target install dir
            $script:srcDir = Join-Path $TestDrive 'psu-app'
            $script:targetDir = Join-Path $TestDrive 'local-psu/Repository/Modules'
            New-Item -Path $script:srcDir -ItemType Directory -Force | Out-Null
            New-Item -Path $script:targetDir -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $script:srcDir '.universal') -ItemType Directory -Force | Out-Null

            New-ModuleManifest `
                -Path (Join-Path $script:srcDir 'Devolutions.CIEM.psd1') `
                -ModuleVersion '0.0.1' `
                -RootModule 'Devolutions.CIEM.psm1'
            Set-Content -Path (Join-Path $script:srcDir 'Devolutions.CIEM.psm1') -Value ''
            Set-Content `
                -Path (Join-Path $script:srcDir '.universal/dashboards.ps1') `
                -Value "New-PSUApp -Name 'Devolutions CIEM' -BaseUrl '/ciem'"

            # Neutralize external dependencies
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { [PSCustomObject]@{ Url = 'https://mocked'; Status = 'Connected' } }
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { $null }
            Mock -ModuleName Devolutions.CIEM.Admin Restart-PSUApp { throw 'Mocked restart failure: PSU connection stale' }
        }

        It 'rethrows the Restart-PSUApp failure instead of emitting a warning' {
            { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -Confirm:$false } |
                Should -Throw -ExpectedMessage '*Mocked restart failure*'
        }

        It 'invokes Restart-PSUApp with the CIEM app name' {
            try { Publish-PSUModule -ModulePath $script:srcDir -LocalOnly -Confirm:$false } catch {}
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Restart-PSUApp -Times 1 -ParameterFilter { $Name -eq 'Devolutions CIEM' }
        }
    }
}

Describe 'Publish-PSUModule -> PSGallery + PSU update (remote path)' {
    BeforeAll {
        # Build a minimal fake module layout for the non-LocalOnly path.
        # Note: the remote path also uses $projectRoot = Split-Path $ModulePath -Parent to find
        # an .env file, so the parent of the module dir is allowed to be empty (no .env present).
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

            # First Find-Module call (pre-publish gallery check) returns nothing so the bump is off the local manifest
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
