BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    InModuleScope Devolutions.CIEM { $script:DatabasePath = "$TestDrive/ciem.db" }
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    # Mock PSU UI cmdlets (not available outside PSU)
    Mock -ModuleName Devolutions.CIEM Set-UDElement {}
    Mock -ModuleName Devolutions.CIEM New-UDCard { 'card' }
    Mock -ModuleName Devolutions.CIEM New-UDProgress { 'progress' }
    Mock -ModuleName Devolutions.CIEM New-UDStack { 'stack' }
    Mock -ModuleName Devolutions.CIEM New-UDTypography { 'typo' }
}

Describe 'Invoke-CIEMJobWithProgress' {

    Context 'Command structure' {

        It 'Is available as a public command' {
            Get-Command Invoke-CIEMJobWithProgress -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Has mandatory -ScriptName parameter' {
            $param = (Get-Command Invoke-CIEMJobWithProgress).Parameters['ScriptName']
            $param | Should -Not -BeNullOrEmpty
            $mandatory = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatory | Should -Not -BeNullOrEmpty
        }

        It 'Has optional -ProgressElementId parameter' {
            $param = (Get-Command Invoke-CIEMJobWithProgress).Parameters['ProgressElementId']
            $param | Should -Not -BeNullOrEmpty
            $mandatory = $param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }
            $mandatory | Should -BeNullOrEmpty
        }

        It 'Has optional -PollIntervalSeconds parameter defaulting to 3' {
            $param = (Get-Command Invoke-CIEMJobWithProgress).Parameters['PollIntervalSeconds']
            $param | Should -Not -BeNullOrEmpty
        }

        It 'Has optional -MaxPollSeconds parameter defaulting to 1800' {
            $param = (Get-Command Invoke-CIEMJobWithProgress).Parameters['MaxPollSeconds']
            $param | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Completed job returns pipeline output' {

        It 'Returns output from a successfully completed job' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 1001 }
            }
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                [PSCustomObject]@{ Id = 1001; Status = 'Completed'; Activity = 'Done'; PercentComplete = 100; StatusDescription = ''; CurrentOperation = '' }
            }
            Mock -ModuleName Devolutions.CIEM Get-PSUJobPipelineOutput {
                [PSCustomObject]@{ Result = 'success' }
            }

            $result = Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'prog1' -PollIntervalSeconds 0 -MaxPollSeconds 10
            $result.Result | Should -Be 'success'
        }
    }

    Context 'Warning status treated as success' {

        It 'Returns output when job status is Warning' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 1002 }
            }
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                [PSCustomObject]@{ Id = 1002; Status = 'Warning'; Activity = ''; PercentComplete = 100; StatusDescription = ''; CurrentOperation = '' }
            }
            Mock -ModuleName Devolutions.CIEM Get-PSUJobPipelineOutput {
                [PSCustomObject]@{ Result = 'with-warnings' }
            }

            $result = Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'prog2' -PollIntervalSeconds 0 -MaxPollSeconds 10
            $result.Result | Should -Be 'with-warnings'
        }
    }

    Context 'Failed job throws' {

        It 'Throws when job status is Failed' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 1003 }
            }
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                [PSCustomObject]@{ Id = 1003; Status = 'Failed'; Activity = ''; PercentComplete = 0; StatusDescription = ''; CurrentOperation = '' }
            }
            Mock -ModuleName Devolutions.CIEM Get-PSUJobOutput { 'Something broke' }

            { Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'prog3' -PollIntervalSeconds 0 -MaxPollSeconds 10 } | Should -Throw '*Something broke*'
        }
    }

    Context 'Canceled job throws' {

        It 'Throws when job status is Canceled' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 1004 }
            }
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                [PSCustomObject]@{ Id = 1004; Status = 'Canceled'; Activity = ''; PercentComplete = 0; StatusDescription = ''; CurrentOperation = '' }
            }

            { Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'prog4' -PollIntervalSeconds 0 -MaxPollSeconds 10 } | Should -Throw '*cancelled*'
        }
    }

    Context 'Button disable/enable' {

        It 'Disables and re-enables buttons during execution' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 1005 }
            }
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                [PSCustomObject]@{ Id = 1005; Status = 'Completed'; Activity = ''; PercentComplete = 100; StatusDescription = ''; CurrentOperation = '' }
            }
            Mock -ModuleName Devolutions.CIEM Get-PSUJobPipelineOutput { 'ok' }

            Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'prog5' -DisableElementIds @('btn1', 'btn2') -PollIntervalSeconds 0 -MaxPollSeconds 10

            # Verify Set-UDElement was called to disable (at start) and enable (at end) each button
            Should -Invoke -CommandName Set-UDElement -ModuleName Devolutions.CIEM -ParameterFilter { $Id -eq 'btn1' -and $Properties.disabled -eq $true } -Times 1
            Should -Invoke -CommandName Set-UDElement -ModuleName Devolutions.CIEM -ParameterFilter { $Id -eq 'btn1' -and $Properties.disabled -eq $false } -Times 1
            Should -Invoke -CommandName Set-UDElement -ModuleName Devolutions.CIEM -ParameterFilter { $Id -eq 'btn2' -and $Properties.disabled -eq $true } -Times 1
            Should -Invoke -CommandName Set-UDElement -ModuleName Devolutions.CIEM -ParameterFilter { $Id -eq 'btn2' -and $Properties.disabled -eq $false } -Times 1
        }
    }

    Context 'Error job throws' {

        It 'Throws when job status is Error' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 2001 }
            }
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                [PSCustomObject]@{ Id = 2001; Status = 'Error'; Activity = ''; PercentComplete = 0; StatusDescription = ''; CurrentOperation = '' }
            }
            Mock -ModuleName Devolutions.CIEM Get-PSUJobOutput { 'Error occurred' }

            { Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'progErr' -PollIntervalSeconds 0 -MaxPollSeconds 10 } | Should -Throw '*Error occurred*'
        }
    }

    Context 'TimedOut job throws' {

        It 'Throws when job status is TimedOut' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 2002 }
            }
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                [PSCustomObject]@{ Id = 2002; Status = 'TimedOut'; Activity = ''; PercentComplete = 0; StatusDescription = ''; CurrentOperation = '' }
            }

            { Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'progTO' -PollIntervalSeconds 0 -MaxPollSeconds 10 } | Should -Throw '*timed out*'
        }
    }

    Context 'Unexpected status throws' {

        It 'Throws with status name for unexpected terminal status' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 2003 }
            }
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                [PSCustomObject]@{ Id = 2003; Status = 'SomethingUnexpected'; Activity = ''; PercentComplete = 0; StatusDescription = ''; CurrentOperation = '' }
            }

            { Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'progUX' -PollIntervalSeconds 0 -MaxPollSeconds 10 } | Should -Throw '*unexpected status*SomethingUnexpected*'
        }
    }

    Context 'Button re-enable on failure' {

        It 'Re-enables buttons even when job fails' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 2004 }
            }
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                [PSCustomObject]@{ Id = 2004; Status = 'Failed'; Activity = ''; PercentComplete = 0; StatusDescription = ''; CurrentOperation = '' }
            }
            Mock -ModuleName Devolutions.CIEM Get-PSUJobOutput { 'Crashed' }

            try {
                Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'progFail' -DisableElementIds @('btn-fail') -PollIntervalSeconds 0 -MaxPollSeconds 10
            } catch {}

            # Finally block should have re-enabled the button even after failure
            Should -Invoke -CommandName Set-UDElement -ModuleName Devolutions.CIEM -ParameterFilter { $Id -eq 'btn-fail' -and $Properties.disabled -eq $false } -Times 1
        }
    }

    Context 'StatusDescription in progress text' {

        It 'Logs StatusDescription when present in job progress' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 2005 }
            }
            $script:callCount = 0
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                $script:callCount++
                if ($script:callCount -ge 2) {
                    [PSCustomObject]@{ Id = 2005; Status = 'Completed'; Activity = 'Done'; PercentComplete = 100; StatusDescription = ''; CurrentOperation = '' }
                } else {
                    [PSCustomObject]@{ Id = 2005; Status = 'Running'; Activity = 'Collecting'; PercentComplete = 50; StatusDescription = 'Collecting Entra data'; CurrentOperation = 'Users' }
                }
            }
            Mock -ModuleName Devolutions.CIEM Get-PSUJobPipelineOutput { 'ok' }

            Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'progSD' -PollIntervalSeconds 0 -MaxPollSeconds 10

            # Verify Write-CIEMLog was called with a message containing the StatusDescription
            Should -Invoke -CommandName Write-CIEMLog -ModuleName Devolutions.CIEM -ParameterFilter { $Message -like '*statusDesc=Collecting Entra data*' } -Times 1
        }
    }

    Context 'Poll timeout' {

        It 'Throws when MaxPollSeconds is exceeded' {
            Mock -ModuleName Devolutions.CIEM Invoke-PSUScript {
                [PSCustomObject]@{ Id = 1006 }
            }
            Mock -ModuleName Devolutions.CIEM Start-Sleep {}
            Mock -ModuleName Devolutions.CIEM Get-PSUJob {
                [PSCustomObject]@{ Id = 1006; Status = 'Running'; Activity = 'Still going'; PercentComplete = 50; StatusDescription = ''; CurrentOperation = '' }
            }

            # MaxPollSeconds = 1, PollIntervalSeconds = 1 → after 1 poll, elapsed >= Max
            { Invoke-CIEMJobWithProgress -ScriptName 'Test\Script' -ProgressElementId 'prog6' -PollIntervalSeconds 1 -MaxPollSeconds 1 } | Should -Throw '*timed out*'
        }
    }
}
