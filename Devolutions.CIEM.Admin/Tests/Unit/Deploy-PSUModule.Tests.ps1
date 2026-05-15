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

Describe 'Deploy-PSUModule parameter surface' {
    It 'is exported from Devolutions.CIEM.Admin' {
        Get-Command Deploy-PSUModule -Module Devolutions.CIEM.Admin -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'exposes the expected parameters' {
        $cmd = Get-Command Deploy-PSUModule -Module Devolutions.CIEM.Admin
        $cmd.Parameters.Keys | Should -Contain 'Environment'
        $cmd.Parameters.Keys | Should -Contain 'ModulePath'
        $cmd.Parameters.Keys | Should -Contain 'Version'
        $cmd.Parameters.Keys | Should -Contain 'EnvFilePath'
        $cmd.Parameters.Keys | Should -Contain 'SkipAppRestart'
        $cmd.Parameters.Keys | Should -Contain 'ValidateDeployment'
        $cmd.Parameters.Keys | Should -Contain 'TimeoutSeconds'
    }

    It 'validates Environment to local or azure' {
        $cmd = Get-Command Deploy-PSUModule -Module Devolutions.CIEM.Admin
        $validateSet = $cmd.Parameters['Environment'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $validateSet.ValidValues | Should -Be @('local', 'azure')
    }
}

Describe 'Deploy-PSUModule' {
    BeforeAll {
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
    }

    Context 'when Environment is local' {
        BeforeAll {
            $script:connectCalls = [System.Collections.Generic.List[object]]::new()
            $script:removeCalls = [System.Collections.Generic.List[object]]::new()
            $script:installCalls = [System.Collections.Generic.List[object]]::new()
            $script:operationOrder = [System.Collections.Generic.List[string]]::new()
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
                $script:connectCalls.Add([pscustomobject]@{ Local = [bool]$Local; Azure = [bool]$Azure; EnvFilePath = $EnvFilePath })
                [PSCustomObject]@{ Url = 'http://mocked-local'; Status = 'Connected'; IsAzure = $false }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUModule {
                $script:operationOrder.Add('remove')
                $script:removeCalls.Add([pscustomobject]@{ Name = $Name; Environment = $Environment; Force = [bool]$Force; EnvFilePath = $EnvFilePath })
            }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule {
                $script:operationOrder.Add('install')
                $script:installCalls.Add([pscustomobject]@{ Name = $Name; Version = $Version })
                [pscustomobject]@{ Name = $Name; Version = '5.1.6'; Repository = 'PSGallery'; Status = 'Installed' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Restart-CIEMPSUApp {}
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-CIEMPSUModuleDeployment { throw 'Validation must not run unless -ValidateDeployment' }
        }

        BeforeEach {
            $script:connectCalls.Clear()
            $script:removeCalls.Clear()
            $script:installCalls.Clear()
            $script:operationOrder.Clear()
        }

        It 'connects with -Local' {
            Deploy-PSUModule -Environment local -ModulePath $script:srcDir -Version '5.1.6' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            $script:connectCalls.Count | Should -Be 1
            $script:connectCalls[0].Local | Should -BeTrue
            $script:connectCalls[0].Azure | Should -BeFalse
        }

        It 'installs the requested version from PSGallery' {
            Deploy-PSUModule -Environment local -ModulePath $script:srcDir -Version '5.1.6' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            $script:installCalls.Count | Should -Be 1
            $script:installCalls[0].Name | Should -Be 'Devolutions.CIEM'
            $script:installCalls[0].Version | Should -Be '5.1.6'
        }

        It 'removes existing module versions before installing the requested version' {
            Deploy-PSUModule -Environment local -ModulePath $script:srcDir -Version '5.1.6' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            $script:removeCalls.Count | Should -Be 1
            $script:removeCalls[0].Name | Should -Be 'Devolutions.CIEM'
            $script:removeCalls[0].Environment | Should -Be 'local'
            $script:removeCalls[0].Force | Should -BeTrue
            $script:removeCalls[0].EnvFilePath | Should -Be 'NO_ENV_FILE'
            $script:operationOrder | Should -Be @('remove', 'install')
        }

        It 'restarts the CIEM app by default' {
            Deploy-PSUModule -Environment local -ModulePath $script:srcDir -Version '5.1.6' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Restart-CIEMPSUApp -Times 1 -Scope It
        }

        It 'returns a deployed envelope with environment, version, and status' {
            $result = Deploy-PSUModule -Environment local -ModulePath $script:srcDir -Version '5.1.6' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false

            $result.ModuleName | Should -Be 'Devolutions.CIEM'
            $result.Version | Should -Be '5.1.6'
            $result.Environment | Should -Be 'local'
            $result.GalleryUrl | Should -Be 'https://www.powershellgallery.com/packages/Devolutions.CIEM'
            $result.UpdatedPSU | Should -BeTrue
            $result.Status | Should -Be 'Deployed'
        }
    }

    Context 'when Environment is azure' {
        BeforeAll {
            $script:connectCalls = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
                $script:connectCalls.Add([pscustomobject]@{ Local = [bool]$Local; Azure = [bool]$Azure })
                [PSCustomObject]@{ Url = 'https://mocked-azure'; Status = 'Connected'; IsAzure = $true }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule {
                [pscustomobject]@{ Name = $Name; Version = '5.1.6'; Repository = 'PSGallery'; Status = 'Installed' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUModule {}
            Mock -ModuleName Devolutions.CIEM.Admin Restart-CIEMPSUApp {}
        }

        It 'connects with -Azure' {
            Deploy-PSUModule -Environment azure -ModulePath $script:srcDir -Version '5.1.6' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            $script:connectCalls[-1].Azure | Should -BeTrue
            $script:connectCalls[-1].Local | Should -BeFalse
        }

        It 'reports environment=azure in the result' {
            $result = Deploy-PSUModule -Environment azure -ModulePath $script:srcDir -Version '5.1.6' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false
            $result.Environment | Should -Be 'azure'
        }
    }

    Context 'when -Version is omitted' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
                [PSCustomObject]@{ Url = 'http://mocked'; Status = 'Connected'; IsAzure = $false }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule {
                [pscustomobject]@{ Name = $Name; Version = $Version; Repository = 'PSGallery'; Status = 'Installed' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUModule {}
            Mock -ModuleName Devolutions.CIEM.Admin Restart-CIEMPSUApp {}
        }

        It 'passes the local manifest version to Install-PSUModule' {
            Deploy-PSUModule -Environment local -ModulePath $script:srcDir -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Install-PSUModule -Times 1 -Scope It -ParameterFilter {
                $Name -eq 'Devolutions.CIEM' -and $Version -eq '0.0.1'
            }
        }

        It 'returns the version that Install-PSUModule reports' {
            $result = Deploy-PSUModule -Environment local -ModulePath $script:srcDir -EnvFilePath 'NO_ENV_FILE' -Confirm:$false
            $result.Version | Should -Be '0.0.1'
        }
    }

    Context 'when -SkipAppRestart is set' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
                [PSCustomObject]@{ Url = 'http://mocked'; Status = 'Connected'; IsAzure = $false }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule {
                [pscustomobject]@{ Name = $Name; Version = '5.1.6'; Repository = 'PSGallery'; Status = 'Installed' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUModule {}
            Mock -ModuleName Devolutions.CIEM.Admin Restart-CIEMPSUApp { throw 'Restart-CIEMPSUApp must not run when -SkipAppRestart is set' }
        }

        It 'does not call Restart-CIEMPSUApp' {
            Deploy-PSUModule -Environment local -ModulePath $script:srcDir -Version '5.1.6' -SkipAppRestart -EnvFilePath 'NO_ENV_FILE' -Confirm:$false | Out-Null

            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Restart-CIEMPSUApp -Times 0 -Scope It
        }
    }

    Context 'when -ValidateDeployment is set' {
        BeforeAll {
            $script:validateCalls = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
                [PSCustomObject]@{ Url = 'http://mocked'; Status = 'Connected'; IsAzure = $false }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule {
                [pscustomobject]@{ Name = $Name; Version = '5.1.6'; Repository = 'PSGallery'; Status = 'Installed' }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUModule {}
            Mock -ModuleName Devolutions.CIEM.Admin Restart-CIEMPSUApp { throw 'Restart-CIEMPSUApp must not run when -ValidateDeployment is set (validation handles its own restart)' }
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-CIEMPSUModuleDeployment {
                $script:validateCalls.Add([pscustomobject]@{ Environment = $Environment; ModulePath = $ModulePath; EnvFilePath = $EnvFilePath; TimeoutSeconds = $TimeoutSeconds })
                [pscustomobject]@{ Status = 'Deployed'; ValidationResult = [pscustomobject]@{ Status = 'Healthy' } }
            }
        }

        It 'invokes Invoke-CIEMPSUModuleDeployment with the matching Environment and returns its result' {
            $result = Deploy-PSUModule -Environment local -ModulePath $script:srcDir -Version '5.1.6' -ValidateDeployment -EnvFilePath '/tmp/custom-ciem.env' -Confirm:$false

            $script:validateCalls.Count | Should -Be 1
            $script:validateCalls[0].Environment | Should -Be 'local'
            $script:validateCalls[0].EnvFilePath | Should -Be '/tmp/custom-ciem.env'
            $result.Status | Should -Be 'Deployed'
            $result.ValidationResult.Status | Should -Be 'Healthy'
        }
    }

    Context 'when Install-PSUModule throws' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
                [PSCustomObject]@{ Url = 'http://mocked'; Status = 'Connected'; IsAzure = $false }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUModule {}
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule { throw 'Mocked install failure: PSU rejected the module upload' }
            Mock -ModuleName Devolutions.CIEM.Admin Restart-CIEMPSUApp { throw 'Restart must not run when install failed' }
        }

        It 'rethrows and never restarts the app' {
            { Deploy-PSUModule -Environment local -ModulePath $script:srcDir -Version '5.1.6' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*Mocked install failure*'

            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Restart-CIEMPSUApp -Times 0 -Scope It
        }
    }

    Context 'when Connect-PSU throws' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU { throw 'Mocked connect failure: AZURE_PSU_TOKEN missing' }
            Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUModule { throw 'Remove must not run when connect failed' }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule { throw 'Install must not run when connect failed' }
        }

        It 'rethrows and never installs' {
            { Deploy-PSUModule -Environment azure -ModulePath $script:srcDir -Version '5.1.6' -EnvFilePath 'NO_ENV_FILE' -Confirm:$false } |
                Should -Throw -ExpectedMessage '*Mocked connect failure*'

            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Install-PSUModule -Times 0 -Scope It
        }
    }

    Context 'when -WhatIf is set' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
                [PSCustomObject]@{ Url = 'http://mocked'; Status = 'Connected'; IsAzure = $false }
            }
            Mock -ModuleName Devolutions.CIEM.Admin Install-PSUModule { throw 'Install must not run in -WhatIf mode' }
            Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUModule { throw 'Remove must not run in -WhatIf mode' }
            Mock -ModuleName Devolutions.CIEM.Admin Restart-CIEMPSUApp { throw 'Restart must not run in -WhatIf mode' }
        }

        It 'returns a DryRun status without installing' {
            $result = Deploy-PSUModule -Environment local -ModulePath $script:srcDir -Version '5.1.6' -EnvFilePath 'NO_ENV_FILE' -WhatIf

            $result.Status | Should -Be 'DryRun'
            Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Install-PSUModule -Times 0 -Scope It
        }
    }
}
