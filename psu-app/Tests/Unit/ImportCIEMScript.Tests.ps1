BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')

    $script:UniversalScriptsPath = Join-Path $PSScriptRoot '..' '..' '.universal' 'scripts.ps1'
    $script:UniversalScriptsExists = Test-Path -Path $script:UniversalScriptsPath -PathType Leaf
    $script:UniversalScriptsContent = if ($script:UniversalScriptsExists) { Get-Content -Path $script:UniversalScriptsPath -Raw } else { '' }
    $script:ImportScriptPath = Join-Path $PSScriptRoot '..' '..' 'Public' 'Import-CIEMScript.ps1'
    $script:ImportScriptContent = Get-Content -Path $script:ImportScriptPath -Raw
    $script:RepairScriptPath = Join-Path $PSScriptRoot '..' '..' 'Public' 'Repair-CIEMLegacyScriptRegistration.ps1'
    $script:RepairScriptContent = if (Test-Path -Path $script:RepairScriptPath -PathType Leaf) { Get-Content -Path $script:RepairScriptPath -Raw } else { '' }
    $script:AppScriptPath = Join-Path $PSScriptRoot '..' '..' 'modules' 'Devolutions.CIEM.PSU' 'Public' 'New-DevolutionsCIEMApp.ps1'
    $script:AppScriptContent = Get-Content -Path $script:AppScriptPath -Raw
    $script:ManifestPath = Join-Path $PSScriptRoot '..' '..' 'data' 'psu-scripts.json'
    $script:ManifestContent = Get-Content -Path $script:ManifestPath -Raw
    $script:Manifest = $script:ManifestContent | ConvertFrom-Json -Depth 10
    $script:RemediationTemplateRoot = Join-Path $PSScriptRoot '..' '..' 'modules' 'Devolutions.CIEM.Graph' 'Data' 'attack_path_remediation_scripts'
    $script:RemediationScriptTemplatePath = Join-Path $PSScriptRoot '..' '..' 'modules' 'Devolutions.CIEM.Graph' 'Data' 'attack_path_remediation_script_template.ps1'
}

Describe 'Import-CIEMScript registration model' {
    Context 'Command exposure' {
        It 'Exposes Import-CIEMScript as a public module command' {
            Get-Command Import-CIEMScript -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Exposes Repair-CIEMLegacyScriptRegistration as a public module command' {
            Get-Command Repair-CIEMLegacyScriptRegistration -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Manifest' {
        It 'Defines the Checks and Identities script folders' {
            @($script:Manifest.folders) | Should -Contain 'Checks'
            @($script:Manifest.folders) | Should -Contain 'Identities'
            @($script:Manifest.folders) | Should -Contain 'Identities/AttackPaths'
            @($script:Manifest.folders) | Should -Not -Contain 'Identity'
        }

        It 'Defines core Checks scripts in psu-scripts.json' {
            $script:ManifestContent | Should -Match '"name"\s*:\s*"Checks/New-CIEMScanRun"'
            $script:ManifestContent | Should -Match '"name"\s*:\s*"Checks/Start-CIEMAzureDiscovery"'
        }

        It 'Keeps core CIEM automation script names under Checks' {
            foreach ($scriptName in @($script:Manifest.scripts | ForEach-Object { $_.name })) {
                $scriptName | Should -Match '^Checks/'
            }
        }

        It 'Does not define legacy Devolutions.CIEM or Users rooted names' {
            $script:ManifestContent | Should -Not -Match '"name"\s*:\s*"Devolutions\.CIEM'
            $script:ManifestContent | Should -Not -Match '"name"\s*:\s*"Users/'
        }

        It 'Does not define a legacy Devolutions.CIEM folder' {
            @($script:Manifest.folders) | Should -Not -Contain 'Devolutions.CIEM'
        }

        It 'Defines attack path script settings with basename PSU script names in psu-scripts.json' {
            $script:ManifestContent | Should -Match '"path"\s*:\s*"modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts"'
            $script:ManifestContent | Should -Match '"templatePath"\s*:\s*"modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_script_template.ps1"'
            $script:ManifestContent | Should -Match '"namePrefix"\s*:\s*""'
            $script:ManifestContent | Should -Not -Match '"namePrefix"\s*:\s*"Checks/AttackPathRemediation-"'
        }
    }

    Context 'PSU app startup registration' {
        It 'Does not ship a .universal scripts.ps1 module resource that creates a read-only Devolutions.CIEM Scripts folder' {
            $script:UniversalScriptsPath | Should -Not -Exist
        }

        It 'Does not run PSU management script registration from the app startup path' {
            $script:AppScriptContent | Should -Not -Match 'Import-CIEMScript'
        }
    }

    Context 'Import-CIEMScript implementation' {
        It 'Loads registration from the shared psu-scripts.json manifest' {
            $script:ImportScriptContent | Should -Match 'psu-scripts\.json'
        }

        It 'Uses generic registration loops rather than hardcoded script names' {
            $script:ImportScriptContent | Should -Not -Match '-Name\s+["'']Checks/New-CIEMScanRun["'']'
            $script:ImportScriptContent | Should -Not -Match '-Name\s+["'']Checks/Start-CIEMAzureDiscovery["'']'
            $script:ImportScriptContent | Should -Not -Match 'modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_scripts/disabled-account'
        }

        It 'Registers core scripts from validated file content as script blocks' {
            $script:ImportScriptContent | Should -Match 'ScriptBlock\s+=\s+\[scriptblock\]::Create\(\$content\)'
            $script:ImportScriptContent | Should -Not -Match '(?m)^\s*-Path \$path\s*$'
        }

        It 'Keeps legacy repair out of the current registration path' {
            $script:ImportScriptContent | Should -Match 'Get-PSUScript'
            $script:ImportScriptContent | Should -Not -Match 'Remove-PSUScript'
            $script:ImportScriptContent | Should -Not -Match 'legacyScriptExactNames'
            $script:ImportScriptContent | Should -Not -Match 'legacyPathPatterns'
        }

        It 'Validates manifest script folders without using PSU folder APIs' {
            $script:ImportScriptContent | Should -Not -Match 'Get-PSUFolder'
            $script:ImportScriptContent | Should -Not -Match 'New-PSUFolder'
            $script:ImportScriptContent | Should -Match 'manifest\.folders'
        }

        It 'Uses managed notes and upsert behavior for CIEM-owned scripts' {
            $script:ImportScriptContent | Should -Match 'ManagedBy=Devolutions\.CIEM;Source=data/psu-scripts\.json'
            $script:ImportScriptContent | Should -Match 'Set-PSUScript'
        }

        It 'Rejects rooted or parent-traversal script paths in the manifest' {
            $script:ImportScriptContent | Should -Match 'IsPathRooted'
            $script:ImportScriptContent | Should -Match 'parent path traversal'
        }

        It 'Registers attack path scripts from remediation templates in PSU Automation' {
            $script:ImportScriptContent | Should -Match 'remediationTemplates'
            $script:ImportScriptContent | Should -Match 'templateFiles'
            $script:ImportScriptContent | Should -Match 'MergeCIEMAttackPathRemediationScriptTemplate'
        }
    }

    Context 'Repair-CIEMLegacyScriptRegistration implementation' {
        It 'Owns stale CIEM script removal instead of Import-CIEMScript' {
            $script:RepairScriptContent | Should -Match 'Get-PSUScript'
            $script:RepairScriptContent | Should -Match 'Remove-PSUScript'
            $script:RepairScriptContent | Should -Match 'legacyScriptExactNames'
            $script:RepairScriptContent | Should -Match 'legacyPathPatterns'
        }
    }

    Context 'Import-CIEMScript behavior' {
        It 'Registers current scripts without pruning legacy scripts' {
            Mock -ModuleName Devolutions.CIEM Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            } -ParameterFilter { $Name -in @('New-PSUScript', 'Get-PSUScript', 'Remove-PSUScript', 'Set-PSUScript', 'Get-PSUFolder', 'New-PSUFolder') }

            Mock -ModuleName Devolutions.CIEM New-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Remove-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Set-PSUScript {}
            Mock -ModuleName Devolutions.CIEM New-PSUFolder {}
            Mock -ModuleName Devolutions.CIEM Get-PSUFolder {
                return @(
                    [pscustomobject]@{ Name = 'Checks'; Path = 'Checks'; Type = 'Script' }
                    [pscustomobject]@{ Name = 'Devolutions.CIEM'; Path = 'Devolutions.CIEM'; Type = 'Script' }
                )
            }
            Mock -ModuleName Devolutions.CIEM Get-PSUScript {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    return @()
                }

                return @(
                    [pscustomobject]@{ Name = 'Checks/New-CIEMScanRun' }
                    [pscustomobject]@{ Name = 'Devolutions.CIEM/Start-CIEMAzureDiscovery' }
                    [pscustomobject]@{ Name = 'Checks/AttackPathRemediation-guest-user-holding-a-privileged-role' }
                    [pscustomobject]@{ Name = 'Identities/AttackPaths/AttackPathRemediation-disabled-account-still-holding-active-role-assignments' }
                    [pscustomobject]@{ Name = 'management-port-open-to-the-internet'; FullPath = 'management-port-open-to-the-internet.ps1'; CommitNotes = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json' }
                    [pscustomobject]@{ Name = 'Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/Checks/New-CIEMScanRun.ps1' }
                    [pscustomobject]@{ Name = 'Infra/RotateCertificates' }
                )
            }

            $result = Import-CIEMScript

            $result.Status | Should -Be 'Registered'
            $result.CoreScripts | Should -Be @($script:Manifest.scripts).Count
            $result.AttackPathScripts | Should -Be @(Get-ChildItem -Path $script:RemediationTemplateRoot -Filter '*.ps1' -File).Count
            $result.PrunedScripts | Should -Be 0
            $result.SyncedFolders | Should -Be 0

            Should -Invoke -CommandName Remove-PSUScript -ModuleName Devolutions.CIEM -Times 0
            Should -Invoke -CommandName Get-PSUFolder -ModuleName Devolutions.CIEM -Times 0
            Should -Invoke -CommandName New-PSUFolder -ModuleName Devolutions.CIEM -Times 0
            Should -Invoke -CommandName New-PSUScript -ModuleName Devolutions.CIEM -Times (@($script:Manifest.scripts).Count + @(Get-ChildItem -Path $script:RemediationTemplateRoot -Filter '*.ps1' -File).Count - 1)
            Should -Invoke -CommandName New-PSUScript -ModuleName Devolutions.CIEM -Times @(Get-ChildItem -Path $script:RemediationTemplateRoot -Filter '*.ps1' -File).Count -ParameterFilter {
                $Name -notmatch '/' -and $Path -match '^Identities/AttackPaths/[^/]+\.ps1$'
            }
            Should -Invoke -CommandName New-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
                $Name -eq 'disabled-account-still-holding-active-role-assignments' -and
                $Path -eq 'Identities/AttackPaths/disabled-account-still-holding-active-role-assignments.ps1'
            }
            Should -Invoke -CommandName Set-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
                $Script.Name -eq 'Checks/New-CIEMScanRun'
            }
            Should -Invoke -CommandName Get-PSUScript -ModuleName Devolutions.CIEM -Times 0 -ParameterFilter { $PSBoundParameters.ContainsKey('Name') }
            Should -Invoke -CommandName Get-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { -not $PSBoundParameters.ContainsKey('Name') -and -not $PSBoundParameters.ContainsKey('Integrated') }
            Should -Invoke -CommandName New-PSUScript -ModuleName Devolutions.CIEM -Times ($result.TotalScripts - 1) -ParameterFilter { -not $PSBoundParameters.ContainsKey('Integrated') }
        }

        It 'Uses integrated PSU cmdlets only when requested' {
            Mock -ModuleName Devolutions.CIEM Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            } -ParameterFilter { $Name -in @('New-PSUScript', 'Get-PSUScript', 'Remove-PSUScript', 'Set-PSUScript', 'Get-PSUFolder', 'New-PSUFolder') }

            Mock -ModuleName Devolutions.CIEM New-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Remove-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Set-PSUScript {}
            Mock -ModuleName Devolutions.CIEM New-PSUFolder {}
            Mock -ModuleName Devolutions.CIEM Get-PSUFolder { return @() }
            Mock -ModuleName Devolutions.CIEM Get-PSUScript {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    return @()
                }

                return @()
            }

            $result = Import-CIEMScript -Integrated

            Should -Invoke -CommandName Get-PSUFolder -ModuleName Devolutions.CIEM -Times 0
            Should -Invoke -CommandName New-PSUFolder -ModuleName Devolutions.CIEM -Times 0
            Should -Invoke -CommandName Get-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $Integrated.IsPresent -and -not $PSBoundParameters.ContainsKey('Name') }
            Should -Invoke -CommandName New-PSUScript -ModuleName Devolutions.CIEM -Times $result.TotalScripts -ParameterFilter { $Integrated.IsPresent }
        }

        It 'Creates scripts when no existing scripts are returned' {
            Mock -ModuleName Devolutions.CIEM Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            } -ParameterFilter { $Name -in @('New-PSUScript', 'Get-PSUScript', 'Remove-PSUScript', 'Set-PSUScript', 'Get-PSUFolder', 'New-PSUFolder') }

            Mock -ModuleName Devolutions.CIEM New-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Remove-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Set-PSUScript {}
            Mock -ModuleName Devolutions.CIEM New-PSUFolder {}
            Mock -ModuleName Devolutions.CIEM Get-PSUFolder { return @() }
            Mock -ModuleName Devolutions.CIEM Get-PSUScript {
                return @()
            }

            $result = Import-CIEMScript

            $result.Status | Should -Be 'Registered'
            $result.TotalScripts | Should -Be (@($script:Manifest.scripts).Count + @(Get-ChildItem -Path $script:RemediationTemplateRoot -Filter '*.ps1' -File).Count)
            Should -Invoke -CommandName New-PSUScript -ModuleName Devolutions.CIEM -Times $result.TotalScripts
            Should -Invoke -CommandName Set-PSUScript -ModuleName Devolutions.CIEM -Times 0
        }

        It 'Creates attack path PSU scripts by combining the shared template with each attack path body' {
            Mock -ModuleName Devolutions.CIEM Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            } -ParameterFilter { $Name -in @('New-PSUScript', 'Get-PSUScript', 'Remove-PSUScript', 'Set-PSUScript', 'Get-PSUFolder', 'New-PSUFolder') }

            Mock -ModuleName Devolutions.CIEM New-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Remove-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Set-PSUScript {}
            Mock -ModuleName Devolutions.CIEM New-PSUFolder {}
            Mock -ModuleName Devolutions.CIEM Get-PSUFolder { return @() }
            Mock -ModuleName Devolutions.CIEM Get-PSUScript {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    return $null
                }

                return @()
            }

            $result = Import-CIEMScript

            $result.Status | Should -Be 'Registered'
            Should -Invoke -CommandName New-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
                $Name -eq 'management-port-open-to-the-internet' -and
                $Path -eq 'Identities/AttackPaths/management-port-open-to-the-internet.ps1' -and
                $ScriptBlock.ToString() -match '^<#' -and
                $ScriptBlock.ToString().IndexOf('#>') -lt $ScriptBlock.ToString().IndexOf('$ErrorActionPreference') -and
                $ScriptBlock.ToString() -match 'function Assert-CIEMAttackPathRemediationScriptResolved' -and
                $ScriptBlock.ToString() -match 'Assert-CIEMAttackPathRemediationScriptResolved -ScriptBlock \$MyInvocation\.MyCommand\.ScriptBlock' -and
                $ScriptBlock.ToString() -match '\{\{NSG_RULE_DELETE_COMMANDS\}\}' -and
                $ScriptBlock.ToString() -notmatch '\{\{CIEM_ATTACK_PATH_SCRIPT_HELP\}\}' -and
                $ScriptBlock.ToString() -notmatch '\{\{CIEM_ATTACK_PATH_SCRIPT_BODY\}\}'
            }
        }

        It 'Does not call PSU folder APIs during current script registration' {
            Mock -ModuleName Devolutions.CIEM Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            } -ParameterFilter { $Name -in @('New-PSUScript', 'Get-PSUScript', 'Remove-PSUScript', 'Set-PSUScript', 'Get-PSUFolder', 'New-PSUFolder') }

            Mock -ModuleName Devolutions.CIEM New-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Remove-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Set-PSUScript {}
            Mock -ModuleName Devolutions.CIEM New-PSUFolder {}
            Mock -ModuleName Devolutions.CIEM Get-PSUFolder {
                throw 'PSU folder API is not part of current script registration.'
            }
            Mock -ModuleName Devolutions.CIEM Get-PSUScript {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    return $null
                }

                return @()
            }

            $result = Import-CIEMScript

            $result.Status | Should -Be 'Registered'
            $result.SyncedFolders | Should -Be 0
            Should -Invoke -CommandName Get-PSUFolder -ModuleName Devolutions.CIEM -Times 0
            Should -Invoke -CommandName New-PSUFolder -ModuleName Devolutions.CIEM -Times 0
        }

    }

    Context 'Repair-CIEMLegacyScriptRegistration behavior' {
        It 'Prunes stale CIEM scripts and keeps unrelated scripts intact' {
            Mock -ModuleName Devolutions.CIEM Get-Command {
                [pscustomobject]@{
                    Name = $Name
                }
            } -ParameterFilter { $Name -in @('Get-PSUScript', 'Remove-PSUScript') }

            Mock -ModuleName Devolutions.CIEM Remove-PSUScript {}
            Mock -ModuleName Devolutions.CIEM Get-PSUScript {
                param($Name)
                if ($PSBoundParameters.ContainsKey('Name')) {
                    return @()
                }

                return @(
                    [pscustomobject]@{ Name = 'Checks/New-CIEMScanRun' }
                    [pscustomobject]@{ Name = 'Devolutions.CIEM/Start-CIEMAzureDiscovery' }
                    [pscustomobject]@{ Name = 'Checks/AttackPathRemediation-guest-user-holding-a-privileged-role' }
                    [pscustomobject]@{ Name = 'Identities/AttackPaths/AttackPathRemediation-disabled-account-still-holding-active-role-assignments' }
                    [pscustomobject]@{ Name = 'management-port-open-to-the-internet'; FullPath = 'management-port-open-to-the-internet.ps1'; CommitNotes = 'ManagedBy=Devolutions.CIEM;Source=data/psu-scripts.json' }
                    [pscustomobject]@{ Name = 'Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/Checks/New-CIEMScanRun.ps1' }
                    [pscustomobject]@{ Name = 'Infra/RotateCertificates' }
                )
            }

            $result = Repair-CIEMLegacyScriptRegistration

            $result.Status | Should -Be 'Repaired'
            $result.ScannedScripts | Should -Be 7
            $result.PrunedScripts | Should -Be 5

            Should -Invoke -CommandName Remove-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $Script.Name -eq 'Devolutions.CIEM/Start-CIEMAzureDiscovery' }
            Should -Invoke -CommandName Remove-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $Script.Name -eq 'Checks/AttackPathRemediation-guest-user-holding-a-privileged-role' }
            Should -Invoke -CommandName Remove-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $Script.Name -eq 'Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/Checks/New-CIEMScanRun.ps1' }
            Should -Invoke -CommandName Remove-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $Script.Name -eq 'Identities/AttackPaths/AttackPathRemediation-disabled-account-still-holding-active-role-assignments' }
            Should -Invoke -CommandName Remove-PSUScript -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter { $Script.Name -eq 'management-port-open-to-the-internet' }
            Should -Invoke -CommandName Remove-PSUScript -ModuleName Devolutions.CIEM -Times 0 -ParameterFilter { $Script.Name -eq 'Checks/New-CIEMScanRun' }
            Should -Invoke -CommandName Remove-PSUScript -ModuleName Devolutions.CIEM -Times 0 -ParameterFilter { $Script.Name -eq 'Infra/RotateCertificates' }
            Should -Invoke -CommandName Get-PSUScript -ModuleName Devolutions.CIEM -Times 0 -ParameterFilter { $PSBoundParameters.ContainsKey('Name') }
        }
    }

    Context 'Remediation template behavior' {
        It 'Provides a shared runtime wrapper for attack path script bodies' {
            $script:RemediationScriptTemplatePath | Should -Exist
            $content = Get-Content -Path $script:RemediationScriptTemplatePath -Raw
            $content | Should -Match '\{\{CIEM_ATTACK_PATH_SCRIPT_HELP\}\}'
            $content | Should -Match '\{\{CIEM_ATTACK_PATH_SCRIPT_BODY\}\}'
            $content | Should -Match 'function Assert-CIEMAttackPathRemediationScriptResolved'
            $content | Should -Match 'Assert-CIEMAttackPathRemediationScriptResolved -ScriptBlock \$MyInvocation\.MyCommand\.ScriptBlock'
            $content | Should -Not -Match '# Attack path: \{\{PATTERN_NAME\}\}'
            $content | Should -Not -Match '(?m)^\$__ciemTemplateContent\s*='
            $content | Should -Not -Match '(?m)^\$__ciemUnresolvedTokens\s*='
            $content | Should -Match 'Devolutions\.CIEM\\Connect-CIEMAzure'
            $content | Should -Not -Match 'az account show'
            $content | Should -Not -Match 'Azure CLI'
            $content | Should -Match 'Write-Information'
            $content | Should -Not -Match 'Write-Output'
            $content | Should -Not -Match 'Write-Host'
        }

        It 'Fails before executing the script body when shared placeholders are unresolved' {
            $content = Get-Content -Path $script:RemediationScriptTemplatePath -Raw
            $content = $content.Replace('{{CIEM_ATTACK_PATH_SCRIPT_BODY}}', "throw 'script body executed'")

            { & ([scriptblock]::Create($content)) } | Should -Throw '*unresolved tokens*'
        }

        It 'Stores existing attack path scripts as command bodies consumed by the shared template' {
            $templates = @(Get-ChildItem -Path $script:RemediationTemplateRoot -Filter '*.ps1' -File)
            foreach ($template in $templates) {
                $content = Get-Content -Path $template.FullName -Raw
                $content | Should -Match '\{\{(ROLE_ASSIGNMENT_DELETE_COMMANDS|NSG_RULE_DELETE_COMMANDS|GROUP_MEMBER_REMOVE_COMMANDS)\}\}'
                $content | Should -Not -Match '# Attack path: \{\{PATTERN_NAME\}\}'
                $content | Should -Not -Match '\$__ciemTemplateProbe'
                $content | Should -Not -Match 'az account show'
                $content | Should -Not -Match 'Write-Host'
            }
        }
    }
}
