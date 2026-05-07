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
        function Remove-PSUCache { param([string]$Key) }
        function Get-PSUVariable { param([string]$Name) }
        function Remove-PSUVariable {
            param(
                [string]$Name,
                [object]$Variable,
                [switch]$RemoveSecret
            )
        }
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
        $script:LocalEnvFile = Join-Path $TestDrive '.env'

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
        Set-Content -Path $script:LocalEnvFile -Value @'
PUBLISH_POINT_SSH=adam-server
PUBLISH_POINT_PSU_PATH=/Users/adam/psu
LOCAL_PSU_URL=http://192.168.86.36:5001
LOCAL_PSU_TOKEN=fake-token
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
        Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUCache {}
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUVariable {
            @(
                [pscustomobject]@{ Name = 'CIEM_Azure_sp-clientsecret_ClientSecret' }
                [pscustomobject]@{ Name = 'CIEM_Azure_sp-clientsecret_CertPfx' }
                [pscustomobject]@{ Name = 'Other_Module_Secret' }
            )
        }
        Mock -ModuleName Devolutions.CIEM.Admin Remove-PSUVariable {}
        $script:sshCalls = [System.Collections.Generic.List[object]]::new()
        Mock -ModuleName Devolutions.CIEM.Admin ssh {
            $sshArgs = @($args)
            $script:sshCalls.Add([pscustomobject]@{
                    Args = $sshArgs
                    Text = $sshArgs -join ' '
                })
            $global:LASTEXITCODE = 0
        }
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
                [pscustomobject]@{ Name = 'CIEMExecutor.ps1'; FullPath = 'CIEMExecutor.ps1' }
                [pscustomobject]@{ Name = 'Infra/RotateCertificates' }
            )
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUJob {
            @(
                [pscustomobject]@{ Id = 10; Status = 1; ScriptFullPath = 'Checks/Start-CIEMAzureDiscovery.ps1' }
                [pscustomobject]@{ Id = 11; Status = 2; ScriptFullPath = 'CIEMExecutor.ps1' }
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
        $result.ScriptResourcesScanned | Should -Be 4
        $result.ScriptResourcesRemoved | Should -Be 3
        $result.JobResourcesScanned | Should -Be 6
        $result.JobResourcesMatched | Should -Be 3
        $result.JobResourcesStopped | Should -Be 1
        $result.QueuedJobResourcesRetained | Should -Be 0
        $result.JobHistoryRetained | Should -Be 2
        $result.ScheduleResourcesRemoved | Should -Be 1

        Should -Invoke -ModuleName Devolutions.CIEM.Admin Connect-PSU -Times 1 -ParameterFilter {
            $Azure -and -not $Local -and $EnvFilePath -eq 'NO_ENV_FILE'
        }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Get-PSUScript -Times 1 -ParameterFilter {
            -not $PSBoundParameters.ContainsKey('Name')
        }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUApp -Times 1 -ParameterFilter { $Id -eq 30 }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Stop-PSUJob -Times 1 -ParameterFilter { $Id -eq 10 }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUSchedule -Times 1 -ParameterFilter { $Schedule.Id -eq 20 }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'Checks/New-CIEMScanRun' }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'management-port-open-to-the-internet' }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'CIEMExecutor.ps1' }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUModule -Times 1 -ParameterFilter {
            $Name -eq 'Devolutions.CIEM' -and
            $Environment -eq 'azure' -and
            $EnvFilePath -eq 'NO_ENV_FILE' -and
            $Force
        }
        $script:sshCalls.Count | Should -Be 0
    }

    It 'removes local CIEM database and log files from the publish point' {
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUApp {
            @([pscustomobject]@{ Id = 30; Name = 'Devolutions CIEM'; BaseUrl = '/ciem'; Module = 'Devolutions.CIEM'; Command = 'New-DevolutionsCIEMApp' })
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUScript {
            @([pscustomobject]@{ Name = 'Checks/New-CIEMScanRun' })
        }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUJob { @() }
        Mock -ModuleName Devolutions.CIEM.Admin Get-PSUSchedule { @() }

        $result = Remove-CIEMPSUModule -Environment local -ModulePath $script:ModulePath -EnvFilePath $script:LocalEnvFile -Force

        $result.Status | Should -Be 'Removed'
        $result.DataRemoval.Status | Should -Be 'Removed'
        $result.DataRemoval.Target | Should -Be 'adam-server'
        $result.DataRemoval.Paths | Should -Contain '/Users/adam/psu/data/ciem.db'
        $result.DataRemoval.Paths | Should -Contain '/Users/adam/psu/data/ciem.db-shm'
        $result.DataRemoval.Paths | Should -Contain '/Users/adam/psu/data/ciem.db-wal'
        $result.DataRemoval.Paths | Should -Contain '/Users/adam/psu/data/ciem.log'
        $result.ConfigurationRemoval.CacheKeysRemoved | Should -Be 4
        $result.ConfigurationRemoval.VariablesRemoved | Should -Be 2

        Should -Invoke -ModuleName Devolutions.CIEM.Admin Connect-PSU -Times 1 -ParameterFilter {
            $Local -and -not $Azure -and $EnvFilePath -eq $script:LocalEnvFile
        }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUModule -Times 1 -ParameterFilter {
            $Name -eq 'Devolutions.CIEM' -and
            $Environment -eq 'local' -and
            $EnvFilePath -eq $script:LocalEnvFile -and
            $Force
        }
        $script:sshCalls.Count | Should -Be 1
        $script:sshCalls[0].Args[0] | Should -Be 'adam-server'
        $script:sshCalls[0].Text | Should -Match 'rm -f'
        $script:sshCalls[0].Text | Should -Match '/Users/adam/psu/data/ciem\.db'
        $script:sshCalls[0].Text | Should -Match '/Users/adam/psu/data/ciem\.log'
        foreach ($cacheKey in @('CIEM:AuthProfiles:Azure', 'CIEM:AuthProfile:AWS', 'CIEM:Config', 'CIEM:ScanConfig')) {
            Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUCache -Times 1 -ParameterFilter {
                $Key -eq $cacheKey
            }
        }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUVariable -Times 1 -ParameterFilter {
            $Name -eq 'CIEM_Azure_sp-clientsecret_ClientSecret' -and $RemoveSecret
        }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUVariable -Times 1 -ParameterFilter {
            $Name -eq 'CIEM_Azure_sp-clientsecret_CertPfx' -and $RemoveSecret
        }
        Should -Invoke -ModuleName Devolutions.CIEM.Admin Remove-PSUVariable -Times 0 -ParameterFilter {
            $Name -eq 'Other_Module_Secret'
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
        function New-TestDeploymentProbeJson {
            param(
                [Parameter()][string]$PsuVersion = '5.5.4',
                [Parameter()][int]$ScriptCount = 3,
                [Parameter()][int]$ExpectedScriptCount = 3,
                [Parameter()][int]$UnsupportedScriptCount = 0,
                [Parameter()][string[]]$UnsupportedScriptNames = @(),
                [Parameter()][bool]$DiscoveryCommandRegistered = $true,
                [Parameter()][bool]$ScheduleSupportAvailable = $true,
                [Parameter()][string]$ManagedIdentityReadStatus = 'NotRequested',
                [Parameter()][int]$ManagedIdentitySubscriptionCount = 0
            )

            [pscustomobject]@{
                PsuVersion                       = $PsuVersion
                ModuleCount                      = 1
                ModuleVersion                    = '4.0.21'
                ModuleBase                       = '/Users/adam/psu/Repository/Modules/Devolutions.CIEM'
                AppCount                         = 1
                ScriptCount                      = $ScriptCount
                ExpectedScriptCount              = $ExpectedScriptCount
                UnsupportedScriptCount           = $UnsupportedScriptCount
                UnsupportedScriptNames           = @($UnsupportedScriptNames)
                DiscoveryCommandRegistered       = $DiscoveryCommandRegistered
                ScheduleSupportAvailable         = $ScheduleSupportAvailable
                DatabasePath                     = '/Users/adam/psu/Repository/Modules/Devolutions.CIEM/data/ciem.db'
                DatabaseInitialized              = $true
                ManagedIdentityReadStatus        = $ManagedIdentityReadStatus
                ManagedIdentitySubscriptionCount = $ManagedIdentitySubscriptionCount
            } | ConvertTo-Json -Depth 5 -Compress
        }
        $script:probeOutput = New-TestDeploymentProbeJson
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

    It 'returns a production readiness checklist with PSU, module, app, script, schedule, database, and topology results' {
        $result = Test-CIEMPSUDeployment -Environment azure

        $result.SupportedTopology | Should -Be 'SingleInstance'
        $result.MultiInstanceStatus | Should -Be 'NotValidated'
        $result.SQLiteSupportStatus | Should -Be 'SupportedForSingleInstance'
        $result.Details.PsuVersion | Should -Be '5.5.4'
        $result.Details.ModuleVersion | Should -Be '4.0.21'
        $result.Details.ModuleBase | Should -Be '/Users/adam/psu/Repository/Modules/Devolutions.CIEM'
        $result.Details.DiscoveryCommandRegistered | Should -BeTrue
        $result.Details.ScheduleSupportAvailable | Should -BeTrue
        $result.Details.ManagedIdentityReadStatus | Should -Be 'NotRequested'

        $checkNames = @($result.Checklist | Select-Object -ExpandProperty Name)
        $checkNames | Should -Contain 'PSU version'
        $checkNames | Should -Contain 'CIEM module import path'
        $checkNames | Should -Contain 'CIEM app route'
        $checkNames | Should -Contain 'CIEM automation scripts'
        $checkNames | Should -Contain 'Scheduled discovery support'
        $checkNames | Should -Contain 'CIEM SQLite database'
        $checkNames | Should -Contain 'PSU topology'
        $checkNames | Should -Contain 'Managed identity read permission'
    }

    It 'passes the selected env file to the PSU runtime probe and page validation' {
        Test-CIEMPSUDeployment -Environment azure -EnvFilePath '/tmp/custom-ciem.env' | Out-Null

        $script:testEnvFilePaths[0] | Should -Be '/tmp/custom-ciem.env'
        Should -Invoke -ModuleName Devolutions.CIEM.Admin GetCIEMRuntimeTarget -Times 1 -ParameterFilter {
            $Name -eq 'azure' -and $EnvFilePath -eq '/tmp/custom-ciem.env'
        }
    }

    It 'enforces an expected PSU version only when the expected version is supplied' {
        $script:probeOutput = New-TestDeploymentProbeJson -PsuVersion '2026.1.0'

        $result = Test-CIEMPSUDeployment -Environment local
        $result.Details.PsuVersion | Should -Be '2026.1.0'

        { Test-CIEMPSUDeployment -Environment local -ExpectedPsuVersion '5.5.4' } |
            Should -Throw -ExpectedMessage '*expected PSU version 5.5.4*found 2026.1.0*'
    }

    It 'throws when only one CIEM-managed PSU script is registered' {
        $script:probeOutput = New-TestDeploymentProbeJson -ScriptCount 1

        { Test-CIEMPSUDeployment -Environment azure } |
            Should -Throw -ExpectedMessage '*expected 3 CIEM-managed PSU scripts*'
    }

    It 'throws when unsupported CIEM PSU script residue exists' {
        $script:probeOutput = New-TestDeploymentProbeJson -UnsupportedScriptCount 1 -UnsupportedScriptNames @('Checks/Start-CIEMAzureDiscovery')

        { Test-CIEMPSUDeployment -Environment azure } |
            Should -Throw -ExpectedMessage '*unsupported CIEM PSU scripts on azure: Checks/Start-CIEMAzureDiscovery*'
    }

    It 'throws when the supported discovery script is not registered' {
        $script:probeOutput = New-TestDeploymentProbeJson -DiscoveryCommandRegistered $false

        { Test-CIEMPSUDeployment -Environment azure } |
            Should -Throw -ExpectedMessage '*Start-CIEMAzureDiscovery is not registered*'
    }

    It 'throws when PSU schedule cmdlets are unavailable' {
        $script:probeOutput = New-TestDeploymentProbeJson -ScheduleSupportAvailable $false

        { Test-CIEMPSUDeployment -Environment azure } |
            Should -Throw -ExpectedMessage '*PSU schedule support is not available*'
    }

    It 'refuses multi-instance topology because CIEM SQLite sharing has not been validated' {
        { Test-CIEMPSUDeployment -Environment azure -Topology MultiInstance } |
            Should -Throw -ExpectedMessage '*multi-instance PSU topology has not been validated*'
    }

    It 'runs the managed identity read probe only when explicitly requested' {
        $script:probeOutput = New-TestDeploymentProbeJson -ManagedIdentityReadStatus 'Validated' -ManagedIdentitySubscriptionCount 2

        $result = Test-CIEMPSUDeployment -Environment azure -ValidateManagedIdentityRead

        $script:runtimeScripts[0] | Should -Match '\$validateManagedIdentityRead\s*=\s*\$true'
        $script:runtimeScripts[0] | Should -Match 'Connect-CIEMAzure'
        $result.Details.ManagedIdentityReadStatus | Should -Be 'Validated'
        $result.Details.ManagedIdentitySubscriptionCount | Should -Be 2
    }

    It 'throws when managed identity read validation is requested but not validated' {
        $script:probeOutput = New-TestDeploymentProbeJson

        { Test-CIEMPSUDeployment -Environment azure -ValidateManagedIdentityRead } |
            Should -Throw -ExpectedMessage '*managed identity read permission was not validated*'
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
