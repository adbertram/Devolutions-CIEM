BeforeAll {
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts/remove-psu.ps1'

    function Connect-PSU {
        param(
            [string]$Url,
            [string]$Token,
            [string]$EnvFilePath,
            [string]$ResourceGroup,
            [string]$WebAppName,
            [switch]$Local
        )
    }
    function Get-PSUScript {
        param([string]$Name)
    }
    function Remove-PSUScript {
        param([object]$Script)
    }
    function Get-PSUJob {
        param(
            [uint64]$First,
            [uint64]$Skip,
            [string]$OrderDirection,
            [bool]$HideChildren,
            [bool]$HideScheduled,
            [bool]$HideTriggered,
            [object]$Script
        )
    }
    function Stop-PSUJob {
        param([long]$Id)
    }
    function Get-PSUSchedule {
        param([object]$Script)
    }
    function Remove-PSUSchedule {
        param([object]$Schedule)
    }
    function Remove-PSUModule {
        param(
            [string]$Name,
            [string]$Version,
            [switch]$Force
        )
    }

    . $script:ScriptPath
}

Describe 'scripts/remove-psu.ps1' {
    BeforeEach {
        $script:ModuleRoot = Join-Path $TestDrive 'psu-app'
        $script:AdminModulePath = Join-Path $TestDrive 'Devolutions.CIEM.Admin.psd1'
        $script:ManifestPath = Join-Path $script:ModuleRoot 'data/psu-scripts.json'
        $script:RemediationRoot = Join-Path $script:ModuleRoot 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts'

        Set-Content -Path $script:AdminModulePath -Value '@{}'
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

        Mock Import-Module {}
        Mock Connect-PSU {}
        Mock Remove-PSUModule {
            [pscustomobject]@{
                Name = $Name
                Status = 'Removed'
                Source = 'Filesystem'
            }
        }
        Mock Remove-PSUScript {}
        Mock Get-PSUJob { @() }
        Mock Stop-PSUJob {}
        Mock Get-PSUSchedule { @() }
        Mock Remove-PSUSchedule {}
    }

    It 'exists under the project scripts directory' {
        $script:ScriptPath | Should -Exist
    }

    It 'connects to Azure, removes CIEM-owned PSU scripts from a single scan, and removes the module' {
        Mock Get-PSUScript {
            if ($PSBoundParameters.ContainsKey('Name')) {
                throw 'remove-psu.ps1 must not use Get-PSUScript -Name against Azure'
            }

            @(
                [pscustomobject]@{ Name = 'Checks/New-CIEMScanRun' }
                [pscustomobject]@{ Name = 'management-port-open-to-the-internet'; FullPath = 'Identities/AttackPaths/management-port-open-to-the-internet.ps1'; CommitNotes = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json' }
                [pscustomobject]@{ Name = 'Devolutions.CIEM/Start-CIEMAzureDiscovery' }
                [pscustomobject]@{ Name = 'Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/Checks/New-CIEMScanRun.ps1' }
                [pscustomobject]@{ Name = 'CIEMExecutor.ps1'; FullPath = 'CIEMExecutor.ps1'; Description = 'Persistent executor for Invoke-CIEMCommand' }
                [pscustomobject]@{ Name = 'Infra/RotateCertificates' }
            )
        }

        $result = Invoke-CIEMPSURemoval `
            -Environment azure `
            -ModulePath $script:ModuleRoot `
            -AdminModulePath $script:AdminModulePath `
            -EnvFilePath 'NO_ENV_FILE' `
            -Force

        $result.Status | Should -Be 'Removed'
        $result.ScriptResourcesScanned | Should -Be 6
        $result.ScriptResourcesRemoved | Should -Be 5

        Should -Invoke Connect-PSU -Times 1 -ParameterFilter {
            -not $Local -and $EnvFilePath -eq 'NO_ENV_FILE'
        }
        Should -Invoke Get-PSUScript -Times 1 -ParameterFilter {
            -not $PSBoundParameters.ContainsKey('Name')
        }
        Should -Invoke Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'Checks/New-CIEMScanRun' }
        Should -Invoke Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'management-port-open-to-the-internet' }
        Should -Invoke Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'Devolutions.CIEM/Start-CIEMAzureDiscovery' }
        Should -Invoke Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/Checks/New-CIEMScanRun.ps1' }
        Should -Invoke Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'CIEMExecutor.ps1' }
        Should -Invoke Remove-PSUScript -Times 0 -ParameterFilter { $Script.Name -eq 'Infra/RotateCertificates' }
        Should -Invoke Remove-PSUModule -Times 1 -ParameterFilter {
            $Name -eq 'Devolutions.CIEM' -and $Force
        }
    }

    It 'stops active CIEM jobs and removes CIEM schedules from a single scan' {
        Mock Get-PSUScript {
            @(
                [pscustomobject]@{ Name = 'CIEMExecutor.ps1'; FullPath = 'CIEMExecutor.ps1'; Description = 'Persistent executor for Invoke-CIEMCommand' }
                [pscustomobject]@{ Name = 'Infra/RotateCertificates'; FullPath = 'Infra/RotateCertificates.ps1' }
            )
        }
        Mock Get-PSUJob {
            if ($PSBoundParameters.ContainsKey('Script')) {
                throw 'remove-psu.ps1 must not use Get-PSUJob -Script after scripts have been removed'
            }

            @(
                [pscustomobject]@{ Id = 10; Status = 1; ScriptFullPath = 'Checks/Start-CIEMAzureDiscovery.ps1' }
                [pscustomobject]@{ Id = 11; Status = 2; ScriptFullPath = 'Checks/Invoke-CIEMAttackPathRemediation.ps1' }
                [pscustomobject]@{ Id = 12; Status = 1; ScriptFullPath = 'Infra/RotateCertificates.ps1' }
                [pscustomobject]@{ Id = 13; Status = 4; ScriptFullPath = 'CIEMExecutor.ps1' }
                [pscustomobject]@{ Id = 14; Status = 0; ScriptFullPath = 'CIEMExecutor.ps1' }
            )
        }
        Mock Get-PSUSchedule {
            if ($PSBoundParameters.ContainsKey('Script')) {
                throw 'remove-psu.ps1 must not use Get-PSUSchedule -Script after scripts have been removed'
            }

            @(
                [pscustomobject]@{ Id = 20; Name = 'CIEM scan'; ScriptName = 'Checks/Start-CIEMAzureDiscovery.ps1' }
                [pscustomobject]@{ Id = 21; Name = 'Infra rotation'; ScriptName = 'Infra/RotateCertificates.ps1' }
            )
        }

        $result = Invoke-CIEMPSURemoval `
            -Environment azure `
            -ModulePath $script:ModuleRoot `
            -AdminModulePath $script:AdminModulePath `
            -EnvFilePath 'NO_ENV_FILE' `
            -Force

        $result.JobResourcesScanned | Should -Be 5
        $result.JobResourcesMatched | Should -Be 4
        $result.JobResourcesStopped | Should -Be 2
        $result.QueuedJobResourcesRetained | Should -Be 1
        $result.ScheduleResourcesScanned | Should -Be 2
        $result.ScheduleResourcesRemoved | Should -Be 1

        Should -Invoke Get-PSUJob -Times 1 -ParameterFilter {
            -not $PSBoundParameters.ContainsKey('Script')
        }
        Should -Invoke Stop-PSUJob -Times 1 -ParameterFilter { $Id -eq 10 }
        Should -Invoke Stop-PSUJob -Times 1 -ParameterFilter { $Id -eq 13 }
        Should -Invoke Stop-PSUJob -Times 0 -ParameterFilter { $Id -eq 11 }
        Should -Invoke Stop-PSUJob -Times 0 -ParameterFilter { $Id -eq 12 }
        Should -Invoke Stop-PSUJob -Times 0 -ParameterFilter { $Id -eq 14 }
        Should -Invoke Remove-PSUSchedule -Times 1 -ParameterFilter { $Schedule.Id -eq 20 }
        Should -Invoke Remove-PSUSchedule -Times 0 -ParameterFilter { $Schedule.Id -eq 21 }
        Should -Invoke Remove-PSUScript -Times 1 -ParameterFilter { $Script.Name -eq 'CIEMExecutor.ps1' }
    }

    It 'connects to the local PSU target before scanning scripts' {
        Mock Get-PSUScript { @() }

        $result = Invoke-CIEMPSURemoval `
            -Environment local `
            -ModulePath $script:ModuleRoot `
            -AdminModulePath $script:AdminModulePath `
            -EnvFilePath 'NO_ENV_FILE' `
            -Force

        $result.ScriptResourcesScanned | Should -Be 0
        $result.ScriptResourcesRemoved | Should -Be 0

        Should -Invoke Connect-PSU -Times 1 -ParameterFilter {
            $Local -and $EnvFilePath -eq 'NO_ENV_FILE'
        }
        Should -Invoke Remove-PSUModule -Times 1 -ParameterFilter {
            $Name -eq 'Devolutions.CIEM' -and $Force
        }
    }
}
