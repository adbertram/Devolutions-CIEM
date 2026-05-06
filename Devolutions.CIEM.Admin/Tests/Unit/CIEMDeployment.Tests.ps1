BeforeAll {
    Remove-Module Universal -Force -ErrorAction SilentlyContinue
    New-Module -Name Universal -ScriptBlock {
        function Connect-PSUServer { param([string]$ComputerName, [string]$AppToken) }
        function Get-PSUScript {}
        function Remove-PSUScript { param([object]$Script) }
        function Get-PSUJob {
            param(
                [uint64]$First,
                [uint64]$Skip,
                [string]$OrderDirection,
                [bool]$HideChildren,
                [bool]$HideScheduled,
                [bool]$HideTriggered
            )
        }
        function Stop-PSUJob { param([long]$Id) }
        function Get-PSUSchedule {}
        function Remove-PSUSchedule { param([object]$Schedule) }
        function Get-PSUApp {}
        function Remove-PSUApp { param([long]$Id) }
        function New-PSUApp {
            param(
                [string]$Name,
                [string]$BaseUrl,
                [string]$Module,
                [string]$Command,
                [switch]$Integrated
            )
        }
        function Get-PSUAppToken {}
        function Get-PSUInformation {}
        function Stop-PSUApp { param([string]$Name) }
        function Start-PSUApp { param([string]$Name) }
        function Sync-PSUConfiguration { param([switch]$Reset) }
    } | Import-Module

    $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $script:Manifest = Join-Path $script:ModuleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $script:Manifest
}

AfterAll {
    Remove-Module Universal -Force -ErrorAction SilentlyContinue
}

Describe 'CIEM deployment cmdlet exports' {
    It 'exports one module publish/deploy command instead of a duplicate CIEM module wrapper' {
        $manifestData = Import-PowerShellDataFile -Path $script:Manifest

        foreach ($commandName in @(
                'Deploy-CIEMPSUInstance'
                'Remove-CIEMPSUModule'
                'Publish-PSUModule'
                'Test-CIEMPSUDeployment'
            )) {
            $manifestData.FunctionsToExport | Should -Contain $commandName
            Get-Command -Module Devolutions.CIEM.Admin -Name $commandName | Should -Not -BeNullOrEmpty
        }

        $manifestData.FunctionsToExport | Should -Not -Contain 'Deploy-CIEMPSUModule'
        Get-Command -Module Devolutions.CIEM.Admin -Name 'Deploy-CIEMPSUModule' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}

Describe 'Deploy-CIEMPSUInstance' {
    BeforeEach {
        $script:azCalls = [System.Collections.Generic.List[object]]::new()
        $script:sleepCalls = 0
        $script:webCalls = 0
        $script:restCalls = [System.Collections.Generic.List[string]]::new()
        $script:azFailureAt = ''

        Mock -ModuleName Devolutions.CIEM.Admin az {
            $script:azCalls.Add(@($args))
            $commandText = @($args) -join ' '
            if ($script:azFailureAt -and $commandText -match "^$([regex]::Escape($script:azFailureAt))") {
                $global:LASTEXITCODE = 42
                return 'mock az failure'
            }

            $global:LASTEXITCODE = 0
            switch -Regex ($commandText) {
                '^account show' { return 'CIEM Subscription' }
                default { return $null }
            }
        }
        Mock -ModuleName Devolutions.CIEM.Admin Invoke-WebRequest {
            $script:webCalls++
            [pscustomobject]@{ StatusCode = 200 }
        }
        Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
            $script:restCalls.Add($Uri)
            [pscustomobject]@{ loading = $false; hasError = $false; loadingInfo = '' }
        }
        Mock -ModuleName Devolutions.CIEM.Admin Start-Sleep { $script:sleepCalls++ }
    }

    It 'deploys the Azure PSU host through the Bicep template and waits for the PSU alive endpoint' {
        $result = Deploy-CIEMPSUInstance `
            -ResourceGroup 'devolutions-ciem-rg' `
            -SiteName 'devolutions-ciem-psu' `
            -Location 'westus2' `
            -ServicePlanPricingTier 'S1' `
            -PsuVersion '5.5.4' `
            -TimeoutSeconds 30 `
            -PollIntervalSeconds 1

        $result.Status | Should -Be 'Ready'
        $result.Url | Should -Be 'https://devolutions-ciem-psu.azurewebsites.net'

        @($script:azCalls | Where-Object { (@($_) -join ' ') -match '^account show' }).Count | Should -Be 1
        @($script:azCalls | Where-Object { (@($_) -join ' ') -match '^group create --name devolutions-ciem-rg --location westus2' }).Count | Should -Be 1
        $deploymentCalls = @($script:azCalls | Where-Object { (@($_) -join ' ') -match '^deployment group create' })
        $deploymentCalls.Count | Should -Be 1
        ($deploymentCalls[0] -join ' ') | Should -Match 'deploy/psu_standalone.bicep'
        ($deploymentCalls[0] -join ' ') | Should -Match 'siteName=devolutions-ciem-psu'
        ($deploymentCalls[0] -join ' ') | Should -Match 'version=5.5.4'
        ($deploymentCalls[0] -join ' ') | Should -Match 'servicePlanPricingTier=S1'
        $script:restCalls | Should -Contain 'https://devolutions-ciem-psu.azurewebsites.net/api/v1/alive'
        $script:webCalls | Should -Be 0
    }

    It 'throws when Azure CLI deployment fails' {
        $script:azFailureAt = 'deployment group create'

        $errorRecord = $null
        try {
            Deploy-CIEMPSUInstance `
                -ResourceGroup 'devolutions-ciem-rg' `
                -SiteName 'devolutions-ciem-psu' `
                -Location 'westus2' `
                -ServicePlanPricingTier 'S1' `
                -PsuVersion '5.5.4' `
                -TimeoutSeconds 30 `
                -PollIntervalSeconds 1
        }
        catch {
            $errorRecord = $_
        }

        $errorRecord | Should -Not -BeNullOrEmpty
        $errorRecord.Exception.Message | Should -Match 'az deployment group create failed with exit code 42'
        $errorRecord.Exception.Message | Should -Match 'jwtSigningKey=\*\*\*'
        $errorRecord.Exception.Message | Should -Not -Match 'jwtSigningKey=[A-Za-z0-9+/=]{10,}'
    }
}

Describe 'Remove-CIEMPSUModule' {
    BeforeEach {
        $script:ModulePath = Join-Path $TestDrive 'psu-app'
        $script:ManifestPath = Join-Path $script:ModulePath 'data/psu-scripts.json'
        $script:RemediationRoot = Join-Path $script:ModulePath 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts'

        New-Item -Path (Split-Path $script:ManifestPath -Parent) -ItemType Directory -Force | Out-Null
        New-Item -Path $script:RemediationRoot -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path $script:RemediationRoot 'management-port-open-to-the-internet.ps1') -Value '$ErrorActionPreference = ''Stop'''
        Set-Content -Path $script:ManifestPath -Value @'
{
  "scripts": [
    {
      "name": "Checks/New-CIEMScanRun"
    },
    {
      "name": "Checks/Start-CIEMAzureDiscovery"
    },
    {
      "name": "Checks/Invoke-CIEMAttackPathRemediation"
    }
  ],
  "remediationTemplates": {
    "path": "modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts"
  }
}
'@

        Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {}
        Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUModule {
            [pscustomobject]@{
                Name   = $Name
                Status = 'Removed'
            }
        }
        Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUScript {}
        Mock -ModuleName Devolutions.CIEM.Admin Stop-PSUJob {}
        Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUSchedule {}
        Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUApp {}
    }

    It 'removes CIEM-owned apps, scripts, schedules, active jobs, and the module from Azure' {
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUApp {
            @(
                [pscustomobject]@{ Id = 30; Name = 'Devolutions CIEM'; BaseUrl = '/ciem'; Module = 'Devolutions.CIEM'; Command = 'New-DevolutionsCIEMApp' }
                [pscustomobject]@{ Id = 31; Name = 'Operations'; BaseUrl = '/ops'; Module = 'Operations.Tools'; Command = 'New-OperationsApp' }
            )
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUScript {
            if ($PSBoundParameters.ContainsKey('Name')) {
                throw 'Remove-CIEMPSUModule must not use Get-PSUScript -Name against Azure'
            }

            @(
                [pscustomobject]@{ Name = 'Checks/New-CIEMScanRun' }
                [pscustomobject]@{ Name = 'management-port-open-to-the-internet'; FullPath = 'Identities/AttackPaths/management-port-open-to-the-internet.ps1'; CommitNotes = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json' }
                [pscustomobject]@{ Name = 'Infra/RotateCertificates' }
            )
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUJob {
            @(
                [pscustomobject]@{ Id = 10; Status = 1; ScriptFullPath = 'Checks/Start-CIEMAzureDiscovery.ps1' }
                [pscustomobject]@{ Id = 11; Status = 0; ScriptFullPath = 'CIEMExecutor.ps1' }
                [pscustomobject]@{ Id = 12; Status = 2; ScriptFullPath = 'Infra/RotateCertificates.ps1' }
                [pscustomobject]@{ Id = 13; Status = 2; ScriptFullPath = 'Checks/New-CIEMScanRun.ps1' }
                [pscustomobject]@{ Id = 14; Status = 2; ScriptFullPath = $null }
                [pscustomobject]@{ Id = 15; Status = 2 }
            )
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUSchedule {
            @(
                [pscustomobject]@{ Id = 20; Name = 'CIEM scan'; ScriptName = 'Checks/Start-CIEMAzureDiscovery.ps1' }
                [pscustomobject]@{ Id = 21; Name = 'Infra rotation'; ScriptName = 'Infra/RotateCertificates.ps1' }
            )
        }

        $result = Remove-CIEMPSUModule -Environment azure -ModulePath $script:ModulePath -EnvFilePath 'NO_ENV_FILE' -Force

        $result.Status | Should -Be 'Removed'
        $result.AppResourcesScanned | Should -Be 2
        $result.AppResourcesRemoved | Should -Be 1
        $result.ScriptResourcesScanned | Should -Be 3
        $result.ScriptResourcesRemoved | Should -Be 2
        $result.JobResourcesScanned | Should -Be 6
        $result.JobResourcesMatched | Should -Be 2
        $result.JobResourcesStopped | Should -Be 1
        $result.QueuedJobResourcesRetained | Should -Be 0
        $result.JobHistoryRetained | Should -Be 1
        $result.ScheduleResourcesRemoved | Should -Be 1

        Should -Invoke -ModuleName Devolutions.CIEM.Admin Connect-PSU -Times 1 -ParameterFilter {
            -not $Local -and $EnvFilePath -eq 'NO_ENV_FILE'
        }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Get-PSUScript -Times 1 -ParameterFilter {
            -not $PSBoundParameters.ContainsKey('Name')
        }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUApp -Times 1 -ParameterFilter { $Id -eq 30 }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Stop-PSUJob -Times 1 -ParameterFilter { $Id -eq 10 }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUSchedule -Times 1 -ParameterFilter { $Schedule.Id -eq 20 }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'Checks/New-CIEMScanRun' }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'management-port-open-to-the-internet' }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUModule -Times 1 -ParameterFilter {
            $Name -eq 'Devolutions.CIEM' -and
            $Environment -eq 'azure' -and
            $EnvFilePath -eq 'NO_ENV_FILE' -and
            $Force
        }
    }

    It 'reports WhatIf without removing CIEM resources or the module' {
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUApp {
            @([pscustomobject]@{ Id = 30; Name = 'Devolutions CIEM'; BaseUrl = '/ciem'; Module = 'Devolutions.CIEM'; Command = 'New-DevolutionsCIEMApp' })
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUScript {
            @([pscustomobject]@{ Name = 'Checks/New-CIEMScanRun' })
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUJob {
            @([pscustomobject]@{ Id = 10; Status = 1; ScriptFullPath = 'Checks/Start-CIEMAzureDiscovery.ps1' })
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUSchedule {
            @([pscustomobject]@{ Id = 20; Name = 'CIEM scan'; ScriptName = 'Checks/Start-CIEMAzureDiscovery.ps1' })
        }

        $result = Remove-CIEMPSUModule -Environment azure -ModulePath $script:ModulePath -Force -WhatIf

        $result.Status | Should -Be 'WhatIf'
        $result.AppResourcesRemoved | Should -Be 0
        $result.ScriptResourcesRemoved | Should -Be 0
        $result.JobResourcesStopped | Should -Be 0
        $result.ScheduleResourcesRemoved | Should -Be 0
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUApp -Times 0 -Scope It
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUScript -Times 0 -Scope It
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUSchedule -Times 0 -Scope It
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Stop-PSUJob -Times 0 -Scope It
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUModule -Times 0 -Scope It
    }
}

Describe 'Test-CIEMPSUDeployment' {
    BeforeEach {
        $script:runtimeScripts = [System.Collections.Generic.List[string]]::new()
        $script:testEnvFilePaths = [System.Collections.Generic.List[string]]::new()
        $script:ciemPageUris = [System.Collections.Generic.List[string]]::new()
        $script:probeOutput = '{ "ModuleCount": 1, "AppCount": 1, "ScriptCount": 13, "ExpectedScriptCount": 13, "UnsupportedScriptCount": 0, "UnsupportedScriptNames": [], "DatabaseInitialized": true }'
        Mock -ModuleName Devolutions.CIEM.Admin Invoke-TestCommand {
            $script:runtimeScripts.Add($ScriptBlock.ToString())
            $script:testEnvFilePaths.Add([string]$EnvFilePath)
            [pscustomobject]@{
                Status = 'Completed'
                Output = @($script:probeOutput)
            }
        }
        Mock -ModuleName Devolutions.CIEM.Admin GetCIEMRuntimeTarget {
            [pscustomobject]@{
                Url = 'https://mocked-ciem-psu.azurewebsites.net'
            }
        }
        Mock -ModuleName Devolutions.CIEM.Admin Invoke-WebRequest {
            $script:ciemPageUris.Add($Uri)
            [pscustomobject]@{
                StatusCode = 200
                Content    = '<html><body>Devolutions CIEM</body></html>'
            }
        }
    }

    It 'uses one combined PSU runtime probe for module, app, scripts, and database state' {
        $result = Test-CIEMPSUDeployment -Environment azure -TimeoutSeconds 300

        $result.Status | Should -Be 'Healthy'
        $script:runtimeScripts.Count | Should -Be 1
        $script:runtimeScripts[0] | Should -Match 'Get-Module'
        $script:runtimeScripts[0] | Should -Match 'Get-PSUApp'
        $script:runtimeScripts[0] | Should -Match 'Get-PSUScript'
        $script:runtimeScripts[0] | Should -Match 'Get-CIEMDatabasePath'
        $script:ciemPageUris | Should -Contain 'https://mocked-ciem-psu.azurewebsites.net/ciem'
    }

    It 'passes the selected env file to the PSU runtime probe and page validation' {
        Test-CIEMPSUDeployment -Environment azure -EnvFilePath '/tmp/custom-ciem.env' | Out-Null

        $script:testEnvFilePaths[0] | Should -Be '/tmp/custom-ciem.env'
        Should -Invoke -ModuleName Devolutions.CIEM.Admin GetCIEMRuntimeTarget -Times 1 -ParameterFilter {
            $Name -eq 'azure' -and $EnvFilePath -eq '/tmp/custom-ciem.env'
        }
    }

    It 'throws when only one CIEM-managed PSU script is registered' {
        $script:probeOutput = '{ "ModuleCount": 1, "AppCount": 1, "ScriptCount": 1, "ExpectedScriptCount": 13, "UnsupportedScriptCount": 0, "UnsupportedScriptNames": [], "DatabaseInitialized": true }'

        { Test-CIEMPSUDeployment -Environment azure } |
            Should -Throw -ExpectedMessage '*expected 13 CIEM-managed PSU scripts*'
    }

    It 'throws when unsupported CIEM PSU script residue exists' {
        $script:probeOutput = '{ "ModuleCount": 1, "AppCount": 1, "ScriptCount": 13, "ExpectedScriptCount": 13, "UnsupportedScriptCount": 1, "UnsupportedScriptNames": ["Devolutions.CIEM/Start-CIEMAzureDiscovery"], "DatabaseInitialized": true }'

        { Test-CIEMPSUDeployment -Environment azure } |
            Should -Throw -ExpectedMessage '*unsupported CIEM PSU scripts on azure: Devolutions.CIEM/Start-CIEMAzureDiscovery*'
    }

    It 'throws when the CIEM page is still the PSU app-not-running placeholder' {
        Mock -ModuleName Devolutions.CIEM.Admin Invoke-WebRequest {
            $script:ciemPageUris.Add($Uri)
            [pscustomobject]@{
                StatusCode = 200
                Content    = '<html><body>App is not running</body></html>'
            }
        }

        { Test-CIEMPSUDeployment -Environment azure } |
            Should -Throw -ExpectedMessage '*CIEM app page is not running*'
    }
}
