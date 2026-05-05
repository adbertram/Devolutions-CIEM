BeforeAll {
    if (-not (Get-Module -Name Universal)) {
        New-Module -Name Universal -ScriptBlock {
            function Sync-PSUConfiguration { param([switch]$Reset) }
        } | Import-Module
    }

    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $manifest = Join-Path $moduleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $manifest
}

Describe 'Remove-PSUModule target connections' {
    BeforeEach {
        $script:capturedRestCalls = [System.Collections.Generic.List[object]]::new()

        InModuleScope Devolutions.CIEM.Admin {
            $script:PSUConnection.Url = $null
            $script:PSUConnection.Token = $null
            $script:PSUConnection.IsAzure = $false
            $script:PSUConnection.ResourceGroup = $null
            $script:PSUConnection.WebAppName = $null
        }

        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUModule {
            @([PSCustomObject]@{
                id      = 42
                name    = 'Devolutions.CIEM'
                version = '0.3.0'
            })
        } -ParameterFilter { $Name -eq 'Devolutions.CIEM' }

        Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
            $script:capturedRestCalls.Add([PSCustomObject]@{
                Uri     = $Uri
                Method  = $Method
                Headers = $Headers
                Body    = $Body
            })

            if ($Method -eq 'Post') {
                return [PSCustomObject]@{
                    ExitCode = 0
                    Error    = ''
                }
            }

            return $null
        }

        Mock -ModuleName Devolutions.CIEM.Admin Sync-PSUConfiguration {}
        Mock -ModuleName Devolutions.CIEM.Admin az {
            '[{"publishMethod":"MSDeploy","userName":"kudu-user","userPWD":"kudu-pass"}]'
        }
    }

    It 'connects to Azure before removing the module from PSU and the Azure filesystem' {
        Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'https://devolutions-ciem-psu.azurewebsites.net'
                $script:PSUConnection.Token = 'azure-token'
                $script:PSUConnection.IsAzure = $true
                $script:PSUConnection.ResourceGroup = 'devolutions-ciem-rg'
                $script:PSUConnection.WebAppName = 'devolutions-ciem-psu'
            }

            [PSCustomObject]@{
                Url           = 'https://devolutions-ciem-psu.azurewebsites.net'
                Status        = 'Connected'
                IsAzure       = $true
                ResourceGroup = 'devolutions-ciem-rg'
                WebAppName    = 'devolutions-ciem-psu'
            }
        }

        $result = Remove-PSUModule `
            -Name 'Devolutions.CIEM' `
            -Environment azure `
            -EnvFilePath 'NO_ENV_FILE' `
            -Force `
            -WarningAction SilentlyContinue

        Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Connect-PSU -Times 1 -Scope It -ParameterFilter {
            -not $Local -and $EnvFilePath -eq 'NO_ENV_FILE'
        }

        $deleteCall = $script:capturedRestCalls | Where-Object { $_.Method -eq 'Delete' } | Select-Object -First 1
        $deleteCall.Uri | Should -Be 'https://devolutions-ciem-psu.azurewebsites.net/api/v1/module/42'
        $deleteCall.Headers.Authorization | Should -Be 'Bearer azure-token'

        $kuduCall = $script:capturedRestCalls | Where-Object { $_.Uri -eq 'https://devolutions-ciem-psu.scm.azurewebsites.net/api/command' } | Select-Object -First 1
        $kuduCall | Should -Not -BeNullOrEmpty
        ($kuduCall.Body | ConvertFrom-Json).command | Should -Be 'rm -rf "/home/Repository/Modules/Devolutions.CIEM"'

        $result.Source | Should -Be 'Filesystem'
    }

    It 'connects to the local PSU instance when local is the requested environment' {
        Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'http://192.168.86.36:5001'
                $script:PSUConnection.Token = 'local-token'
                $script:PSUConnection.IsAzure = $false
                $script:PSUConnection.ResourceGroup = $null
                $script:PSUConnection.WebAppName = $null
            }

            [PSCustomObject]@{
                Url           = 'http://192.168.86.36:5001'
                Status        = 'Connected'
                IsAzure       = $false
                ResourceGroup = $null
                WebAppName    = $null
            }
        }

        $result = Remove-PSUModule `
            -Name 'Devolutions.CIEM' `
            -Environment local `
            -EnvFilePath 'NO_ENV_FILE' `
            -Force `
            -WarningAction SilentlyContinue

        Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Connect-PSU -Times 1 -Scope It -ParameterFilter {
            $Local -and $EnvFilePath -eq 'NO_ENV_FILE'
        }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName az -Times 0 -Scope It

        $deleteCall = $script:capturedRestCalls | Where-Object { $_.Method -eq 'Delete' } | Select-Object -First 1
        $deleteCall.Uri | Should -Be 'http://192.168.86.36:5001/api/v1/module/42'
        $result.Source | Should -Be 'Database'
    }

    It 'requires an explicit environment when connection parameters are supplied' {
        Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
            throw 'Connect-PSU should not run without an explicit environment'
        }

        {
            Remove-PSUModule `
                -Name 'Devolutions.CIEM' `
                -EnvFilePath 'NO_ENV_FILE' `
                -Force `
                -WarningAction SilentlyContinue
        } | Should -Throw -ExpectedMessage '*-Environment*'

        Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Connect-PSU -Times 0 -Scope It
    }

    It 'returns NotFound when the local PSU module database entry is already absent' {
        Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'http://192.168.86.36:5001'
                $script:PSUConnection.Token = 'local-token'
                $script:PSUConnection.IsAzure = $false
                $script:PSUConnection.ResourceGroup = $null
                $script:PSUConnection.WebAppName = $null
            }
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUModule { @() } -ParameterFilter { $Name -eq 'Devolutions.CIEM' }

        $result = Remove-PSUModule `
            -Name 'Devolutions.CIEM' `
            -Environment local `
            -EnvFilePath 'NO_ENV_FILE' `
            -Force `
            -WarningAction SilentlyContinue

        $result.Status | Should -Be 'NotFound'
        $result.Source | Should -Be 'Database'
        Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Invoke-RestMethod -Times 0 -Scope It -ParameterFilter {
            $Method -eq 'Delete'
        }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Sync-PSUConfiguration -Times 0 -Scope It
    }

    It 'cleans the Azure filesystem when the module database entry is already absent' {
        Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
            InModuleScope Devolutions.CIEM.Admin {
                $script:PSUConnection.Url = 'https://devolutions-ciem-psu.azurewebsites.net'
                $script:PSUConnection.Token = 'azure-token'
                $script:PSUConnection.IsAzure = $true
                $script:PSUConnection.ResourceGroup = 'devolutions-ciem-rg'
                $script:PSUConnection.WebAppName = 'devolutions-ciem-psu'
            }
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUModule { @() } -ParameterFilter { $Name -eq 'Devolutions.CIEM' }

        $result = Remove-PSUModule `
            -Name 'Devolutions.CIEM' `
            -Environment azure `
            -EnvFilePath 'NO_ENV_FILE' `
            -Force `
            -WarningAction SilentlyContinue

        $deleteCall = $script:capturedRestCalls | Where-Object { $_.Method -eq 'Delete' } | Select-Object -First 1
        $deleteCall | Should -BeNullOrEmpty

        $kuduCall = $script:capturedRestCalls | Where-Object { $_.Uri -eq 'https://devolutions-ciem-psu.scm.azurewebsites.net/api/command' } | Select-Object -First 1
        $kuduCall | Should -Not -BeNullOrEmpty
        ($kuduCall.Body | ConvertFrom-Json).command | Should -Be 'rm -rf "/home/Repository/Modules/Devolutions.CIEM"'

        $result.Status | Should -Be 'Removed'
        $result.Source | Should -Be 'Filesystem'
        Should -Invoke -ModuleName Devolutions.CIEM.Admin -CommandName Sync-PSUConfiguration -Times 1 -Scope It
    }
}
