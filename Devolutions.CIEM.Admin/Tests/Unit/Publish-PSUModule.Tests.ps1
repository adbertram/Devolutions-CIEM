BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $manifest = Join-Path $moduleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $manifest
}

Describe 'Publish-PSUModule parameter surface' {
    It 'does not expose deploy parameters that moved to Deploy-PSUModule' {
        $cmd = Get-Command Publish-PSUModule -Module Devolutions.CIEM.Admin
        $cmd.Parameters.Keys | Should -Not -Contain 'LocalOnly'
        $cmd.Parameters.Keys | Should -Not -Contain 'InstallPublishedVersion'
        $cmd.Parameters.Keys | Should -Not -Contain 'IncludeData'
        $cmd.Parameters.Keys | Should -Not -Contain 'SkipAppRestart'
        $cmd.Parameters.Keys | Should -Not -Contain 'ValidateDeployment'
        $cmd.Parameters.Keys | Should -Not -Contain 'TimeoutSeconds'
    }

    It 'exposes the PSGallery publish parameters' {
        $cmd = Get-Command Publish-PSUModule -Module Devolutions.CIEM.Admin
        $cmd.Parameters.Keys | Should -Contain 'ModulePath'
        $cmd.Parameters.Keys | Should -Contain 'NuGetApiKey'
        $cmd.Parameters.Keys | Should -Contain 'BumpVersion'
        $cmd.Parameters.Keys | Should -Contain 'SkipValidation'
        $cmd.Parameters.Keys | Should -Contain 'EnvFilePath'
    }
}

Describe 'Publish-PSUModule -> PSGallery' {
    BeforeAll {
        $script:srcDir = Join-Path $TestDrive 'psu-app'
        New-Item -Path $script:srcDir -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:srcDir '.universal') -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $script:srcDir 'modules/PSUSQLite') -ItemType Directory -Force | Out-Null

        New-ModuleManifest `
            -Path (Join-Path $script:srcDir 'Devolutions.CIEM.psd1') `
            -ModuleVersion '0.0.1' `
            -RootModule 'Devolutions.CIEM.psm1'
        Set-Content -Path (Join-Path $script:srcDir 'Devolutions.CIEM.psm1') -Value ''
        Set-Content `
            -Path (Join-Path $script:srcDir '.universal/dashboards.ps1') `
            -Value "New-PSUApp -Name 'Devolutions CIEM' -BaseUrl '/ciem'"
        Set-Content `
            -Path (Join-Path $script:srcDir '.universal/scripts.ps1') `
            -Value "Import-Module Devolutions.CIEM`nNew-PSUScript -Module 'Devolutions.CIEM' -Command 'New-CIEMScanRun'"
        Set-Content `
            -Path (Join-Path $script:srcDir 'setup.ps1') `
            -Value "function Invoke-CIEMPSUSetup { [pscustomobject]@{ Status = 'Initialized' } }`nInvoke-CIEMPSUSetup | Out-Null"
        New-ModuleManifest `
            -Path (Join-Path $script:srcDir 'modules/PSUSQLite/PSUSQLite.psd1') `
            -ModuleVersion '0.0.1' `
            -RootModule 'PSUSQLite.psm1'
        Set-Content -Path (Join-Path $script:srcDir 'modules/PSUSQLite/PSUSQLite.psm1') -Value ''
    }

    Context 'when PowerShell Gallery version lookup fails' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { throw 'mock gallery unavailable' }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {}
        }

        It 'throws instead of silently using only the local version baseline' {
            { Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*mock gallery unavailable*'
        }
    }

    Context 'when publishing succeeds' {
        BeforeAll {
            $script:publishCalls = [System.Collections.Generic.List[object]]::new()
            $script:findCallCount = 0

            Mock -ModuleName Devolutions.CIEM.Admin Find-Module {
                $script:findCallCount++
                # First call: pre-publish baseline. Subsequent calls: post-publish verification.
                if ($script:findCallCount -eq 1) {
                    [PSCustomObject]@{ Version = '0.0.2' }
                }
                else {
                    [PSCustomObject]@{ Version = '0.0.3' }
                }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {
                $script:publishCalls.Add([pscustomobject]@{
                        Path       = $Path
                        ApiKey     = $ApiKey
                        Repository = $Repository
                    })
            }
            Mock -ModuleName Devolutions.CIEM.Admin Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { throw 'Connect-PSU must not be called from Publish-PSUModule (deploy responsibility moved to Deploy-PSUModule)' }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule { throw 'Install-PSUModule must not be called from Publish-PSUModule' }
        }

        BeforeEach {
            $manifestPath = Join-Path $script:srcDir 'Devolutions.CIEM.psd1'
            $manifestContent = Get-Content -Path $manifestPath -Raw
            $reset = $manifestContent -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '0.0.1'"
            Set-Content -Path $manifestPath -Value $reset -NoNewline
            $script:publishCalls.Clear()
            $script:findCallCount = 0
        }

        It 'publishes the bumped version to PSGallery' {
            $result = Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -BumpVersion Patch -EnvFilePath 'NO_ENV_FILE' -Confirm:$false

            $result.Status | Should -Be 'Published'
            $result.ModuleName | Should -Be 'Devolutions.CIEM'
            $result.Version | Should -Be '0.0.3'
            $result.GalleryUrl | Should -Be 'https://www.powershellgallery.com/packages/Devolutions.CIEM'
            $script:publishCalls.Count | Should -Be 1
            $script:publishCalls[0].Repository | Should -Be 'PSGallery'
            $script:publishCalls[0].ApiKey | Should -Be 'fake-key'
        }

        It 'never calls Connect-PSU or Install-PSUModule from Publish-PSUModule (deploy responsibilities live in Deploy-PSUModule)' {
            Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Connect-PSU -Times 0 -Scope It
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Install-PSUModule -Times 0 -Scope It
        }

        It 'writes the bumped version back to the manifest' {
            Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -BumpVersion Patch -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            $manifestPath = Join-Path $script:srcDir 'Devolutions.CIEM.psd1'
            $data = Import-PowerShellDataFile -Path $manifestPath
            $data.ModuleVersion | Should -Be '0.0.3'
        }

        It 'bumps from the higher of local manifest or current Gallery version' {
            $manifestPath = Join-Path $script:srcDir 'Devolutions.CIEM.psd1'
            $content = Get-Content -Path $manifestPath -Raw
            $bumped = $content -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '0.0.5'"
            Set-Content -Path $manifestPath -Value $bumped -NoNewline

            $result = Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -BumpVersion Patch -EnvFilePath 'NO_ENV_FILE' -Confirm:$false

            $result.Version | Should -Be '0.0.6'
        }

        It 'supports Minor and Major bumps' {
            $result = Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -BumpVersion Minor -EnvFilePath 'NO_ENV_FILE' -Confirm:$false
            $result.Version | Should -Be '0.1.0'
        }

        It 'stages a clean copy that excludes Tests, ui/e2e, *.db, and node_modules before publishing' {
            New-Item -Path (Join-Path $script:srcDir 'Tests') -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $script:srcDir 'Tests/dummy.Tests.ps1') -Value '# dummy'
            New-Item -Path (Join-Path $script:srcDir 'ui/e2e') -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $script:srcDir 'ui/e2e/dummy.test.js') -Value '// dummy'
            New-Item -Path (Join-Path $script:srcDir 'node_modules') -ItemType Directory -Force | Out-Null
            Set-Content -Path (Join-Path $script:srcDir 'data.db') -Value 'fake db'

            Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            $stagingPath = $script:publishCalls[0].Path
            Test-Path (Join-Path $stagingPath 'Tests') | Should -BeFalse
            Test-Path (Join-Path $stagingPath 'ui/e2e') | Should -BeFalse
            Test-Path (Join-Path $stagingPath 'node_modules') | Should -BeFalse
            Test-Path (Join-Path $stagingPath 'data.db') | Should -BeFalse
        }
    }

    Context 'when NUGET_API_KEY is not provided' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { [PSCustomObject]@{ Version = '0.0.2' } }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {}
        }

        It 'throws a helpful error explaining where to set the key' {
            $env:NUGET_API_KEY = ''
            { Publish-PSUModule -ModulePath $script:srcDir -EnvFilePath 'NO_ENV_FILE' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*NuGet API key*'
        }
    }

    Context 'when running in -WhatIf mode' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { [PSCustomObject]@{ Version = '0.0.2' } }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource { throw 'Publish-PSResource should not run in WhatIf mode' }
        }

        It 'returns a DryRun status without publishing' {
            $result = Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -WhatIf

            $result.Status | Should -Be 'DryRun'
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Publish-PSResource -Times 0 -Scope It
        }
    }
}
