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

Describe 'Unlist-CIEMPSGalleryPackageVersion' {
    It 'sends the NuGet delete request for the exact package version' {
        $script:capturedDeleteUri = $null
        $script:capturedDeleteHeaders = $null
        $script:capturedDeleteMethod = $null

        Mock -ModuleName Devolutions.CIEM.Admin Invoke-WebRequest {
            $script:capturedDeleteUri = $Uri
            $script:capturedDeleteHeaders = $Headers
            $script:capturedDeleteMethod = $Method
        }

        InModuleScope Devolutions.CIEM.Admin {
            Unlist-CIEMPSGalleryPackageVersion -Name 'Devolutions.CIEM' -Version ([version]'0.2.108') -ApiKey 'fake-key'
        }

        $script:capturedDeleteMethod | Should -Be 'Delete'
        $script:capturedDeleteUri | Should -Be 'https://www.powershellgallery.com/api/v2/package/Devolutions.CIEM/0.2.108'
        $script:capturedDeleteHeaders['X-NuGet-ApiKey'] | Should -Be 'fake-key'
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
            -ModuleVersion '0.2.109' `
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

    BeforeEach {
        $manifestPath = Join-Path $script:srcDir 'Devolutions.CIEM.psd1'
        $manifestContent = Get-Content -Path $manifestPath -Raw
        $reset = $manifestContent -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '0.2.109'"
        Set-Content -Path $manifestPath -Value $reset -NoNewline
    }

    Context 'when PowerShell Gallery version lookup fails' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { throw 'mock gallery unavailable' }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {}
        }

        It 'throws instead of publishing without a listed Gallery version' {
            { Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*mock gallery unavailable*'
        }
    }

    Context 'when publishing succeeds' {
        BeforeAll {
            $script:publishCalls = [System.Collections.Generic.List[object]]::new()
            $script:unlistCalls = [System.Collections.Generic.List[object]]::new()

            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource {
                $script:publishCalls.Add([pscustomobject]@{
                        Path       = $Path
                        ApiKey     = $ApiKey
                        Repository = $Repository
                    })
            }
            Mock -ModuleName Devolutions.CIEM.Admin Unlist-CIEMPSGalleryPackageVersion {
                $script:unlistCalls.Add([pscustomobject]@{
                        Name    = $Name
                        Version = $Version
                        ApiKey  = $ApiKey
                    })
            }
            Mock -ModuleName Devolutions.CIEM.Admin Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { throw 'Connect-PSU must not be called from Publish-PSUModule (deploy responsibility moved to Deploy-PSUModule)' }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule { throw 'Install-PSUModule must not be called from Publish-PSUModule' }
        }

        BeforeEach {
            $script:publishCalls.Clear()
            $script:unlistCalls.Clear()
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { [PSCustomObject]@{ Version = '0.2.109' } }
            Mock -ModuleName Devolutions.CIEM.Admin Test-CIEMPSGalleryPackageVersion { $false }
        }

        It 'bumps and publishes the manifest version when the bumped version is exactly one patch above the listed Gallery version' {
            $result = Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false

            $result.Status | Should -Be 'Published'
            $result.ModuleName | Should -Be 'Devolutions.CIEM'
            $result.Version | Should -Be '0.2.110'
            $result.DelistedVersion | Should -BeNullOrEmpty
            $script:publishCalls.Count | Should -Be 1
            $script:unlistCalls.Count | Should -Be 0

            $manifestPath = Join-Path $script:srcDir 'Devolutions.CIEM.psd1'
            $data = Import-PowerShellDataFile -Path $manifestPath
            $data.ModuleVersion | Should -Be '0.2.110'
        }

        It 'delists the listed Gallery version before publishing when the bumped manifest is not exactly one patch higher' {
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { [PSCustomObject]@{ Version = '0.2.105' } }

            $result = Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false

            $result.Version | Should -Be '0.2.110'
            $result.DelistedVersion | Should -Be '0.2.105'
            $script:unlistCalls.Count | Should -Be 1
            $script:unlistCalls[0].Version | Should -Be ([version]'0.2.105')
            $script:publishCalls.Count | Should -Be 1
        }

        It 'delists a listed Gallery version from a different line before publishing the bumped 0.2.x manifest version' {
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { [PSCustomObject]@{ Version = '1.0.83' } }

            $result = Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false

            $result.Version | Should -Be '0.2.110'
            $result.DelistedVersion | Should -Be '1.0.83'
            $script:unlistCalls.Count | Should -Be 1
            $script:publishCalls.Count | Should -Be 1
        }

        It 'fails before delisting when the bumped manifest version is already consumed on PSGallery' {
            Mock -ModuleName Devolutions.CIEM.Admin Test-CIEMPSGalleryPackageVersion {
                $Version -eq [version]'0.2.110'
            }

            { Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*0.2.110*already exists*cannot be republished*'

            $script:unlistCalls.Count | Should -Be 0
            $script:publishCalls.Count | Should -Be 0
        }

        It 'never calls Connect-PSU or Install-PSUModule from Publish-PSUModule' {
            Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Connect-PSU -Times 0 -Scope It
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Install-PSUModule -Times 0 -Scope It
        }

        It 'rewrites the manifest version when publishing succeeds' {
            Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            $manifestPath = Join-Path $script:srcDir 'Devolutions.CIEM.psd1'
            $data = Import-PowerShellDataFile -Path $manifestPath
            $data.ModuleVersion | Should -Be '0.2.110'
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

    Context 'when the local manifest version leaves the 0.2.x line' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { [PSCustomObject]@{ Version = '0.2.109' } }
        }

        It 'throws before publishing' {
            $manifestPath = Join-Path $script:srcDir 'Devolutions.CIEM.psd1'
            $manifestContent = Get-Content -Path $manifestPath -Raw
            $updated = $manifestContent -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '0.3.0'"
            Set-Content -Path $manifestPath -Value $updated -NoNewline

            { Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*0.2.x*'
        }

        It 'throws when an explicit bump would leave the 0.2.x line' {
            { Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -BumpVersion Minor -EnvFilePath 'NO_ENV_FILE' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*0.2.x*'
        }
    }

    Context 'when NUGET_API_KEY is not provided' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { [PSCustomObject]@{ Version = '0.2.109' } }
            Mock -ModuleName Devolutions.CIEM.Admin Test-CIEMPSGalleryPackageVersion { $false }
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
            Mock -ModuleName Devolutions.CIEM.Admin Find-Module { [PSCustomObject]@{ Version = '0.2.105' } }
            Mock -ModuleName Devolutions.CIEM.Admin Test-CIEMPSGalleryPackageVersion { $false }
            Mock -ModuleName Devolutions.CIEM.Admin Publish-PSResource { throw 'Publish-PSResource should not run in WhatIf mode' }
            Mock -ModuleName Devolutions.CIEM.Admin Unlist-CIEMPSGalleryPackageVersion { throw 'Unlist-CIEMPSGalleryPackageVersion should not run in WhatIf mode' }
        }

        It 'returns a DryRun status without delisting or publishing' {
            $result = Publish-PSUModule -ModulePath $script:srcDir -NuGetApiKey 'fake-key' -EnvFilePath 'NO_ENV_FILE' -WhatIf

            $result.Status | Should -Be 'DryRun'
            $result.Version | Should -Be '0.2.110'
            $result.DelistedVersion | Should -Be '0.2.105'
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Publish-PSResource -Times 0 -Scope It
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Unlist-CIEMPSGalleryPackageVersion -Times 0 -Scope It

            $manifestPath = Join-Path $script:srcDir 'Devolutions.CIEM.psd1'
            $data = Import-PowerShellDataFile -Path $manifestPath
            $data.ModuleVersion | Should -Be '0.2.109'
        }
    }
}
